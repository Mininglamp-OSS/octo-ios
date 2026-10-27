//
//  WKDocumentPreviewLoader.m
//  WuKongBase
//

#import "WKDocumentPreviewLoader.h"
#import "WuKongBase.h"
#import <AFNetworking/AFNetworking.h>

NSNotificationName const WKDocumentPreviewSessionDidChangeNotification = @"WKDocumentPreviewSessionDidChangeNotification";

static void WKInvalidateDocPreviewManager(AFHTTPSessionManager *manager) {
    if (!manager) return;
    [manager invalidateSessionCancelingTasks:YES resetSession:YES];
}

BOOL WKDocumentShareCardIsValidDocId(NSString *docId) {
    if (![docId isKindOfClass:NSString.class] || docId.length == 0 || docId.length > 128) return NO;
    for (NSUInteger i = 0; i < docId.length; i++) {
        unichar character = [docId characterAtIndex:i];
        BOOL allowed = (character >= 'A' && character <= 'Z')
            || (character >= 'a' && character <= 'z')
            || (character >= '0' && character <= '9')
            || character == '_' || character == '-';
        if (!allowed) return NO;
    }
    return YES;
}

NSURL *WKDocumentShareCardAbsoluteURL(NSString *relativePath, NSString *apiBaseURL) {
    if (relativePath.length == 0 || apiBaseURL.length == 0) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithString:apiBaseURL];
    NSString *scheme = components.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return nil;
    if (components.host.length == 0) return nil;

    NSString *basePath = components.path ?: @"";
    while ([basePath hasSuffix:@"/"]) {
        basePath = [basePath substringToIndex:basePath.length - 1];
    }
    if ([basePath hasSuffix:@"/api/v1"]) {
        basePath = [basePath substringToIndex:basePath.length - [@"/api/v1" length]];
    } else if ([basePath hasSuffix:@"/v1"]) {
        basePath = [basePath substringToIndex:basePath.length - [@"/v1" length]];
    }

    NSString *route = [relativePath hasPrefix:@"/"] ? relativePath : [@"/" stringByAppendingString:relativePath];
    components.path = [basePath stringByAppendingString:route];
    components.query = nil;
    components.fragment = nil;
    return components.URL;
}

static const NSUInteger WKDocPreviewMaxTextLength = 500;
static const NSUInteger WKDocPreviewMaxParagraphs = 3;
static const NSUInteger WKDocPreviewMaxBlocks = 200;
static const NSUInteger WKDocPreviewMaxDepth = 20;
static const NSUInteger WKDocPreviewMaxVisitedNodes = 2000;
static const NSUInteger WKDocPreviewMaxBoardElements = 2000;
static const NSUInteger WKDocPreviewMaxSheetRows = 3;
static const NSUInteger WKDocPreviewMaxSheetColumns = 5;
static const NSUInteger WKDocPreviewMaxSheetKeyLength = 160;
static const NSTimeInterval WKDocPreviewCacheTTL = 30.0;
static const NSUInteger WKDocPreviewMaxCacheEntries = 128;
static const int64_t WKDocPreviewMaxResponseBytes = 2 * 1000 * 1000;

@interface WKDocumentPreviewSubscription ()
@property(nonatomic, copy) dispatch_block_t cancellation;
@end

@implementation WKDocumentPreviewSubscription
- (void)cancel {
    dispatch_block_t cancellation = nil;
    @synchronized (self) {
        cancellation = self.cancellation;
        self.cancellation = nil;
    }
    if (cancellation) cancellation();
}
@end

