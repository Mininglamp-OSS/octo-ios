//
//  WKConversationListTableView.m
//  WuKongBase
//
//  Created by tt on 2021/4/22.
//

/**
 安全更新调度器：
 - 所有行级操作走 safePerformUpdate，用 performBatchUpdates 包裹
 - isUpdating 防重入，冲突时自动降级为 reloadData
 - 异常恢复使用延迟 reloadData，带防循环保护
 - 看门狗兜底：更新超 2 秒未完成强制恢复
 - stale 保险：每个入口都先检查 isUpdating 时长，超过 kStaleThreshold 直接强制回收，
   防止 watchdog 因 runloop 模式 / 计时器被错杀等原因没触发，导致 reloadData 被
   永久吞掉、整张表停止刷新（用户侧表现为「切 tab 也不变、新消息无红点」）。
 */
#import "WKConversationListTableView.h"
#import "WuKongBase.h"

static NSTimeInterval const kWatchdogTimeout = 2.0;
static NSTimeInterval const kStaleThreshold  = 2.0; // isUpdating 卡住超过这个时长就强制回收
static NSInteger const kMaxRecoverRetries = 3; // 防止异常恢复死循环

@interface WKConversationListTableView ()

@property (nonatomic) BOOL needsReloadWhenPutOnScreen;
@property (nonatomic) BOOL isUpdating;
@property (nonatomic) NSTimeInterval isUpdatingSince; // isUpdating 被置 YES 的时间，用于 stale 检测
@property (nonatomic) BOOL pendingReload;
@property (nonatomic) NSInteger recoverRetryCount; // 异常恢复计数，防死循环
@property (nonatomic, strong) NSTimer *watchdogTimer;

@end

@implementation WKConversationListTableView

- (void)dealloc {
    [self stopWatchdog];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window != nil && self.needsReloadWhenPutOnScreen) {
        self.needsReloadWhenPutOnScreen = NO;
        [self forceReload];
    }
}

#pragma mark - 强制刷新（绕过所有保护，直接调 super）

/// 最终兜底：清除所有状态，直接调 super reloadData
- (void)forceReload {
    [self stopWatchdog];
    self.isUpdating = NO;
    self.isUpdatingSince = 0;
    self.pendingReload = NO;
    [super reloadData];
}

/// 检查 isUpdating 是否已 stale —— 超过 kStaleThreshold 还没复位，说明
/// 上一轮 batch 的 completion 没回调（watchdog 没起作用 / 异常路径漏 finishUpdate
/// / runloop 模式不对漏触发 timer），强制清掉，让后续操作能正常往下走。
/// 真发生 stale 时打 log，便于事后定位。
- (BOOL)recoverIfStale {
    if (!self.isUpdating) return NO;
    if (self.isUpdatingSince <= 0) return NO;
    NSTimeInterval elapsed = CFAbsoluteTimeGetCurrent() - self.isUpdatingSince;
    if (elapsed < kStaleThreshold) return NO;
    NSLog(@"[WKConversationListTableView] ⚠️ stale isUpdating detected (%.2fs), force recovering", elapsed);
    [self stopWatchdog];
    self.isUpdating = NO;
    self.isUpdatingSince = 0;
    self.pendingReload = NO;
    self.recoverRetryCount = 0;
    return YES;
}

#pragma mark - 安全更新调度器

- (void)safePerformUpdate:(void(^)(void))updateBlock {
    if (self.window == nil) {
        self.needsReloadWhenPutOnScreen = YES;
        return;
    }

    // 入口先做 stale 体检：上一轮 batch 卡死时这里能自愈
    [self recoverIfStale];

    // 已在更新中 → 不重入，标记待刷新
    if (self.isUpdating) {
        self.pendingReload = YES;
        return;
    }

    self.isUpdating = YES;
    self.isUpdatingSince = CFAbsoluteTimeGetCurrent();
    [self startWatchdog];

    @try {
        [super performBatchUpdates:^{
            if (updateBlock) updateBlock();
        } completion:^(BOOL finished) {
            [self finishUpdate];
        }];
    } @catch (NSException *exception) {
        NSLog(@"[WKConversationListTableView] safePerformUpdate exception: %@", exception);
        [self recoverFromException];
    }
}

- (void)finishUpdate {
    [self stopWatchdog];
    self.isUpdating = NO;
    self.isUpdatingSince = 0;
    self.recoverRetryCount = 0; // 正常完成，重置计数

    if (self.pendingReload) {
        self.pendingReload = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self forceReload];
        });
    }
}

- (void)recoverFromException {
    [self stopWatchdog];
    self.isUpdating = NO;
    self.isUpdatingSince = 0;
    self.pendingReload = NO;

    self.recoverRetryCount++;
    if (self.recoverRetryCount > kMaxRecoverRetries) {
        // 超过最大重试次数，停止恢复，等下次用户操作或定时器触发
        NSLog(@"[WKConversationListTableView] ⚠️ Exceeded max recover retries (%ld), stop retrying", (long)kMaxRecoverRetries);
        self.recoverRetryCount = 0;
        // 延迟较长时间后做一次最终恢复
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self forceReload];
        });
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self forceReload];
    });
}

#pragma mark - 看门狗

