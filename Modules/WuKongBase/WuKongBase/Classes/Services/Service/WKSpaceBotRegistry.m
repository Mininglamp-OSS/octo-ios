//
//  WKSpaceBotRegistry.m
//  WuKongBase
//

#import "WKSpaceBotRegistry.h"
#import "WKAPIClient.h"

NSString * const WKSpaceBotRegistryDidLoadNotification = @"WKSpaceBotRegistryDidLoadNotification";

@interface WKSpaceBotRegistry ()
/// spaceId → NSSet<NSString*>（已加载的 Bot UID 集合）。@synchronized(self) 互斥。
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSSet<NSString *> *> *spaceBotMap;
/// spaceId → @[completion...]（同 Space 并发请求合并）。
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *pendingCompletions;
@end

@implementation WKSpaceBotRegistry

+ (instancetype)shared {
    static WKSpaceBotRegistry *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKSpaceBotRegistry alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _spaceBotMap = [NSMutableDictionary dictionary];
        _pendingCompletions = [NSMutableDictionary dictionary];
    }
    return self;
}

- (WKSpaceBotMembership)membershipForBotUID:(NSString *)botUID
                                    inSpace:(NSString *)spaceId {
    if (botUID.length == 0 || spaceId.length == 0) {
        return WKSpaceBotMembershipUnknown;
    }
    @synchronized (self) {
        NSSet<NSString *> *set = self.spaceBotMap[spaceId];
        if (!set) {
            return WKSpaceBotMembershipUnknown;
        }
        return [set containsObject:botUID]
            ? WKSpaceBotMembershipMember
            : WKSpaceBotMembershipNotMember;
    }
}

- (void)resetAllCaches {
    @synchronized (self) {
        [self.spaceBotMap removeAllObjects];
        // pendingCompletions 不清：即将完成的请求继续回调
    }
}

- (void)loadBotsForSpace:(NSString *)spaceId
              completion:(void (^)(BOOL))completion {
    if (spaceId.length == 0) {
        if (completion) completion(NO);
        return;
    }

    // 同 Space 并发合并：已有 pending 请求时只追加 completion，不再发起新的 HTTP。
    @synchronized (self) {
        NSMutableArray *queue = self.pendingCompletions[spaceId];
        if (queue) {
            if (completion) [queue addObject:[completion copy]];
            return;
        }
        queue = [NSMutableArray array];
        if (completion) [queue addObject:[completion copy]];
        self.pendingCompletions[spaceId] = queue;
    }

    __block NSArray *myBots = nil;
    __block NSArray *spaceBots = nil;
    __block int pending = 2;
    __block BOOL hasError = NO;
    __weak typeof(self) weakSelf = self;

    void (^afterEach)(void) = ^{
        pending--;
        if (pending != 0) return;

        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;

        NSMutableSet<NSString *> *uidSet = [NSMutableSet set];
        if (!hasError) {
            // my_bots：全部并入
            for (id m in myBots) {
                if (![m isKindOfClass:[NSDictionary class]]) continue;
                id uid = ((NSDictionary *)m)[@"uid"];
                if ([uid isKindOfClass:[NSString class]] && [(NSString *)uid length] > 0) {
                    [uidSet addObject:uid];
                }
            }
            // space_bots：仅 status=added 并入（与 WKBotListVM 同源）
            for (id m in spaceBots) {
                if (![m isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *d = (NSDictionary *)m;
                id uid = d[@"uid"];
                id status = d[@"status"];
                if (![uid isKindOfClass:[NSString class]] || [(NSString *)uid length] == 0) continue;
                if (![status isKindOfClass:[NSString class]] || ![(NSString *)status isEqualToString:@"added"]) continue;
                [uidSet addObject:uid];
            }
        }

        NSArray *callbacks = nil;
        @synchronized (self_) {
            if (!hasError) {
                self_.spaceBotMap[spaceId] = [uidSet copy];
            }
            callbacks = [self_.pendingCompletions[spaceId] copy];
            [self_.pendingCompletions removeObjectForKey:spaceId];
        }

        NSLog(@"[BotSpaceTrace] WKSpaceBotRegistry loaded spaceId=%@ bots=%lu hasError=%d",
              spaceId, (unsigned long)uidSet.count, hasError);

        for (void (^cb)(BOOL) in callbacks) {
            cb(!hasError);
        }
        if (!hasError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:WKSpaceBotRegistryDidLoadNotification
                                  object:nil
                                userInfo:@{@"space_id": spaceId}];
            });
        }
    };

    [[WKAPIClient sharedClient] taskGET:@"robot/my_bots"
                             parameters:@{@"space_id": spaceId}
                               callback:^(NSError *error, id result) {
        if (error) hasError = YES;
        myBots = [result isKindOfClass:[NSArray class]] ? (NSArray *)result : @[];
        afterEach();
    }];
    [[WKAPIClient sharedClient] taskGET:@"robot/space_bots"
                             parameters:@{@"space_id": spaceId}
                               callback:^(NSError *error, id result) {
        if (error) hasError = YES;
        spaceBots = [result isKindOfClass:[NSArray class]] ? (NSArray *)result : @[];
        afterEach();
    }];
}

@end