static NSString *WKDocString(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSString *WKDocCollectText(id node, NSUInteger depth, NSUInteger *visited) {
    if (*visited >= WKDocPreviewMaxVisitedNodes) return @"";
    (*visited)++;
    if (depth > WKDocPreviewMaxDepth || ![node isKindOfClass:NSDictionary.class]) return @"";
    id text = node[@"text"];
    if ([text isKindOfClass:NSString.class]) {
        NSString *value = text;
        return value.length > WKDocPreviewMaxTextLength ? [value substringToIndex:WKDocPreviewMaxTextLength] : value;
    }
    id children = node[@"content"];
    if (![children isKindOfClass:NSArray.class]) return @"";
    NSMutableString *result = [NSMutableString string];
    for (id child in children) {
        if (*visited >= WKDocPreviewMaxVisitedNodes) break;
        [result appendString:WKDocCollectText(child, depth + 1, visited)];
        if (result.length >= WKDocPreviewMaxTextLength) break;
    }
    return result.length > WKDocPreviewMaxTextLength
        ? [result substringToIndex:WKDocPreviewMaxTextLength] : result;
}

static NSDictionary *WKParseDocumentPreview(id body) {
    if (![body isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *doc = [body[@"doc"] isKindOfClass:NSDictionary.class] ? body[@"doc"] : nil;
    NSArray *blocks = [doc[@"content"] isKindOfClass:NSArray.class] ? doc[@"content"] : nil;
    if (!blocks) return nil;
    NSString *heading = @"";
    NSMutableArray<NSString *> *paragraphs = [NSMutableArray array];
    NSUInteger visited = 0;
    NSUInteger count = MIN(blocks.count, WKDocPreviewMaxBlocks);
    for (NSUInteger i = 0; i < count; i++) {
        if (visited >= WKDocPreviewMaxVisitedNodes) break;
        id block = blocks[i];
        if (![block isKindOfClass:NSDictionary.class]) continue;
        NSString *text = [WKDocCollectText(block, 0, &visited) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length == 0) continue;
        id rawType = block[@"type"];
        if (heading.length == 0 && [rawType isKindOfClass:NSString.class] && [rawType isEqualToString:@"heading"]) {
            heading = text;
        } else {
            [paragraphs addObject:text];
            if (paragraphs.count >= WKDocPreviewMaxParagraphs) break;
        }
    }
    if (heading.length == 0 && paragraphs.count == 0) return nil;
    return @{@"type": @"doc", @"heading": heading, @"paragraphs": paragraphs};
}

static NSDictionary *WKParseBoardPreview(id body) {
    if (![body isKindOfClass:NSDictionary.class]) return nil;
    id elements = body[@"elements"];
    if (![elements isKindOfClass:NSArray.class]) {
        id scene = body[@"scene"];
        elements = [scene isKindOfClass:NSDictionary.class] ? scene[@"elements"] : nil;
    }
    if (![elements isKindOfClass:NSArray.class]) return nil;
    NSMutableArray<NSString *> *nodes = [NSMutableArray array];
    NSArray *boardElements = (NSArray *)elements;
    NSUInteger count = MIN(boardElements.count, WKDocPreviewMaxBoardElements);
    for (NSUInteger i = 0; i < count; i++) {
        id element = boardElements[i];
        if (![element isKindOfClass:NSDictionary.class]) continue;
        id rawText = element[@"text"];
        if (![rawText isKindOfClass:NSString.class]) continue;
        NSString *text = [rawText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length == 0) continue;
        [nodes addObject:text.length > WKDocPreviewMaxTextLength ? [text substringToIndex:WKDocPreviewMaxTextLength] : text];
        if (nodes.count >= 6) break;
    }
    return nodes.count ? @{@"type": @"board", @"nodes": nodes} : nil;
}

static NSDictionary *WKParseSheetPreview(id body) {
    if (![body isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *cells = [body[@"sheetCells"] isKindOfClass:NSDictionary.class] ? body[@"sheetCells"] : nil;
    if (!cells) return nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(.+)!(\\d+):(\\d+)$" options:0 error:nil];
    NSMutableDictionary<NSString *, NSMutableDictionary<NSNumber *, NSMutableDictionary<NSNumber *, NSString *> *> *> *sheets = [NSMutableDictionary dictionary];
    for (id rawKey in cells) {
        if (![rawKey isKindOfClass:NSString.class]) continue;
        NSString *key = rawKey;
        if (key.length > WKDocPreviewMaxSheetKeyLength) continue;
        NSTextCheckingResult *match = [regex firstMatchInString:key options:0 range:NSMakeRange(0, key.length)];
        if (match.numberOfRanges != 4) continue;
        NSInteger row = [[key substringWithRange:[match rangeAtIndex:2]] integerValue];
        NSInteger col = [[key substringWithRange:[match rangeAtIndex:3]] integerValue];
        // Keep only the first-page coordinates. Each sheet can contribute at most 24 cells,
        // regardless of how many later rows appear before them in NSDictionary iteration.
        if (row < 0 || row > WKDocPreviewMaxSheetRows || col < 0 || col > WKDocPreviewMaxSheetColumns) continue;
        NSDictionary *cell = [cells[key] isKindOfClass:NSDictionary.class] ? cells[key] : nil;
        id rawValue = cell[@"v"];
        if (!rawValue || rawValue == NSNull.null || ([rawValue isKindOfClass:NSString.class] && [rawValue length] == 0)) continue;
        NSString *value = [rawValue isKindOfClass:NSString.class] ? rawValue : [rawValue description];
        if (value.length > WKDocPreviewMaxTextLength) value = [value substringToIndex:WKDocPreviewMaxTextLength];
        NSString *sheetId = [key substringWithRange:[match rangeAtIndex:1]];
        NSMutableDictionary *rows = sheets[sheetId] ?: (sheets[sheetId] = [NSMutableDictionary dictionary]);
        NSMutableDictionary *columns = rows[@(row)] ?: (rows[@(row)] = [NSMutableDictionary dictionary]);
        columns[@(col)] = value;
    }
    NSMutableDictionary *target = nil;
    NSUInteger maxCount = 0;
    for (NSString *sheetId in [sheets.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *rows = sheets[sheetId];
        NSUInteger count = 0;
        for (NSDictionary *columns in rows.allValues) count += columns.count;
        if (count > maxCount) { maxCount = count; target = (NSMutableDictionary *)rows; }
    }
    if (!target) return nil;
    NSMutableSet<NSNumber *> *columnSet = [NSMutableSet set];
    for (NSDictionary *columns in target.allValues) [columnSet addObjectsFromArray:columns.allKeys];
    NSArray<NSNumber *> *columns = [[columnSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    if (columns.count > WKDocPreviewMaxSheetColumns + 1) columns = [columns subarrayWithRange:NSMakeRange(0, WKDocPreviewMaxSheetColumns + 1)];
    if (columns.count == 0) return nil;
    NSArray<NSString *> *(^makeRow)(NSInteger) = ^NSArray<NSString *> *(NSInteger rowIndex) {
        NSMutableArray *result = [NSMutableArray array];
        for (NSNumber *column in columns) [result addObject:target[@(rowIndex)][column] ?: @""];
        return result;
    };
    NSArray *headers = makeRow(0);
    NSMutableArray *rows = [NSMutableArray array];
    for (NSInteger i = 1; i <= WKDocPreviewMaxSheetRows; i++) if (target[@(i)]) [rows addObject:makeRow(i)];
    BOOL hasValue = rows.count > 0;
    for (NSString *header in headers) if (header.length) { hasValue = YES; break; }
    return hasValue ? @{@"type": @"sheet", @"headers": headers, @"rows": rows} : nil;
}

static NSDictionary *WKParseHTMLPreview(id body) {
    if (![body isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *raw = [body[@"preview"] isKindOfClass:NSDictionary.class] ? body[@"preview"] : nil;
    if (!raw) return nil;
    NSString *heading = [WKDocString(raw[@"heading"]) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (heading.length > WKDocPreviewMaxTextLength) heading = [heading substringToIndex:WKDocPreviewMaxTextLength];
    NSMutableArray *paragraphs = [NSMutableArray array];
    id rawParagraphs = raw[@"paragraphs"];
    if ([rawParagraphs isKindOfClass:NSArray.class]) {
        for (id item in rawParagraphs) {
            if (![item isKindOfClass:NSString.class]) continue;
            NSString *text = [item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (!text.length) continue;
            if (text.length > WKDocPreviewMaxTextLength) text = [text substringToIndex:WKDocPreviewMaxTextLength];
            [paragraphs addObject:text];
            if (paragraphs.count >= WKDocPreviewMaxParagraphs) break;
        }
    }
    return heading.length || paragraphs.count ? @{@"type": @"doc", @"heading": heading, @"paragraphs": paragraphs} : nil;
}

@interface WKDocPreviewRequestSnapshot : NSObject
@property(nonatomic, copy) NSString *origin;
@property(nonatomic, copy) NSString *apiBaseURL;
@property(nonatomic, copy) NSString *uid;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, copy) NSString *language;
@property(nonatomic, assign) NSUInteger generation;
@end
@implementation WKDocPreviewRequestSnapshot
@end

@interface WKDocPreviewCacheEntry : NSObject
@property(nonatomic, copy) NSDictionary *result;
@property(nonatomic, assign) NSTimeInterval timestamp;
@end
@implementation WKDocPreviewCacheEntry
@end

/// A flight holds its callbacks, task and a reference to the shared transport. Identity checks prevent a late
/// completion from an invalidated request from consuming a newer flight's callbacks.
@interface WKDocPreviewFlight : NSObject
@property(nonatomic, copy) NSString *requestID;
@property(nonatomic, copy) NSString *cacheKey;
@property(nonatomic, strong) WKDocPreviewRequestSnapshot *snapshot;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *callbacks;
@property(nonatomic, strong) AFHTTPSessionManager *manager;
@property(nonatomic, strong) NSURLSessionDataTask *task;
@property(nonatomic, assign) BOOL finished;
@end
@implementation WKDocPreviewFlight
@end

@interface WKDocumentPreviewLoader ()
- (WKDocPreviewRequestSnapshot *)requestSnapshot;
- (void)finishFlight:(WKDocPreviewFlight *)flight result:(NSDictionary *)result;
- (void)cancelFlights:(NSArray<WKDocPreviewFlight *> *)flights manager:(AFHTTPSessionManager *)manager;
- (void)notifySessionChanged;
- (WKDocumentPreviewSubscription *)subscriptionForFlight:(WKDocPreviewFlight *)flight callbackID:(NSString *)callbackID;
- (void)cancelCallbackForKey:(NSString *)key requestID:(NSString *)requestID callbackID:(NSString *)callbackID;
@end

@implementation WKDocumentPreviewLoader {
    NSLock *_lock;
    NSMutableDictionary<NSString *, WKDocPreviewCacheEntry *> *_cache;
    NSMutableArray<NSString *> *_cacheOrder;
    NSMutableDictionary<NSString *, WKDocPreviewFlight *> *_inflight;
    NSString *_sessionOrigin;
    NSString *_sessionAPIBaseURL;
    NSString *_sessionUID;
    NSString *_sessionToken;
    NSUInteger _sessionGeneration;
    AFHTTPSessionManager *_manager;
}

+ (instancetype)shared {
    static WKDocumentPreviewLoader *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _lock = [NSLock new];
    _cache = [NSMutableDictionary dictionary];
    _cacheOrder = [NSMutableArray array];
    _inflight = [NSMutableDictionary dictionary];
    return self;
}

- (NSString *)endpointForKind:(NSString *)kind {
    if ([kind isEqualToString:@"board"]) return @"scene";
    if ([kind isEqualToString:@"sheet"]) return @"sheet";
    if ([kind isEqualToString:@"html"]) return @"html-preview";
    return @"content";
}

- (NSString *)languageHeaderForLanguage:(NSString *)language {
    language = language ?: @"zh-Hans";
    if ([language isEqualToString:@"zh-Hans"]) return @"zh-CN,zh;q=0.9,en;q=0.8";
    if ([language isEqualToString:@"zh-Hant"]) return @"zh-TW,zh;q=0.9,en;q=0.8";
    return @"en-US,en;q=0.9";
}

- (WKDocPreviewRequestSnapshot *)requestSnapshot {
    WKApp *app = WKApp.shared;
    NSString *apiBaseURL = app.config.apiBaseUrl ?: @"";
    NSURLComponents *components = [NSURLComponents componentsWithString:apiBaseURL];
    NSString *scheme = components.scheme.lowercaseString;
    if ((![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) || components.host.length == 0) return nil;
    NSString *origin = [NSString stringWithFormat:@"%@://%@%@",
        components.scheme.lowercaseString,
        components.host.lowercaseString,
        components.port ? [NSString stringWithFormat:@":%@", components.port] : @""];
    WKDocPreviewRequestSnapshot *snapshot = [WKDocPreviewRequestSnapshot new];
    snapshot.origin = origin;
    snapshot.apiBaseURL = apiBaseURL;
    snapshot.uid = app.loginInfo.uid ?: @"";
    snapshot.token = app.isLogined ? (app.loginInfo.token ?: @"") : @"";
    snapshot.language = app.config.langue ?: @"zh-Hans";
    return snapshot;
}

- (AFHTTPSessionManager *)managerForOrigin:(NSString *)origin {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.timeoutIntervalForRequest = 20.0;
    configuration.timeoutIntervalForResource = 20.0;
    configuration.URLCache = nil;
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:origin]
                                                              sessionConfiguration:configuration];
    manager.completionQueue = dispatch_queue_create("com.octo.document.preview.parse", DISPATCH_QUEUE_SERIAL);
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.requestSerializer.timeoutInterval = 20.0;
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/plain", @"text/javascript", nil];
    // A document endpoint must not forward the custom token header to a redirect target.
    [manager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest *(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request) {
        return nil;
    }];
    [manager setDataTaskDidReceiveResponseBlock:^NSURLSessionResponseDisposition(NSURLSession *session, NSURLSessionDataTask *task, NSURLResponse *response) {
        return response.expectedContentLength > WKDocPreviewMaxResponseBytes
            ? NSURLSessionResponseCancel : NSURLSessionResponseAllow;
    }];
    [manager setDataTaskDidReceiveDataBlock:^(NSURLSession *session, NSURLSessionDataTask *task, NSData *data) {
        if (task.countOfBytesReceived > WKDocPreviewMaxResponseBytes) [task cancel];
    }];
    return manager;
}

- (NSURLSessionDataTask *)requestKind:(NSString *)kind docId:(NSString *)docId spaceId:(NSString *)spaceId snapshot:(WKDocPreviewRequestSnapshot *)snapshot manager:(AFHTTPSessionManager *)manager completion:(void (^)(NSDictionary *, NSError *))completion {
    NSString *encodedId = [docId stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSString *path = [NSString stringWithFormat:@"/api/v1/docs/%@/%@", encodedId ?: docId, [self endpointForKind:kind]];
    NSURL *url = WKDocumentShareCardAbsoluteURL(path, snapshot.apiBaseURL);
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, [NSError errorWithDomain:@"WKDocPreview" code:0 userInfo:nil]);
        });
        return nil;
    }
    NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:@"GET" URLString:url.absoluteString parameters:nil error:nil];
    if (!request) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, [NSError errorWithDomain:@"WKDocPreview" code:0 userInfo:nil]);
        });
        return nil;
    }
    if (snapshot.token.length) [request setValue:snapshot.token forHTTPHeaderField:@"token"];
    if (spaceId.length) [request setValue:spaceId forHTTPHeaderField:@"X-Space-Id"];
    [request setValue:[self languageHeaderForLanguage:snapshot.language] forHTTPHeaderField:@"Accept-Language"];
    NSURLSessionDataTask *task = [manager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse *response, id object, NSError *error) {
        if (!error) { completion([object isKindOfClass:NSDictionary.class] ? object : @{}, nil); return; }
        NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : error.code;
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        NSData *data = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        id body = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([body isKindOfClass:NSDictionary.class] && [body[@"error"] isKindOfClass:NSString.class]) info[@"_wireErrorCode"] = body[@"error"];
        completion(nil, [NSError errorWithDomain:@"WKDocPreview" code:status userInfo:info]);
    }];
    return task;
}

- (NSString *)statusForError:(NSError *)error {
    if (error.code == 401) return @"unauthenticated";
    if (error.code == 403) return @"denied";
    if (error.code == 404 || error.code == 410) return @"unavailable";
    if (error.code == 409) {
        if ([error.userInfo[@"_wireErrorCode"] isEqualToString:@"unsupported_doc_type"]) return @"empty";
        if ([error.userInfo[@"_wireErrorCode"] isEqualToString:@"conflict"]) return @"unavailable";
    }
    return @"error";
}

- (NSURLSessionDataTask *)loadKind:(NSString *)kind docId:(NSString *)docId spaceId:(NSString *)spaceId snapshot:(WKDocPreviewRequestSnapshot *)snapshot manager:(AFHTTPSessionManager *)manager completion:(void (^)(NSDictionary *))completion {
    return [self requestKind:kind docId:docId spaceId:spaceId snapshot:snapshot manager:manager completion:^(NSDictionary *body, NSError *error) {
        if (error) { completion(@{@"status": [self statusForError:error]}); return; }
        NSDictionary *preview;
        if ([kind isEqualToString:@"board"]) preview = WKParseBoardPreview(body);
        else if ([kind isEqualToString:@"sheet"]) preview = WKParseSheetPreview(body);
        else if ([kind isEqualToString:@"html"]) preview = WKParseHTMLPreview(body);
        else preview = WKParseDocumentPreview(body);
        if (!preview) { completion(@{@"status": @"empty"}); return; }
        completion(@{@"status": @"ready", @"preview": preview});
    }];
}

- (WKDocumentPreviewSubscription *)fetchPreviewForKind:(NSString *)kind docId:(NSString *)docId spaceId:(NSString *)spaceId force:(BOOL)force callback:(void (^)(NSDictionary *))callback {
    if (!WKDocumentShareCardIsValidDocId(docId)
        || !WKDocumentShareCardIsValidDocId(spaceId)) {
        callback(@{@"status": @"error"});
        return nil;
    }
    [_lock lock];
    NSUInteger startingGeneration = _sessionGeneration;
    [_lock unlock];
    WKDocPreviewRequestSnapshot *snapshot = [self requestSnapshot];
    if (!snapshot) { callback(@{@"status": @"error"}); return nil; }
    if (snapshot.uid.length == 0 || snapshot.token.length == 0) {
        callback(@{@"status": @"unauthenticated"});
        return nil;
    }
    NSString *key = [NSString stringWithFormat:@"%@\0%@\0%@\0%@\0%@\0%@\0%@", snapshot.origin, snapshot.apiBaseURL, snapshot.uid, snapshot.language, kind ?: @"doc", docId, spaceId ?: @""];
    NSArray<WKDocPreviewFlight *> *invalidatedFlights = @[];
    AFHTTPSessionManager *invalidatedManager = nil;
    WKDocPreviewFlight *flight = nil;
    BOOL notifyChange = NO;
    [_lock lock];
    // A reset or account switch may have happened while the app snapshot was read.
    // Never let that old snapshot install itself as a new session.
    if (_sessionGeneration != startingGeneration
        && (![_sessionOrigin isEqualToString:snapshot.origin]
            || ![_sessionAPIBaseURL isEqualToString:snapshot.apiBaseURL]
            || ![_sessionUID isEqualToString:snapshot.uid]
            || ![_sessionToken isEqualToString:snapshot.token])) {
        [_lock unlock];
        callback(@{@"status": @"error"});
        return nil;
    }
    BOOL sessionChanged = ![_sessionOrigin isEqualToString:snapshot.origin]
        || ![_sessionAPIBaseURL isEqualToString:snapshot.apiBaseURL]
        || ![_sessionUID isEqualToString:snapshot.uid]
        || ![_sessionToken isEqualToString:snapshot.token];
    if (sessionChanged) {
        notifyChange = _sessionOrigin != nil;
        _sessionGeneration++;
        _sessionOrigin = [snapshot.origin copy];
        _sessionAPIBaseURL = [snapshot.apiBaseURL copy];
        _sessionUID = [snapshot.uid copy];
        _sessionToken = [snapshot.token copy];
        invalidatedManager = _manager;
        _manager = nil;
        [_cache removeAllObjects];
        [_cacheOrder removeAllObjects];
        invalidatedFlights = _inflight.allValues;
        for (WKDocPreviewFlight *oldFlight in invalidatedFlights) oldFlight.finished = YES;
        [_inflight removeAllObjects];
    }
    snapshot.generation = _sessionGeneration;
    WKDocPreviewCacheEntry *entry = _cache[key];
    if (entry && NSProcessInfo.processInfo.systemUptime - entry.timestamp >= WKDocPreviewCacheTTL) {
        [_cache removeObjectForKey:key];
        [_cacheOrder removeObject:key];
        entry = nil;
    }
    if (!force && entry && NSProcessInfo.processInfo.systemUptime - entry.timestamp < WKDocPreviewCacheTTL) {
        NSDictionary *cachedResult = entry.result;
        [_cacheOrder removeObject:key];
        [_cacheOrder addObject:key];
        [_lock unlock];
        [self cancelFlights:invalidatedFlights manager:invalidatedManager];
        if (notifyChange) [self notifySessionChanged];
        callback(cachedResult);
        return nil;
    }
    flight = _inflight[key];
    if (flight) {
        NSString *callbackID = NSUUID.UUID.UUIDString;
        flight.callbacks[callbackID] = [callback copy];
        WKDocumentPreviewSubscription *subscription = [self subscriptionForFlight:flight callbackID:callbackID];
        [_lock unlock];
        [self cancelFlights:invalidatedFlights manager:invalidatedManager];
        if (notifyChange) [self notifySessionChanged];
        return subscription;
    }
    flight = [WKDocPreviewFlight new];
    flight.requestID = NSUUID.UUID.UUIDString;
    flight.cacheKey = key;
    flight.snapshot = snapshot;
    NSString *callbackID = NSUUID.UUID.UUIDString;
    flight.callbacks = [NSMutableDictionary dictionaryWithObject:[callback copy] forKey:callbackID];
    WKDocumentPreviewSubscription *subscription = [self subscriptionForFlight:flight callbackID:callbackID];
    if (!_manager) _manager = [self managerForOrigin:snapshot.origin];
    flight.manager = _manager;
    _inflight[key] = flight;
    [_lock unlock];
    [self cancelFlights:invalidatedFlights manager:invalidatedManager];
    if (notifyChange) [self notifySessionChanged];

    __weak typeof(self) weakSelf = self;
    [_lock lock];
    if (flight.finished || _sessionGeneration != snapshot.generation || _inflight[key] != flight) {
        [_lock unlock];
        return subscription; // The invalidation path has already completed this flight's callbacks.
    }
    NSURLSessionDataTask *task = [self loadKind:kind docId:docId spaceId:spaceId snapshot:snapshot manager:flight.manager completion:^(NSDictionary *result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self) [self finishFlight:flight result:result];
    }];
    flight.task = task;
    if (task) [task resume];
    [_lock unlock];
    return subscription;
}