- (void)startWatchdog {
    [self stopWatchdog];
    __weak typeof(self) ws = self;
    // 用 CommonModes 注册，scroll/拖动期间也能触发，避免 runloop 切到 UITrackingMode
    // 后 watchdog 沉默、isUpdating 永远卡住的情况。
    NSTimer *t = [NSTimer timerWithTimeInterval:kWatchdogTimeout repeats:NO block:^(NSTimer *timer) {
        NSLog(@"[WKConversationListTableView] ⚠️ Watchdog fired! Forcing reloadData");
        [ws forceReload];
    }];
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    self.watchdogTimer = t;
}

- (void)stopWatchdog {
    [self.watchdogTimer invalidate];
    self.watchdogTimer = nil;
}

#pragma mark - 重写行级操作

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    [self safePerformUpdate:^{ [super insertRowsAtIndexPaths:indexPaths withRowAnimation:animation]; }];
}

- (void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath*>*)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    [self safePerformUpdate:^{ [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation]; }];
}

- (void)reloadRowsAtIndexPaths:(NSArray<NSIndexPath*>*)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    [self safePerformUpdate:^{ [super reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation]; }];
}

- (void)moveRowAtIndexPath:(NSIndexPath*)indexPath toIndexPath:(NSIndexPath*)newIndexPath {
    [self safePerformUpdate:^{ [super moveRowAtIndexPath:indexPath toIndexPath:newIndexPath]; }];
}

#pragma mark - 重写 Section 级操作

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    [self safePerformUpdate:^{ [super insertSections:sections withRowAnimation:animation]; }];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    [self safePerformUpdate:^{ [super deleteSections:sections withRowAnimation:animation]; }];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    [self safePerformUpdate:^{ [super reloadSections:sections withRowAnimation:animation]; }];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    [self safePerformUpdate:^{ [super moveSection:section toSection:newSection]; }];
}

#pragma mark - 重写批量更新

- (void)performBatchUpdates:(void (NS_NOESCAPE ^ _Nullable)(void))updates
                 completion:(void (^ _Nullable)(BOOL finished))completion {
    if (self.window == nil) { self.needsReloadWhenPutOnScreen = YES; return; }
    [self recoverIfStale];
    if (self.isUpdating) { self.pendingReload = YES; return; }

    self.isUpdating = YES;
    self.isUpdatingSince = CFAbsoluteTimeGetCurrent();
    [self startWatchdog];
    @try {
        [super performBatchUpdates:updates completion:^(BOOL finished) {
            [self finishUpdate];
            if (completion) completion(finished);
        }];
    } @catch (NSException *exception) {
        NSLog(@"[WKConversationListTableView] performBatchUpdates exception: %@", exception);
        [self recoverFromException];
        if (completion) completion(NO);
    }
}

- (void)beginUpdates {
    if (self.window == nil) { self.needsReloadWhenPutOnScreen = YES; return; }
    [self recoverIfStale];
    if (self.isUpdating) { self.pendingReload = YES; return; }
    self.isUpdating = YES;
    self.isUpdatingSince = CFAbsoluteTimeGetCurrent();
    [self startWatchdog];
    @try { [super beginUpdates]; }
    @catch (NSException *e) {
        NSLog(@"[WKConversationListTableView] beginUpdates exception: %@", e);
        [self recoverFromException];
    }
}

- (void)endUpdates {
    if (self.window == nil) { self.needsReloadWhenPutOnScreen = YES; return; }
    @try { [super endUpdates]; }
    @catch (NSException *e) {
        NSLog(@"[WKConversationListTableView] endUpdates exception: %@", e);
        [self recoverFromException];
        return;
    }
    [self finishUpdate];
}

#pragma mark - reloadData

/// reloadData 是「放弃所有 batch 中间态、整张表重建」的恢复路径，不能被 isUpdating
/// 闸门长期拒掉 —— 那样一旦 isUpdating 因任何原因卡住，整张表就再也刷不出来了
/// （之前用户反馈的「切 tab 也不变 / bot 消息没红点」就是这个症状）。
/// 策略：
///   - 不在 window 上：保留旧行为，标 needsReloadWhenPutOnScreen，等上屏再放
///   - 当前正在 batch 更新：先 stale 体检；仍在更新就把 reload 暂存为 pendingReload
///     **并 dispatch_async 一次延迟兜底 forceReload**——即便 finishUpdate 因任何原因
///     没回调（completion 被 UIKit 吃掉、watchdog 没起作用等），延迟兜底也能在下一轮
///     runloop 里再做一次自愈检查并落地 reload，整张表绝不会永久静止
///   - 其它情况：直接 super reloadData
- (void)reloadData {
    if (self.window == nil) {
        self.needsReloadWhenPutOnScreen = YES;
        return;
    }
    [self recoverIfStale];
    if (self.isUpdating) {
        self.pendingReload = YES;
        // 异步兜底：dispatch_async 在下一轮 runloop 跑，那时 batch 应已完成；若还没完成,
        // recoverIfStale 会在 forceReload 之前再清一次 isUpdating，确保 super reloadData
        // 至少能跑到。weak self 防止 dealloc 后还持有。
        __weak typeof(self) ws = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            if (!ss.pendingReload) return; // 期间已被 finishUpdate 处理过
            [ss recoverIfStale];
            if (!ss.isUpdating) {
                ss.pendingReload = NO;
                [ss forceReload];
            }
            // 仍在 update 中：让正常 finishUpdate 路径处理；下一次入口的 stale 检查会兜底
        });
        return;
    }
    self.recoverRetryCount = 0; // 主动 reloadData 重置计数
    [super reloadData];
}

@end
