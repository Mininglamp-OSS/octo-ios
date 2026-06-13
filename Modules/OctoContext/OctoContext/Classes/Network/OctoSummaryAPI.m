//
//  OctoSummaryAPI.m
//  OctoContext
//

#import "OctoSummaryAPI.h"
#import <WuKongBase/WuKongBase.h>
#import <AFNetworking/AFNetworking.h>

@interface OctoSummaryAPI ()
@property(nonatomic, strong) AFHTTPSessionManager *manager;
@end

@implementation OctoSummaryAPI

+ (instancetype)shared {
    static OctoSummaryAPI *inst;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ inst = [[self alloc] init]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        // baseURL 取主 API host 末尾不带斜杠;BASE_PATH 在每个调用里拼。
        NSString *base = [WKApp shared].config.apiBaseUrl ?: @"";
        if ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
        // dmworksummary baseURL 是 ''(同源相对),iOS 这边需要绝对地址。
        // 后端 web 网关是 host/summary/api/v1, host 与 IM API 一致,
        // 所以这里直接拿 apiBaseUrl 的 host 部分。apiBaseUrl 形如
        // "https://api.example.com/v1",截掉末尾 path 留 host。
        NSURL *u = [NSURL URLWithString:base];
        NSString *origin = u.scheme && u.host
            ? [NSString stringWithFormat:@"%@://%@%@",
               u.scheme, u.host, (u.port ? [@":" stringByAppendingFormat:@"%@", u.port] : @"")]
            : base;
        _manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:origin]];
        _manager.requestSerializer  = [AFJSONRequestSerializer serializer];
        _manager.responseSerializer = [AFJSONResponseSerializer serializer];
        _manager.responseSerializer.acceptableContentTypes =
            [NSSet setWithObjects:@"application/json", @"text/json", @"text/plain", @"text/javascript", nil];
    }
    return self;
}

- (NSString *)acceptLanguage {
    NSString *lang = [WKApp shared].config.langue ?: @"zh-Hans";
    if ([lang isEqualToString:@"zh-Hans"]) return @"zh-CN,zh;q=0.9,en;q=0.8";
    if ([lang isEqualToString:@"zh-Hant"]) return @"zh-TW,zh;q=0.9,en;q=0.8";
    return @"en-US,en;q=0.9";
}

- (void)applyCommonHeaders:(NSMutableURLRequest *)req {
    if ([WKApp shared].isLogined && [WKApp shared].loginInfo.token.length > 0) {
        [req setValue:[WKApp shared].loginInfo.token forHTTPHeaderField:@"token"];
    }
    NSString *spaceId = [[WKSpaceFilter shared] currentSpaceId];
    if (spaceId.length > 0) {
        [req setValue:spaceId forHTTPHeaderField:@"X-Space-Id"];
    }
    [req setValue:[self acceptLanguage] forHTTPHeaderField:@"Accept-Language"];
}

#pragma mark - Internal request

- (NSString *)fullPath:(NSString *)path {
    if ([path hasPrefix:@"/"]) return [@"/summary/api/v1" stringByAppendingString:path];
    return [@"/summary/api/v1/" stringByAppendingString:path];
}

/// 统一请求入口。method ∈ {GET, POST, PUT, DELETE}。
/// 响应包 {code, message, data} 解开 data 返回；transform 把 data 转成模型。
- (void)request:(NSString *)method
           path:(NSString *)path
     parameters:(nullable id)parameters
      transform:(id _Nullable (^)(id _Nullable rawData))transform
       callback:(OctoSummaryCallback)cb {

    NSString *url = [[NSURL URLWithString:[self fullPath:path] relativeToURL:_manager.baseURL] absoluteString];
    NSError *serErr = nil;
    NSMutableURLRequest *req = [_manager.requestSerializer
        requestWithMethod:method URLString:url parameters:parameters error:&serErr];
    if (serErr) {
        if (cb) cb(nil, serErr);
        return;
    }
    [self applyCommonHeaders:req];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [_manager dataTaskWithRequest:req
                                                uploadProgress:nil
                                              downloadProgress:nil
                                             completionHandler:^(NSURLResponse * _Nonnull resp, id _Nullable obj, NSError * _Nullable err) {
        if (err) {
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
            if (http.statusCode == 401) {
                [[WKApp shared] logout];
            }
            // 把 statusCode 透出到 NSError.code,供 editSummary 区分 409
            NSMutableDictionary *ui = [(err.userInfo ?: @{}) mutableCopy];
            ui[@"_httpStatus"] = @(http.statusCode);
            // 尝试解析后端 message
            NSData *data = ui[AFNetworkingOperationFailingURLResponseDataErrorKey];
            NSString *msg = nil;
            if (data) {
                NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([d isKindOfClass:NSDictionary.class]) {
                    msg = d[@"message"] ?: d[@"msg"];
                }
            }
            NSError *finalErr = [NSError errorWithDomain:@"OctoSummary"
                                                    code:(http.statusCode > 0 ? http.statusCode : err.code)
                                                userInfo:msg ? @{NSLocalizedDescriptionKey: msg, @"_httpStatus": @(http.statusCode)} : ui];
            if (cb) cb(nil, finalErr);
            return;
        }
        // 解开 envelope
        id data = obj;
        if ([obj isKindOfClass:NSDictionary.class]) {
            id maybeData = ((NSDictionary *)obj)[@"data"];
            if (maybeData && maybeData != [NSNull null]) data = maybeData;
        }
        id transformed = transform ? transform(data) : data;
        if (cb) cb(transformed, nil);
        (void)weakSelf;
    }];
    [task resume];
}