- (WKDocumentPreviewSubscription *)subscriptionForFlight:(WKDocPreviewFlight *)flight callbackID:(NSString *)callbackID {
    WKDocumentPreviewSubscription *subscription = [WKDocumentPreviewSubscription new];
    __weak typeof(self) weakSelf = self;
    NSString *key = [flight.cacheKey copy];
    NSString *requestID = [flight.requestID copy];
    subscription.cancellation = ^{
        [weakSelf cancelCallbackForKey:key requestID:requestID callbackID:callbackID];
    };
    return subscription;
}

- (void)cancelCallbackForKey:(NSString *)key requestID:(NSString *)requestID callbackID:(NSString *)callbackID {
    [_lock lock];
    WKDocPreviewFlight *flight = _inflight[key];
    if ([flight.requestID isEqualToString:requestID]) [flight.callbacks removeObjectForKey:callbackID];
    [_lock unlock];
}

- (void)finishFlight:(WKDocPreviewFlight *)flight result:(NSDictionary *)result {
    WKDocPreviewRequestSnapshot *currentSnapshot = [self requestSnapshot];
    BOOL sessionMatches = currentSnapshot
        && [currentSnapshot.origin isEqualToString:flight.snapshot.origin]
        && [currentSnapshot.apiBaseURL isEqualToString:flight.snapshot.apiBaseURL]
        && [currentSnapshot.uid isEqualToString:flight.snapshot.uid]
        && [currentSnapshot.token isEqualToString:flight.snapshot.token];
    NSArray<WKDocPreviewFlight *> *invalidatedFlights = @[];
    AFHTTPSessionManager *invalidatedManager = nil;
    NSArray *callbacks = @[];
    BOOL notifyChange = NO;
    [_lock lock];
    if (flight.finished) { [_lock unlock]; return; }
    WKDocPreviewFlight *current = _inflight[flight.cacheKey];
    BOOL ownsSlot = _sessionGeneration == flight.snapshot.generation
        && current == flight
        && [current.requestID isEqualToString:flight.requestID];
    if (!ownsSlot) { [_lock unlock]; return; }
    BOOL loaderSessionChanged = currentSnapshot
        ? (![_sessionOrigin isEqualToString:currentSnapshot.origin]
            || ![_sessionAPIBaseURL isEqualToString:currentSnapshot.apiBaseURL]
            || ![_sessionUID isEqualToString:currentSnapshot.uid]
            || ![_sessionToken isEqualToString:currentSnapshot.token])
        : (_sessionOrigin != nil || _sessionAPIBaseURL != nil || _sessionUID != nil || _sessionToken != nil);
    if (loaderSessionChanged) {
        // A session switch can happen without another card request being issued.
        // Detect it here too, so all outstanding work becomes stale immediately.
        notifyChange = _sessionOrigin != nil;
        _sessionGeneration++;
        _sessionOrigin = [currentSnapshot.origin copy];
        _sessionAPIBaseURL = [currentSnapshot.apiBaseURL copy];
        _sessionUID = [currentSnapshot.uid copy];
        _sessionToken = [currentSnapshot.token copy];
        invalidatedManager = _manager;
        _manager = nil;
        [_cache removeAllObjects];
        [_cacheOrder removeAllObjects];
        invalidatedFlights = _inflight.allValues;
        for (WKDocPreviewFlight *oldFlight in invalidatedFlights) oldFlight.finished = YES;
        [_inflight removeAllObjects];
        [_lock unlock];
        [self cancelFlights:invalidatedFlights manager:invalidatedManager];
        if (notifyChange) [self notifySessionChanged];
        return;
    }

    flight.finished = YES;
    callbacks = [flight.callbacks.allValues copy];
    flight.callbacks = nil;
    [_inflight removeObjectForKey:flight.cacheKey];
    if (sessionMatches && ![result[@"status"] isEqualToString:@"error"]) {
        WKDocPreviewCacheEntry *entry = [WKDocPreviewCacheEntry new];
        entry.result = result;
        entry.timestamp = NSProcessInfo.processInfo.systemUptime;
        _cache[flight.cacheKey] = entry;
        [_cacheOrder removeObject:flight.cacheKey];
        [_cacheOrder addObject:flight.cacheKey];
        NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
        for (NSString *key in [_cacheOrder copy]) {
            WKDocPreviewCacheEntry *cached = _cache[key];
            if (!cached || now - cached.timestamp >= WKDocPreviewCacheTTL) {
                [_cache removeObjectForKey:key];
                [_cacheOrder removeObject:key];
            }
        }
        while (_cacheOrder.count > WKDocPreviewMaxCacheEntries) {
            NSString *oldest = _cacheOrder.firstObject;
            [_cache removeObjectForKey:oldest];
            [_cacheOrder removeObjectAtIndex:0];
        }
    }
    flight.task = nil;
    flight.manager = nil;
    [_lock unlock];
    NSDictionary *finalResult = sessionMatches ? result : @{@"status": @"error"};
    for (void (^callback)(NSDictionary *) in callbacks) callback(finalResult);
}

