// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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
 */
#import "WKConversationListTableView.h"
#import "WuKongBase.h"

static NSTimeInterval const kWatchdogTimeout = 2.0;
static NSInteger const kMaxRecoverRetries = 3; // 防止异常恢复死循环

@interface WKConversationListTableView ()

@property (nonatomic) BOOL needsReloadWhenPutOnScreen;
@property (nonatomic) BOOL isUpdating;
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
    self.pendingReload = NO;
    [super reloadData];
}

#pragma mark - 安全更新调度器

- (void)safePerformUpdate:(void(^)(void))updateBlock {
    if (self.window == nil) {
        self.needsReloadWhenPutOnScreen = YES;
        return;
    }

    // 已在更新中 → 不重入，标记待刷新
    if (self.isUpdating) {
        self.pendingReload = YES;
        return;
    }

    self.isUpdating = YES;
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
    self.watchdogTimer = [NSTimer scheduledTimerWithTimeInterval:kWatchdogTimeout repeats:NO block:^(NSTimer *timer) {
        NSLog(@"[WKConversationListTableView] ⚠️ Watchdog fired! Forcing reloadData");
        [ws forceReload];
    }];
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
    if (self.isUpdating) { self.pendingReload = YES; return; }

    self.isUpdating = YES;
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
    if (self.isUpdating) { self.pendingReload = YES; return; }
    self.isUpdating = YES;
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

- (void)reloadData {
    if (self.window == nil) {
        self.needsReloadWhenPutOnScreen = YES;
        return;
    }
    if (self.isUpdating) {
        self.pendingReload = YES;
        return;
    }
    self.recoverRetryCount = 0; // 主动 reloadData 重置计数
    [super reloadData];
}

@end
