//
//  OctoSummaryNotifyStore.m
//  OctoContext
//

#import "OctoSummaryNotifyStore.h"

/// SENT 表: [ {@"id": NSNumber(taskId), @"version": NSNumber(version), @"channels": NSArray<NSString*>} ]。
/// 用有序数组而不是字典, 是为了能按"命中即续命排到队尾"的顺序做淘汰——严格来说是
/// LRU 不是 FIFO (见 _markSentTaskId:version:channelId: 命中已存在的条目会挪到队尾),
/// 字典无序做不到这个, 溢出时也不知道该丢谁。
/// version 与安卓 SummaryNotifyStore 的 "taskId:version" 复合 key 对齐: 后端 regenerate
/// 是原地复用同一个 task_id 的 UPDATE, 不产生新 task_id, 只按 taskId 记账会让重新生成
/// 完成后的提示被上一轮的记录误判成"发过了"而跳过。改成 (taskId, version) 后, 新一轮
/// 完成天然带着新 version (result.version 由后端在 saveLatestResultAndCompleteTask 事务
/// 里单调递增, 且严格先于 status 改成 Completed 提交, 客户端读到 Completed 时 version
/// 必然是这一轮的权威值), 不需要在"点击重新生成"那一刻做任何清账动作。
static NSString *const kSentKey = @"OctoSummaryTipSentKey";
/// 历史扁平表: NSArray<NSString*>, 元素是 taskId 的十进制字符串。只读不写, 键名必须与
/// 那边的字面量保持一致, 改它等于把那批去重记录全部作废。
/// 语义局限: 没有 version/channel 维度, 只能回答"这个 taskId 有没有发过", 回答不了
/// "发过的是哪个版本"。早期实现 (以及据此打过的灰度包) 拿它当"taskId 命中就永远算
/// 已发过"用——这对装过那批灰度包的设备是过度拦截: 只要 taskId 命中过, 之后任何一次
/// regenerate 产出的新版本都会被这条无条件短路挡掉, 版本号判断完全轮不到, 提示永久
/// 发不出去。
/// 现在的用法改成"吸收一次就退场": 见 +claimTaskId:version:channelId: —— 只在这个
/// taskId 在新版 kSentKey 里还完全没有任何记录 (即这台设备第一次在新代码下判定这个
/// taskId) 时, 才把这次请求携带的 (taskId, version, channelId) 直接当"已发过"落进
/// kSentKey (不真的发送), 且仅此一次。落账之后这个 taskId 就彻底转交新表, 之后所有
/// regenerate 产出的新版本都走正常的版本号判断, 不再受这条历史表影响。
/// 这个策略默认"legacy 记录时真实发送过的 channel 集合" ≈ "这次重新判定时解析出的目标
/// channel 集合"——legacy 本身没记录 channel, 没法精确还原, 只能按当下能拿到的最新
/// 信息吸收, 边界情况下可能因两者不完全一致而漏发, 但不会造成重复发 (与整份文件
/// "宁可漏发不重发"的取舍一致)。
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

/// 纯读谓词, 只查新表——legacy 判断挪到 +claimTaskId:version:channelId: 里做 (那边
/// 命中 legacy 时除了要"读", 还要顺带"写"一次吸收记录, 放在这个方法里语义会变得
/// 名不副实)。
+ (BOOL)_hasSentTaskId:(int64_t)taskId version:(NSInteger)version channelId:(NSString *)channelId {
    for (NSDictionary *entry in [self entriesForKey:kSentKey]) {
        if ([entry[@"id"] longLongValue] != taskId) continue;
        if ([entry[@"version"] integerValue] != version) continue;
        NSArray *channels = entry[@"channels"];
        return [channels isKindOfClass:NSArray.class] && [channels containsObject:channelId];
    }
    return NO;
}

