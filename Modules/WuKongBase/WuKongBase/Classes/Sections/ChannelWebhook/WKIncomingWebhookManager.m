//
//  WKIncomingWebhookManager.m
//  WuKongBase
//

#import "WKIncomingWebhookManager.h"
#import "WKAPIClient.h"

#define WK_WEBHOOK_TEST_COOLDOWN_SEC 3.0

@interface WKIncomingWebhookManager ()
@property(nonatomic,assign) BOOL hasTestInFlight;
// webhookId -> 冷却失效时间戳（绝对秒）
@property(nonatomic,strong) NSMutableDictionary<NSString *, NSNumber *> *cooldownExpire;
@end

@implementation WKIncomingWebhookManager

+ (instancetype)shared {
    static WKIncomingWebhookManager *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [WKIncomingWebhookManager new]; });
    return inst;
}

- (instancetype)init {
    if (self = [super init]) {
        _cooldownExpire = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - List

- (void)listWebhooksOfGroup:(NSString *)groupNo
                   complete:(void(^)(NSArray<WKIncomingWebhook *> *, NSError * _Nullable))complete {
    NSString *path = [NSString stringWithFormat:@"groups/%@/incoming-webhooks", groupNo ?: @""];
    [[WKAPIClient sharedClient] GET:path parameters:nil].then(^(id resp) {
        NSMutableArray<WKIncomingWebhook *> *out = [NSMutableArray array];
        NSArray *list = nil;
        if ([resp isKindOfClass:[NSDictionary class]]) {
            list = resp[@"list"];
        } else if ([resp isKindOfClass:[NSArray class]]) {
            // 兜底：少数接口 fallback 直接给数组
            list = resp;
        }
        if ([list isKindOfClass:[NSArray class]]) {
            for (id item in list) {
                if ([item isKindOfClass:[NSDictionary class]]) {
                    [out addObject:[WKIncomingWebhook fromDict:item]];
                }
            }
        }
        if (complete) complete(out, nil);
    }).catch(^(NSError *err) {
        if (complete) complete(@[], err);
    });
}

#pragma mark - Create / Update / Delete / Regenerate

- (NSDictionary *)buildUpsertParamsWithName:(NSString *)name
                                     avatar:(NSString *)avatar
                                     status:(NSNumber *)status {
    NSMutableDictionary *req = [NSMutableDictionary dictionary];
    if (name) req[@"name"] = name;
    if (avatar) req[@"avatar"] = avatar;
    if (status) req[@"status"] = status;
    return req;
}

- (void)createWebhookForGroup:(NSString *)groupNo
                         name:(NSString *)name
                       avatar:(NSString *)avatar
                     complete:(void(^)(WKIncomingWebhook *, NSError *))complete {
    NSString *path = [NSString stringWithFormat:@"groups/%@/incoming-webhooks", groupNo ?: @""];
    NSDictionary *params = [self buildUpsertParamsWithName:name avatar:avatar status:nil];
    [[WKAPIClient sharedClient] POST:path parameters:params].then(^(id resp) {
        if (![resp isKindOfClass:[NSDictionary class]]) {
            if (complete) complete(nil, [NSError errorWithDomain:@"响应格式异常" code:-1 userInfo:nil]);
            return;
        }
        WKIncomingWebhook *h = [WKIncomingWebhook fromDict:resp];
        if (complete) complete(h, nil);
    }).catch(^(NSError *err) {
        if (complete) complete(nil, err);
    });
}

- (void)updateWebhook:(NSString *)webhookId
              ofGroup:(NSString *)groupNo
                 name:(NSString *)name
               avatar:(NSString *)avatar
               status:(NSNumber *)status
             complete:(void(^)(NSError *))complete {
    NSString *path = [NSString stringWithFormat:@"groups/%@/incoming-webhooks/%@", groupNo ?: @"", webhookId ?: @""];
    NSDictionary *params = [self buildUpsertParamsWithName:name avatar:avatar status:status];
    [[WKAPIClient sharedClient] PUT:path parameters:params].then(^(id resp) {
        if (complete) complete(nil);
    }).catch(^(NSError *err) {
        if (complete) complete(err);
    });
}

- (void)deleteWebhook:(NSString *)webhookId
              ofGroup:(NSString *)groupNo
             complete:(void(^)(NSError *))complete {
    NSString *path = [NSString stringWithFormat:@"groups/%@/incoming-webhooks/%@", groupNo ?: @"", webhookId ?: @""];
    [[WKAPIClient sharedClient] DELETE:path parameters:nil].then(^(id resp) {
        if (complete) complete(nil);
    }).catch(^(NSError *err) {
        if (complete) complete(err);
    });
}

- (void)regenerateWebhook:(NSString *)webhookId
                  ofGroup:(NSString *)groupNo
                 complete:(void(^)(WKIncomingWebhook *, NSError *))complete {
    NSString *path = [NSString stringWithFormat:@"groups/%@/incoming-webhooks/%@/regenerate", groupNo ?: @"", webhookId ?: @""];
    [[WKAPIClient sharedClient] POST:path parameters:nil].then(^(id resp) {
        if (![resp isKindOfClass:[NSDictionary class]]) {
            if (complete) complete(nil, [NSError errorWithDomain:@"响应格式异常" code:-1 userInfo:nil]);
            return;
        }
        WKIncomingWebhook *h = [WKIncomingWebhook fromDict:resp];
        if (complete) complete(h, nil);
    }).catch(^(NSError *err) {
        if (complete) complete(nil, err);
    });
}

#pragma mark - Test (with serialization + per-webhook cooldown)

- (BOOL)isWebhookOnTestCooldown:(NSString *)webhookId {
    if (webhookId.length == 0) return NO;
    NSNumber *expire = self.cooldownExpire[webhookId];
    if (!expire) return NO;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now >= expire.doubleValue) {
        [self.cooldownExpire removeObjectForKey:webhookId];
        return NO;
    }
    return YES;
}

- (void)testWebhook:(NSString *)webhookId
            ofGroup:(NSString *)groupNo
           complete:(void(^)(BOOL, NSError *))complete {
    // 守卫：全局串行 + 单条冷却。命中即静默忽略（UI 应该提前禁用按钮，这里只是保险）。
    if (self.hasTestInFlight || [self isWebhookOnTestCooldown:webhookId]) {
        if (complete) complete(NO, nil);
        return;
    }
    self.hasTestInFlight = YES;

    NSString *path = [NSString stringWithFormat:@"groups/%@/incoming-webhooks/%@/test", groupNo ?: @"", webhookId ?: @""];
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] POST:path parameters:nil].then(^(id resp) {
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;
        self_.hasTestInFlight = NO;
        // 进入单条冷却
        if (webhookId.length > 0) {
            NSTimeInterval expire = [[NSDate date] timeIntervalSince1970] + WK_WEBHOOK_TEST_COOLDOWN_SEC;
            self_.cooldownExpire[webhookId] = @(expire);
        }
        if (complete) complete(YES, nil);
    }).catch(^(NSError *err) {
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;
        self_.hasTestInFlight = NO;
        // 失败也进入冷却 —— 失败常因 401/429/网络抖动，不冷却会被瞬间再点产生雪崩。
        if (webhookId.length > 0) {
            NSTimeInterval expire = [[NSDate date] timeIntervalSince1970] + WK_WEBHOOK_TEST_COOLDOWN_SEC;
            self_.cooldownExpire[webhookId] = @(expire);
        }
        if (complete) complete(NO, err);
    });
}

@end