- (void)cancelFlights:(NSArray<WKDocPreviewFlight *> *)flights manager:(AFHTTPSessionManager *)manager {
    for (WKDocPreviewFlight *flight in flights) [flight.task cancel];
    WKInvalidateDocPreviewManager(manager);
    for (WKDocPreviewFlight *flight in flights) {
        NSArray *callbacks = [flight.callbacks.allValues copy];
        flight.callbacks = nil;
        flight.task = nil;
        flight.manager = nil;
        for (void (^callback)(NSDictionary *) in callbacks) callback(@{@"status": @"error"});
    }
}

- (void)notifySessionChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:WKDocumentPreviewSessionDidChangeNotification object:self];
    });
}

- (void)resetCache {
    [_lock lock];
    _sessionGeneration++;
    [_cache removeAllObjects];
    [_cacheOrder removeAllObjects];
    NSArray<WKDocPreviewFlight *> *invalidatedFlights = _inflight.allValues;
    for (WKDocPreviewFlight *flight in invalidatedFlights) flight.finished = YES;
    [_inflight removeAllObjects];
    AFHTTPSessionManager *invalidatedManager = _manager;
    _manager = nil;
    _sessionOrigin = nil;
    _sessionAPIBaseURL = nil;
    _sessionUID = nil;
    _sessionToken = nil;
    [_lock unlock];
    [self cancelFlights:invalidatedFlights manager:invalidatedManager];
    [self notifySessionChanged];
}

@end