#pragma mark - Endpoints

- (void)createSummaryWithParams:(NSDictionary *)params callback:(OctoSummaryCallback)cb {
    [self request:@"POST" path:@"/summaries" parameters:params transform:nil callback:cb];
}

- (void)listSummariesWithParams:(NSDictionary *)params callback:(OctoSummaryCallback)cb {
    [self request:@"GET" path:@"/summaries" parameters:params
        transform:^id _Nullable(id _Nullable raw) {
            if (![raw isKindOfClass:NSDictionary.class]) return @{@"items": @[], @"total": @0};
            NSDictionary *d = raw;
            NSMutableArray *items = [NSMutableArray array];
            for (NSDictionary *it in d[@"items"]) {
                if ([it isKindOfClass:NSDictionary.class]) {
                    OctoSummaryListItem *m = [OctoSummaryListItem modelFromDict:it];
                    if (m) [items addObject:m];
                }
            }
            return @{@"items": items, @"total": d[@"total"] ?: @(items.count)};
        }
        callback:cb];
}

- (void)getSummaryDetail:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"GET" path:[NSString stringWithFormat:@"/summaries/%lld", taskId]
       parameters:nil
        transform:^id _Nullable(id _Nullable raw) {
            return [raw isKindOfClass:NSDictionary.class] ? [OctoSummaryDetail modelFromDict:raw] : nil;
        } callback:cb];
}

- (void)deleteSummary:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"DELETE" path:[NSString stringWithFormat:@"/summaries/%lld", taskId]
       parameters:nil transform:nil callback:cb];
}

- (void)regenerateSummary:(int64_t)taskId topic:(NSString *)topic callback:(OctoSummaryCallback)cb {
    NSDictionary *body = topic.length > 0 ? @{@"topic": topic} : nil;
    [self request:@"POST"
             path:[NSString stringWithFormat:@"/summaries/%lld/regenerate", taskId]
       parameters:body transform:nil callback:cb];
}

- (void)editSummary:(int64_t)taskId
            content:(NSString *)content
       baseResultId:(int64_t)baseResultId
           callback:(OctoSummaryCallback)cb {
    [self request:@"PUT"
             path:[NSString stringWithFormat:@"/summaries/%lld/edit", taskId]
       parameters:@{@"content": content ?: @"", @"base_result_id": @(baseResultId)}
        transform:nil callback:cb];
}

- (void)batchStatus:(NSArray<NSNumber *> *)taskIds callback:(OctoSummaryCallback)cb {
    [self request:@"POST" path:@"/summaries/batch-status"
       parameters:@{@"task_ids": taskIds ?: @[]}
        transform:^id _Nullable(id _Nullable raw) {
            NSArray *tasks = nil;
            if ([raw isKindOfClass:NSDictionary.class]) tasks = raw[@"tasks"];
            if (![tasks isKindOfClass:NSArray.class]) tasks = @[];
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *d in tasks) {
                if ([d isKindOfClass:NSDictionary.class]) {
                    OctoBatchStatusItem *m = [OctoBatchStatusItem modelFromDict:d];
                    if (m) [out addObject:m];
                }
            }
            return out;
        } callback:cb];
}

- (void)cancelSummary:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"POST"
             path:[NSString stringWithFormat:@"/summaries/%lld/cancel", taskId]
       parameters:nil transform:nil callback:cb];
}

- (void)confirmParticipation:(int64_t)taskId
                     sources:(NSArray<OctoSourceItem *> *)sources
                    callback:(OctoSummaryCallback)cb {
    NSMutableArray *arr = [NSMutableArray array];
    for (OctoSourceItem *s in sources) {
        [arr addObject:@{@"source_type": @(s.sourceType), @"source_id": s.sourceId ?: @""}];
    }
    [self request:@"POST"
             path:[NSString stringWithFormat:@"/summaries/%lld/confirm", taskId]
       parameters:@{@"sources": arr}
        transform:nil callback:cb];
}

