//
//  WKStickerLocalOrderStore.m
//  WuKongBase
//

#import "WKStickerLocalOrderStore.h"
#import "WKStickerPackage.h"

static NSString *const kStickerLocalOrderKeyPrefix = @"wk_sticker_local_order_";

@implementation WKStickerLocalOrderStore

+ (instancetype)shared {
    static WKStickerLocalOrderStore *inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [WKStickerLocalOrderStore new];
    });
    return inst;
}

- (NSString *)keyForUID:(NSString *)uid {
    return [kStickerLocalOrderKeyPrefix stringByAppendingString:uid];
}

- (void)saveOrder:(NSArray<NSString *> *)paths forUID:(NSString *)uid {
    if (uid.length == 0) return;
    NSArray<NSString *> *filtered = [paths ?: @[] filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *b) {
            return [obj isKindOfClass:NSString.class] && ((NSString *)obj).length > 0;
        }]];
    [[NSUserDefaults standardUserDefaults] setObject:filtered forKey:[self keyForUID:uid]];
}

- (NSArray<NSString *> *)loadOrderForUID:(NSString *)uid {
    if (uid.length == 0) return nil;
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:[self keyForUID:uid]];
    if (![val isKindOfClass:NSArray.class]) return nil;
    return (NSArray<NSString *> *)val;
}

- (void)clearForUID:(NSString *)uid {
    if (uid.length == 0) return;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self keyForUID:uid]];
}

- (NSArray<WKSticker *> *)mergeServerList:(NSArray<WKSticker *> *)serverList
                                   forUID:(NSString *)uid {
    NSArray<WKSticker *> *server = serverList ?: @[];
    NSArray<NSString *> *localOrder = [self loadOrderForUID:uid];
    if (uid.length == 0 || localOrder.count == 0) {
        return server;
    }

    // path → WKSticker 反查
    NSMutableDictionary<NSString *, WKSticker *> *byPath =
        [NSMutableDictionary dictionaryWithCapacity:server.count];
    for (WKSticker *s in server) {
        if (s.path.length > 0) byPath[s.path] = s;
    }

    NSMutableArray<WKSticker *> *result = [NSMutableArray arrayWithCapacity:server.count];
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:server.count];
    NSMutableArray<NSString *> *cleanedOrder = [NSMutableArray arrayWithCapacity:localOrder.count];

    NSSet<NSString *> *localSet = [NSSet setWithArray:localOrder];

    // 1. 服务端 list 里、本地 order 不含的 path（新增 / collect 进来的）优先插到**最前面**，
    //    保持用户「刚加进来的立即看到」的期望。按 server 原序 push（若一次多个新增）。
    for (WKSticker *s in server) {
        if (s.path.length > 0 && ![localSet containsObject:s.path] && ![seen containsObject:s.path]) {
            [result addObject:s];
            [seen addObject:s.path];
        }
    }
    // 2. 按本地 order 追加（跳过已被服务端删除的）
    for (NSString *p in localOrder) {
        WKSticker *s = byPath[p];
        if (s && ![seen containsObject:p]) {
            [result addObject:s];
            [seen addObject:p];
            [cleanedOrder addObject:p];
        }
    }
    // 3. 如果 order 里有本次已消失的 path，写回精简后的 order（幂等清理）
    if (cleanedOrder.count != localOrder.count) {
        [self saveOrder:cleanedOrder forUID:uid];
    }
    return result;
}

@end