/// 这个 taskId 在新表里是否已经有任意一条记录 (不看 version)——用来判定"这台设备是不是
/// 第一次在新代码下遇到这个 (legacy 命中的) taskId"。命中过一次之后, 不管后续是不是
/// 同一个 version, 都不再是"第一次", legacy 吸收分支只会触发这一次。
+ (BOOL)_hasAnySentEntryForTaskId:(int64_t)taskId {
    for (NSDictionary *entry in [self entriesForKey:kSentKey]) {
        if ([entry[@"id"] longLongValue] == taskId) return YES;
    }
    return NO;
}

+ (void)_markSentTaskId:(int64_t)taskId version:(NSInteger)version channelId:(NSString *)channelId {
    NSMutableArray<NSDictionary *> *entries = [[self entriesForKey:kSentKey] mutableCopy];
    NSUInteger found = NSNotFound;
    for (NSUInteger i = 0; i < entries.count; i++) {
        if ([entries[i][@"id"] longLongValue] != taskId) continue;
        if ([entries[i][@"version"] integerValue] != version) continue;
        found = i; break;
    }
    NSMutableArray<NSString *> *channels = [NSMutableArray array];
    if (found != NSNotFound) {
        NSArray *old = entries[found][@"channels"];
        if ([old isKindOfClass:NSArray.class]) [channels addObjectsFromArray:old];
        if ([channels containsObject:channelId]) return;
        [entries removeObjectAtIndex:found];
    }
    [channels addObject:channelId];
    // 命中的 (task, version) 重新追加到队尾: 最近活跃的不会被 FIFO 截断掉。
    [entries addObject:@{@"id": @(taskId), @"version": @(version), @"channels": channels}];
    while (entries.count > kMaxSentTasks) [entries removeObjectAtIndex:0];
    [[NSUserDefaults standardUserDefaults] setObject:entries forKey:kSentKey];
}

+ (BOOL)claimTaskId:(int64_t)taskId version:(NSInteger)version channelId:(NSString *)channelId {
    if (taskId <= 0 || channelId.length == 0) return NO;
    @synchronized ([self lockToken]) {
        if ([self _hasSentTaskId:taskId version:version channelId:channelId]) return NO;
        // legacy 吸收: 命中旧扁平表、且新表里这个 taskId 还一条记录都没有 (第一次在新
        // 代码下遇到它), 就把这次解析出的 (taskId, version, channelId) 直接落账成
        // "已发过", 不实际发送——对应 legacy 表记录的那一次已经真实发过了。落账之后
        // 这个 taskId 立刻转交新表, 后续 regenerate 产出的新 version 不会再被这条
        // 短路挡住 (kLegacySentKey 处注释有完整说明)。
        if ([self legacyHasSentTaskId:taskId] && ![self _hasAnySentEntryForTaskId:taskId]) {
            [self _markSentTaskId:taskId version:version channelId:channelId];
            return NO;
        }
        [self _markSentTaskId:taskId version:version channelId:channelId];
        return YES;
    }
}

+ (void)unmarkSentTaskId:(int64_t)taskId version:(NSInteger)version channelId:(NSString *)channelId {
    if (taskId <= 0 || channelId.length == 0) return;
    @synchronized ([self lockToken]) {
        NSMutableArray<NSDictionary *> *entries = [[self entriesForKey:kSentKey] mutableCopy];
        for (NSUInteger i = 0; i < entries.count; i++) {
            if ([entries[i][@"id"] longLongValue] != taskId) continue;
            if ([entries[i][@"version"] integerValue] != version) continue;
            NSArray *old = entries[i][@"channels"];
            // 脏数据只跳过这一条, 不打断整个遍历——entries 里 (id, version) 理应唯一
            // (markSentTaskId 写入前会先删掉旧 entry 再追加), 但防御性地保留 continue
            // 而不是 return, 万一真出现重复条目也不会因为前一条格式不对就漏查后面
            // 本该匹配上的条目。
            if (![old isKindOfClass:NSArray.class]) continue;
            NSMutableArray *channels = [old mutableCopy];
            [channels removeObject:channelId];
            if (channels.count == 0) [entries removeObjectAtIndex:i];
            else entries[i] = @{@"id": @(taskId), @"version": @(version), @"channels": channels};
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