- (void)declineParticipation:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"POST"
             path:[NSString stringWithFormat:@"/summaries/%lld/decline", taskId]
       parameters:nil transform:nil callback:cb];
}

- (void)acceptInvitation:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"POST"
             path:[NSString stringWithFormat:@"/summaries/%lld/accept", taskId]
       parameters:nil transform:nil callback:cb];
}

- (void)respondToTask:(int64_t)taskId action:(NSString *)action callback:(OctoSummaryCallback)cb {
    [self request:@"POST"
             path:[NSString stringWithFormat:@"/summaries/%lld/respond", taskId]
       parameters:@{@"action": action ?: @"accept"} transform:nil callback:cb];
}

- (void)getPersonalResult:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"GET"
             path:[NSString stringWithFormat:@"/summaries/%lld/personal", taskId]
       parameters:nil
        transform:^id _Nullable(id _Nullable raw) {
            return [raw isKindOfClass:NSDictionary.class] ? [OctoPersonalResult modelFromDict:raw] : nil;
        } callback:cb];
}

- (void)submitPersonalResult:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"POST"
             path:[NSString stringWithFormat:@"/summaries/%lld/submit", taskId]
       parameters:nil transform:nil callback:cb];
}

- (void)getMembers:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"GET"
             path:[NSString stringWithFormat:@"/summaries/%lld/members", taskId]
       parameters:nil
        transform:^id _Nullable(id _Nullable raw) {
            NSArray *arr = nil;
            if ([raw isKindOfClass:NSDictionary.class]) arr = raw[@"members"];
            if (![arr isKindOfClass:NSArray.class]) arr = @[];
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *d in arr) {
                if ([d isKindOfClass:NSDictionary.class]) {
                    OctoMemberStatus *m = [OctoMemberStatus modelFromDict:d];
                    if (m) [out addObject:m];
                }
            }
            return out;
        } callback:cb];
}

- (void)getParticipants:(int64_t)taskId callback:(OctoSummaryCallback)cb {
    [self request:@"GET"
             path:[NSString stringWithFormat:@"/summaries/%lld/participants", taskId]
       parameters:nil
        transform:^id _Nullable(id _Nullable raw) {
            NSArray *arr = nil;
            if ([raw isKindOfClass:NSDictionary.class]) arr = raw[@"participants"];
            if (![arr isKindOfClass:NSArray.class]) arr = @[];
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *d in arr) {
                if ([d isKindOfClass:NSDictionary.class]) {
                    OctoParticipant *p = [OctoParticipant modelFromDict:d];
                    if (p) [out addObject:p];
                }
            }
            return out;
        } callback:cb];
}

- (void)getTopicTemplates:(OctoSummaryCallback)cb {
    [self request:@"GET" path:@"/summary-templates" parameters:nil
        transform:^id _Nullable(id _Nullable raw) {
            NSArray *arr = nil;
            if ([raw isKindOfClass:NSDictionary.class]) arr = raw[@"templates"];
            if (![arr isKindOfClass:NSArray.class]) arr = @[];
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *d in arr) {
                if ([d isKindOfClass:NSDictionary.class]) {
                    OctoTopicTemplate *t = [OctoTopicTemplate modelFromDict:d];
                    if (t) [out addObject:t];
                }
            }
            return out;
        } callback:cb];
}

- (void)inferScope:(NSString *)topic callback:(OctoSummaryCallback)cb {
    [self request:@"GET" path:@"/summary-infer"
       parameters:@{@"topic": topic ?: @""}
        transform:nil callback:cb];
}

- (void)getChatCandidates:(NSDictionary *)params callback:(OctoSummaryCallback)cb {
    [self request:@"GET" path:@"/summary-chat-candidates" parameters:params
        transform:^id _Nullable(id _Nullable raw) {
            if (![raw isKindOfClass:NSArray.class]) return @[];
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *d in raw) {
                if ([d isKindOfClass:NSDictionary.class]) {
                    OctoChatCandidate *c = [OctoChatCandidate modelFromDict:d];
                    if (c) [out addObject:c];
                }
            }
            return out;
        } callback:cb];
}

- (void)getMemberCandidates:(NSDictionary *)params callback:(OctoSummaryCallback)cb {
    [self request:@"GET" path:@"/summary-member-candidates" parameters:params
        transform:^id _Nullable(id _Nullable raw) {
            if (![raw isKindOfClass:NSArray.class]) return @[];
            NSMutableArray *out = [NSMutableArray array];
            for (NSDictionary *d in raw) {
                if ([d isKindOfClass:NSDictionary.class]) {
                    OctoMemberCandidate *c = [OctoMemberCandidate modelFromDict:d];
                    if (c) [out addObject:c];
                }
            }
            return out;
        } callback:cb];
}

@end
