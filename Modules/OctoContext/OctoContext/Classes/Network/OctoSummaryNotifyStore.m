//
//  OctoSummaryNotifyStore.m
//  OctoContext
//

#import "OctoSummaryNotifyStore.h"

/// SENT 表: [ {@"id": NSNumber(taskId), @"channels": NSArray<NSString*>} ]。
/// 用有序数组而不是字典, 是为了能按写入顺序做 FIFO 截断 (字典无序, 溢出时不知道该丢谁)。
static NSString *const kSentKey = @"OctoSummaryTipSentKey";
/// 历史扁平表: NSArray<NSString*>, 元素是 taskId 的十进制字符串。只读不写。
/// 另一条在评审中的分支 (以及据此打过的灰度包) 用的是这个按 taskId 整体去重、没有
/// channel 维度的键。继续认它, 装过那种包的设备升级后就不会对同一条总结再发一遍。
/// 键名必须与那边的字面量保持一致, 改它等于把那批去重记录全部作废。
static NSString *const kLegacySentKey = @"OctoSummaryNotifiedTaskIds";
/// ELIGIBLE 表: [ {@"id": NSNumber(taskId), @"ts": NSNumber(unix 秒)} ]。
static NSString *const kEligibleKey = @"OctoSummaryTipEligibleKey";

/// SENT 表最多保留多少个 task。溢出丢最早的 —— 被丢掉的 task 若之后又被点开且仍有
/// eligible 标记才可能重发, 而 eligible 只有 10 分钟, 实际不可能同时成立。
static const NSUInteger kMaxSentTasks = 500;
/// ELIGIBLE 表上限与 TTL, 与安卓 / web 对齐。
static const NSUInteger kMaxEligibleTasks = 100;
static const NSTimeInterval kEligibleTTL = 10 * 60;

@implementation OctoSummaryNotifyStore

/// 所有读-改-写都串在这个锁上。详情页轮询回调、卡片点击后的详情回调都在主线程,
/// 但两条链路的 setObject 之间没有别的同步保证, 加锁比依赖"都在主线程"更稳。
+ (id)lockToken {
    static id token;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ token = [NSObject new]; });
    return token;
}

+ (NSArray<NSDictionary *> *)entriesForKey:(NSString *)key {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
    if (![raw isKindOfClass:NSArray.class]) return @[];
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    for (id item in raw) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        if (![((NSDictionary *)item)[@"id"] isKindOfClass:NSNumber.class]) continue;
        [out addObject:item];
    }
    return out;
}

#pragma mark - SENT

+ (BOOL)legacyHasSentTaskId:(int64_t)taskId {
    NSArray *ids = [[NSUserDefaults standardUserDefaults] arrayForKey:kLegacySentKey];
    if (![ids isKindOfClass:NSArray.class]) return NO;
    return [ids containsObject:[NSString stringWithFormat:@"%lld", taskId]];
}

+ (BOOL)_hasSentTaskId:(int64_t)taskId channelId:(NSString *)channelId {
    if ([self legacyHasSentTaskId:taskId]) return YES;
    for (NSDictionary *entry in [self entriesForKey:kSentKey]) {
        if ([entry[@"id"] longLongValue] != taskId) continue;
        NSArray *channels = entry[@"channels"];
        return [channels isKindOfClass:NSArray.class] && [channels containsObject:channelId];
    }
    return NO;
}

+ (void)_markSentTaskId:(int64_t)taskId channelId:(NSString *)channelId {
    NSMutableArray<NSDictionary *> *entries = [[self entriesForKey:kSentKey] mutableCopy];
    NSUInteger found = NSNotFound;
    for (NSUInteger i = 0; i < entries.count; i++) {
        if ([entries[i][@"id"] longLongValue] == taskId) { found = i; break; }
    }
    NSMutableArray<NSString *> *channels = [NSMutableArray array];
    if (found != NSNotFound) {
        NSArray *old = entries[found][@"channels"];
        if ([old isKindOfClass:NSArray.class]) [channels addObjectsFromArray:old];
        if ([channels containsObject:channelId]) return;
        [entries removeObjectAtIndex:found];
    }
    [channels addObject:channelId];
    // 命中的 task 重新追加到队尾: 最近活跃的不会被 FIFO 截断掉。
    [entries addObject:@{@"id": @(taskId), @"channels": channels}];
    while (entries.count > kMaxSentTasks) [entries removeObjectAtIndex:0];
    [[NSUserDefaults standardUserDefaults] setObject:entries forKey:kSentKey];
}

