//
//  WKDocumentPreviewLoader.m
//  WuKongBase
//

#import "WKDocumentPreviewLoader.h"
#import "WuKongBase.h"
#import <AFNetworking/AFNetworking.h>

static const NSUInteger WKDocPreviewMaxTextLength = 500;
static const NSUInteger WKDocPreviewMaxParagraphs = 3;
static const NSUInteger WKDocPreviewMaxBlocks = 200;
static const NSUInteger WKDocPreviewMaxDepth = 20;
static const NSUInteger WKDocPreviewMaxSheetRows = 3;
static const NSUInteger WKDocPreviewMaxSheetColumns = 5;
static const NSUInteger WKDocPreviewMaxSheetCellsScanned = 4000;
static const NSTimeInterval WKDocPreviewCacheTTL = 30.0;

static NSString *WKDocString(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSString *WKDocCollectText(id node, NSUInteger depth) {
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
        [result appendString:WKDocCollectText(child, depth + 1)];
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
    NSUInteger count = MIN(blocks.count, WKDocPreviewMaxBlocks);
    for (NSUInteger i = 0; i < count; i++) {
        id block = blocks[i];
        if (![block isKindOfClass:NSDictionary.class]) continue;
        NSString *text = [WKDocCollectText(block, 0) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
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
    for (id element in elements) {
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
    NSUInteger scanned = 0;
    for (id rawKey in cells) {
        if (++scanned > WKDocPreviewMaxSheetCellsScanned) break;
        if (![rawKey isKindOfClass:NSString.class]) continue;
        NSString *key = rawKey;
        NSTextCheckingResult *match = [regex firstMatchInString:key options:0 range:NSMakeRange(0, key.length)];
        if (match.numberOfRanges != 4) continue;
        NSInteger row = [[key substringWithRange:[match rangeAtIndex:2]] integerValue];
        NSInteger col = [[key substringWithRange:[match rangeAtIndex:3]] integerValue];
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
    for (NSDictionary *rows in sheets.allValues) {
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

@interface WKDocPreviewCacheEntry : NSObject
@property(nonatomic, copy) NSDictionary *result;
@property(nonatomic, assign) NSTimeInterval timestamp;
@end
@implementation WKDocPreviewCacheEntry
@end

@interface WKDocumentPreviewLoader ()
@property(nonatomic, strong) AFHTTPSessionManager *manager;
@end

@implementation WKDocumentPreviewLoader {
    NSLock *_lock;
    NSMutableDictionary<NSString *, WKDocPreviewCacheEntry *> *_cache;
    NSMutableDictionary<NSString *, NSMutableArray *> *_inflight;
    NSString *_cacheUID;
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
    _inflight = [NSMutableDictionary dictionary];
    NSURLComponents *components = [NSURLComponents componentsWithString:WKApp.shared.config.apiBaseUrl ?: @""];
    NSString *origin = components.scheme.length && components.host.length
        ? [NSString stringWithFormat:@"%@://%@%@", components.scheme, components.host, components.port ? [NSString stringWithFormat:@":%@", components.port] : @""]
        : WKApp.shared.config.apiBaseUrl;
    _manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:origin]];
    _manager.requestSerializer = [AFJSONRequestSerializer serializer];
    _manager.responseSerializer = [AFJSONResponseSerializer serializer];
    _manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/plain", @"text/javascript", nil];
    return self;
}

- (NSString *)endpointForKind:(NSString *)kind {
    if ([kind isEqualToString:@"board"]) return @"scene";
    if ([kind isEqualToString:@"sheet"]) return @"sheet";
    if ([kind isEqualToString:@"html"]) return @"html-preview";
    return @"content";
}

- (NSString *)languageHeader {
    NSString *language = WKApp.shared.config.langue ?: @"zh-Hans";
    if ([language isEqualToString:@"zh-Hans"]) return @"zh-CN,zh;q=0.9,en;q=0.8";
    if ([language isEqualToString:@"zh-Hant"]) return @"zh-TW,zh;q=0.9,en;q=0.8";
    return @"en-US,en;q=0.9";
}

- (void)requestKind:(NSString *)kind docId:(NSString *)docId spaceId:(NSString *)spaceId completion:(void (^)(NSDictionary *, NSError *))completion {
    NSString *encodedId = [docId stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSString *path = [NSString stringWithFormat:@"/api/v1/docs/%@/%@", encodedId ?: docId, [self endpointForKind:kind]];
    NSURL *url = [[NSURL URLWithString:path relativeToURL:self.manager.baseURL] absoluteURL];
    if (!url) { completion(nil, [NSError errorWithDomain:@"WKDocPreview" code:0 userInfo:nil]); return; }
    NSMutableURLRequest *request = [self.manager.requestSerializer requestWithMethod:@"GET" URLString:url.absoluteString parameters:nil error:nil];
    if (WKApp.shared.isLogined && WKApp.shared.loginInfo.token.length) [request setValue:WKApp.shared.loginInfo.token forHTTPHeaderField:@"token"];
    if (spaceId.length) [request setValue:spaceId forHTTPHeaderField:@"X-Space-Id"];
    [request setValue:[self languageHeader] forHTTPHeaderField:@"Accept-Language"];
    NSURLSessionDataTask *task = [self.manager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse *response, id object, NSError *error) {
        if (!error) { completion([object isKindOfClass:NSDictionary.class] ? object : @{}, nil); return; }
        NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : error.code;
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        NSData *data = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        id body = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if ([body isKindOfClass:NSDictionary.class] && [body[@"error"] isKindOfClass:NSString.class]) info[@"_wireErrorCode"] = body[@"error"];
        completion(nil, [NSError errorWithDomain:@"WKDocPreview" code:status userInfo:info]);
    }];
    [task resume];
}

- (NSString *)statusForError:(NSError *)error {
    if (error.code == 403) return @"denied";
    if (error.code == 404 || error.code == 410) return @"unavailable";
    if (error.code == 409) {
        if ([error.userInfo[@"_wireErrorCode"] isEqualToString:@"unsupported_doc_type"]) return @"empty";
        if ([error.userInfo[@"_wireErrorCode"] isEqualToString:@"conflict"]) return @"unavailable";
    }
    return @"error";
}

- (void)loadKind:(NSString *)kind docId:(NSString *)docId spaceId:(NSString *)spaceId completion:(void (^)(NSDictionary *))completion {
    [self requestKind:kind docId:docId spaceId:spaceId completion:^(NSDictionary *body, NSError *error) {
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

- (void)fetchPreviewForKind:(NSString *)kind docId:(NSString *)docId spaceId:(NSString *)spaceId force:(BOOL)force callback:(void (^)(NSDictionary *))callback {
    if (docId.length == 0) { callback(@{@"status": @"error"}); return; }
    NSString *uid = WKApp.shared.loginInfo.uid ?: @"";
    NSString *key = [NSString stringWithFormat:@"%@\0%@\0%@\0%@", uid, kind ?: @"doc", docId, spaceId ?: @""];
    [_lock lock];
    if (![_cacheUID isEqualToString:uid]) { [_cache removeAllObjects]; [_inflight removeAllObjects]; _cacheUID = uid; }
    WKDocPreviewCacheEntry *entry = _cache[key];
    if (!force && entry && NSDate.date.timeIntervalSince1970 - entry.timestamp < WKDocPreviewCacheTTL) {
        NSDictionary *cachedResult = entry.result;
        [_lock unlock];
        callback(cachedResult);
        return;
    }
    NSMutableArray *waiters = _inflight[key];
    if (waiters) { [waiters addObject:[callback copy]]; [_lock unlock]; return; }
    _inflight[key] = [NSMutableArray arrayWithObject:[callback copy]];
    [_lock unlock];
    __weak typeof(self) weakSelf = self;
    [self loadKind:kind docId:docId spaceId:spaceId completion:^(NSDictionary *result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self->_lock lock];
        NSArray *callbacks = [self->_inflight[key] copy] ?: @[];
        [self->_inflight removeObjectForKey:key];
        if (![result[@"status"] isEqualToString:@"error"]) {
            WKDocPreviewCacheEntry *newEntry = [WKDocPreviewCacheEntry new];
            newEntry.result = result;
            newEntry.timestamp = NSDate.date.timeIntervalSince1970;
            self->_cache[key] = newEntry;
        }
        [self->_lock unlock];
        for (void (^waiter)(NSDictionary *) in callbacks) waiter(result);
    }];
}

- (void)resetCache {
    [_lock lock];
    [_cache removeAllObjects];
    [_inflight removeAllObjects];
    _cacheUID = nil;
    [_lock unlock];
}

@end