+ (BOOL)claimTaskId:(int64_t)taskId channelId:(NSString *)channelId {
    if (taskId <= 0 || channelId.length == 0) return NO;
    @synchronized ([self lockToken]) {
        if ([self _hasSentTaskId:taskId channelId:channelId]) return NO;
        [self _markSentTaskId:taskId channelId:channelId];
        return YES;
    }
}

+ (void)unmarkSentTaskId:(int64_t)taskId channelId:(NSString *)channelId {
    if (taskId <= 0 || channelId.length == 0) return;
    @synchronized ([self lockToken]) {
        NSMutableArray<NSDictionary *> *entries = [[self entriesForKey:kSentKey] mutableCopy];
        for (NSUInteger i = 0; i < entries.count; i++) {
            if ([entries[i][@"id"] longLongValue] != taskId) continue;
            NSArray *old = entries[i][@"channels"];
            // 脏数据只跳过这一条, 不打断整个遍历——entries 里 id 理应唯一 (markSentTaskId
            // 写入前会先删掉旧 entry 再追加), 但防御性地保留 continue 而不是 return, 万一
            // 真出现重复 id 也不会因为前一条格式不对就漏查后面本该匹配上的条目。
            if (![old isKindOfClass:NSArray.class]) continue;
            NSMutableArray *channels = [old mutableCopy];
            [channels removeObject:channelId];
            if (channels.count == 0) [entries removeObjectAtIndex:i];
            else entries[i] = @{@"id": @(taskId), @"channels": channels};
            [[NSUserDefaults standardUserDefaults] setObject:entries forKey:kSentKey];
            return;
        }
    }
}

#pragma mark - ELIGIBLE

/// 读表顺带清过期项。返回值已过滤过期, 调用方拿到的都是有效标记。
+ (NSMutableArray<NSDictionary *> *)liveEligibleEntries {
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    NSMutableArray<NSDictionary *> *live = [NSMutableArray array];
    for (NSDictionary *entry in [self entriesForKey:kEligibleKey]) {
        NSNumber *ts = entry[@"ts"];
        if (![ts isKindOfClass:NSNumber.class]) continue;
        NSTimeInterval age = now - ts.doubleValue;
        // age < 0 是设备时钟被往前调过, 一并丢掉 —— 这种标记的 TTL 无法判定。
        if (age < 0 || age > kEligibleTTL) continue;
        [live addObject:entry];
    }
    return live;
}

+ (void)markEligibleTaskId:(int64_t)taskId {
    if (taskId <= 0) return;
    @synchronized ([self lockToken]) {
        NSMutableArray<NSDictionary *> *entries = [self liveEligibleEntries];
        for (NSInteger i = (NSInteger)entries.count - 1; i >= 0; i--) {
            if ([entries[i][@"id"] longLongValue] == taskId) [entries removeObjectAtIndex:i];
        }
        [entries addObject:@{@"id": @(taskId), @"ts": @([NSDate date].timeIntervalSince1970)}];
        while (entries.count > kMaxEligibleTasks) [entries removeObjectAtIndex:0];
        [[NSUserDefaults standardUserDefaults] setObject:entries forKey:kEligibleKey];
    }
}

+ (BOOL)isEligibleTaskId:(int64_t)taskId {
    if (taskId <= 0) return NO;
    @synchronized ([self lockToken]) {
        for (NSDictionary *entry in [self liveEligibleEntries]) {
            if ([entry[@"id"] longLongValue] == taskId) return YES;
        }
        return NO;
    }
}

+ (BOOL)hasAnyEligibleTask {
    @synchronized ([self lockToken]) {
        return [self liveEligibleEntries].count > 0;
    }
}

+ (BOOL)consumeEligibleTaskId:(int64_t)taskId {
    if (taskId <= 0) return NO;
    @synchronized ([self lockToken]) {
        NSMutableArray<NSDictionary *> *entries = [self liveEligibleEntries];
        BOOL hit = NO;
        for (NSInteger i = (NSInteger)entries.count - 1; i >= 0; i--) {
            if ([entries[i][@"id"] longLongValue] == taskId) {
                [entries removeObjectAtIndex:i];
                hit = YES;
            }
        }
        // 命中与否都要写回: 上面的 liveEligibleEntries 已经把过期项滤掉了。
        [[NSUserDefaults standardUserDefaults] setObject:entries forKey:kEligibleKey];
        return hit;
    }
}

@end
