//  WKANRWatchdog.m — 主线程卡死 + UI冻结 检测（临时调试工具，上线前删除）

#import "WKANRWatchdog.h"
#import <UIKit/UIKit.h>
#include <pthread.h>
#include <mach/mach.h>
#include <dlfcn.h>

@interface WKANRWatchdog ()
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, assign) NSTimeInterval threshold;
@property (nonatomic, assign) BOOL mainThreadResponded;
@property (nonatomic, assign) BOOL waitingForResponse;
@property (nonatomic, assign) CFAbsoluteTime lastPingTime;
@property (nonatomic, assign) NSInteger tickCount;
@property (nonatomic, assign) CFAbsoluteTime stuckTransitionDetectedAt;
@end

@implementation WKANRWatchdog

+ (instancetype)shared {
    static WKANRWatchdog *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[self alloc] init]; });
    return inst;
}

- (void)startWithThreshold:(NSTimeInterval)threshold {
    [self stop];
    self.threshold = threshold;
    self.waitingForResponse = NO;
    self.tickCount = 0;

    dispatch_queue_t q = dispatch_queue_create("com.wk.anr-watchdog", DISPATCH_QUEUE_SERIAL);
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);
    dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, interval), interval, 0);

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timer, ^{
        [weakSelf tick];
    });
    dispatch_resume(self.timer);
    NSLog(@"[ANR-Watchdog] started, threshold=%.1fs", threshold);
}

- (void)stop {
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
}

- (void)tick {
    self.tickCount++;

    // ────── 检测1: 主线程GCD阻塞 ──────
    if (self.waitingForResponse) {
        CFAbsoluteTime elapsed = CFAbsoluteTimeGetCurrent() - self.lastPingTime;
        if (elapsed > self.threshold && !self.mainThreadResponded) {
            [self reportMainThreadBlock:elapsed];
            self.waitingForResponse = NO;
        }
        if (self.mainThreadResponded) {
            self.waitingForResponse = NO;
        }
    }
    if (!self.waitingForResponse) {
        self.mainThreadResponded = NO;
        self.waitingForResponse = YES;
        self.lastPingTime = CFAbsoluteTimeGetCurrent();
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mainThreadResponded = YES;
        });
    }

    // ────── 检测2: UI级冻结（每3秒检查一次） ──────
    if (self.tickCount % 3 == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self checkUIState];
        });
    }
}

#pragma mark - UI 状态检测

- (void)checkUIState {
    UINavigationController *nav = [self topNavigationController];
    if (!nav) return;

    // 检查交互式转场是否卡住
    UIGestureRecognizer *popGesture = nav.interactivePopGestureRecognizer;
    if (popGesture) {
        UIGestureRecognizerState state = popGesture.state;
        if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
            NSLog(@"⚠️ [ANR-Watchdog] interactivePopGesture 状态异常: %ld (应该已结束)", (long)state);
        }

        // 检查 popGesture 的 targets 数量（通过 KVC）
        @try {
            NSArray *targets = [popGesture valueForKey:@"targets"];
            if (targets.count > 2) {
                NSLog(@"⚠️ [ANR-Watchdog] interactivePopGesture targets 数量异常: %lu (可能有泄漏)", (unsigned long)targets.count);
                for (id target in targets) {
                    NSLog(@"⚠️ [ANR-Watchdog]   target: %@", target);
                }
            }
        } @catch (NSException *e) {}
    }

    // 检查是否有卡住的 transitionCoordinator
    UIViewController *rootForTransition = nav;
    // 也检查 nav 的 parent（如 TabBarController）
    if (nav.tabBarController) {
        id<UIViewControllerTransitionCoordinator> tabCoord = nav.tabBarController.transitionCoordinator;
        if (tabCoord) {
            rootForTransition = nav.tabBarController;
        }
    }
    id<UIViewControllerTransitionCoordinator> coord = rootForTransition.transitionCoordinator;
    if (coord) {
        NSLog(@"⚠️ [ANR-Watchdog] %@(%@) 有活跃的 transitionCoordinator, isInteractive=%d, isAnimated=%d",
              NSStringFromClass([rootForTransition class]),
              NSStringFromClass([nav.topViewController class]),
              coord.isInteractive, coord.isAnimated);

        if (self.stuckTransitionDetectedAt == 0) {
            self.stuckTransitionDetectedAt = CFAbsoluteTimeGetCurrent();
        } else {
            CFAbsoluteTime stuckDuration = CFAbsoluteTimeGetCurrent() - self.stuckTransitionDetectedAt;
            if (stuckDuration > 5.0) {
                NSLog(@"🔴🔴🔴 [ANR-Watchdog] 转场卡住 %.1f 秒！尝试强制恢复...", stuckDuration);
                [self forceRecoverStuckTransition:nav];
                self.stuckTransitionDetectedAt = 0;
            }
        }
    } else {
        self.stuckTransitionDetectedAt = 0;
    }

    // 检查是否有 modal 挡住交互
    UIViewController *presented = nav.presentedViewController;
    if (presented) {
        NSLog(@"ℹ️ [ANR-Watchdog] 有 presentedViewController: %@ (modalStyle=%ld)",
              NSStringFromClass([presented class]), (long)presented.modalPresentationStyle);
    }

    // 检查 key window 的 hitTest 是否正常
    UIWindow *keyWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
        }
    }
    if (keyWindow) {
        // 检查是否有高层级的 window 挡住
        UIWindowScene *scene = keyWindow.windowScene;
        for (UIWindow *w in scene.windows) {
            if (w != keyWindow && w.windowLevel > keyWindow.windowLevel && !w.hidden && w.alpha > 0.01) {
                NSString *cls = NSStringFromClass([w class]);
                // 排除已知的调试工具窗口
                if ([cls containsString:@"Doraemon"] || [cls containsString:@"FPS"]) continue;
                NSLog(@"⚠️ [ANR-Watchdog] 发现高层 window: level=%.0f class=%@ frame=%@ userInteraction=%d",
                      w.windowLevel, cls,
                      NSStringFromCGRect(w.frame), w.userInteractionEnabled);
            }
        }
    }
}

- (UINavigationController *)topNavigationController {
    UIWindow *keyWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
        }
    }
    if (!keyWindow) return nil;
    UIViewController *root = keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    if ([root isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)root;
    }
    if ([root isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = ((UITabBarController *)root).selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) {
            return (UINavigationController *)selected;
        }
    }
    return root.navigationController;
}

#pragma mark - 卡住转场恢复

- (void)forceRecoverStuckTransition:(UINavigationController *)nav {
    // 如果有卡住的 modal，强制 dismiss
    UIViewController *presented = nav.presentedViewController;
    if (!presented && nav.tabBarController) {
        presented = nav.tabBarController.presentedViewController;
    }
    if (presented) {
        NSLog(@"🔴 [ANR-Watchdog] 强制 dismiss presentedVC: %@", NSStringFromClass([presented class]));
        [presented dismissViewControllerAnimated:NO completion:nil];
        return;
    }

    // 没有 modal 但 transition 卡住：
    // popToRoot 对卡死的转场也无效（因为导航控制器拒绝处理新的 pop）
    // 最后手段：直接设置 viewControllers 数组来绕过转场状态机
    NSLog(@"🔴 [ANR-Watchdog] 无 modal，使用 setViewControllers 强制重置导航栈");
    NSArray *rootOnly = @[nav.viewControllers.firstObject ?: [[UIViewController alloc] init]];
    [nav setViewControllers:rootOnly animated:NO];
}

#pragma mark - 主线程阻塞报告

- (void)reportMainThreadBlock:(CFAbsoluteTime)elapsed {
    NSLog(@"🔴🔴🔴 [ANR-Watchdog] 主线程GCD阻塞 %.1f 秒！", elapsed);

    NSArray<NSString *> *symbols = [self mainThreadCallStack];
    NSLog(@"🔴 [ANR-Watchdog] 主线程调用栈 (%lu 帧):", (unsigned long)symbols.count);
    for (NSInteger i = 0; i < symbols.count && i < 30; i++) {
        NSLog(@"🔴   %@", symbols[i]);
    }

    CFStringRef mode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain());
    NSLog(@"🔴 [ANR-Watchdog] RunLoop mode: %@", (__bridge NSString *)mode);
    if (mode) CFRelease(mode);
}

#pragma mark - 主线程调用栈 (Mach API)

- (NSArray<NSString *> *)mainThreadCallStack {
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount;
    kern_return_t kr = task_threads(mach_task_self(), &threads, &threadCount);
    if (kr != KERN_SUCCESS) return @[@"(无法获取线程列表)"];

    thread_t mainThread = threads[0];
    NSMutableArray<NSString *> *result = [NSMutableArray array];

#if defined(__arm64__)
    _STRUCT_MCONTEXT machineContext;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    kr = thread_get_state(mainThread, ARM_THREAD_STATE64, (thread_state_t)&machineContext.__ss, &stateCount);
    if (kr == KERN_SUCCESS) {
        uintptr_t pc = (uintptr_t)machineContext.__ss.__pc;
        uintptr_t lr = (uintptr_t)machineContext.__ss.__lr;
        uintptr_t fp = (uintptr_t)machineContext.__ss.__fp;
        Dl_info info;
        if (dladdr((void *)pc, &info)) {
            [result addObject:[NSString stringWithFormat:@"PC: %s + %ld (%s)",
                               info.dli_sname ?: "???", (long)(pc - (uintptr_t)info.dli_saddr),
                               info.dli_fname ? strrchr(info.dli_fname, '/') + 1 : "???"]];
        }
        if (dladdr((void *)lr, &info)) {
            [result addObject:[NSString stringWithFormat:@"LR: %s + %ld (%s)",
                               info.dli_sname ?: "???", (long)(lr - (uintptr_t)info.dli_saddr),
                               info.dli_fname ? strrchr(info.dli_fname, '/') + 1 : "???"]];
        }
        for (int i = 0; i < 28 && fp != 0; i++) {
            uintptr_t *framePtr = (uintptr_t *)fp;
            uintptr_t nextFP = framePtr[0];
            uintptr_t retAddr = framePtr[1];
            if (retAddr == 0) break;
            if (dladdr((void *)retAddr, &info)) {
                [result addObject:[NSString stringWithFormat:@"#%d: %s + %ld (%s)",
                                   i, info.dli_sname ?: "???", (long)(retAddr - (uintptr_t)info.dli_saddr),
                                   info.dli_fname ? strrchr(info.dli_fname, '/') + 1 : "???"]];
            } else {
                [result addObject:[NSString stringWithFormat:@"#%d: 0x%lx", i, (unsigned long)retAddr]];
            }
            fp = nextFP;
        }
    }
#elif defined(__x86_64__)
    _STRUCT_MCONTEXT machineContext;
    mach_msg_type_number_t stateCount = x86_THREAD_STATE64_COUNT;
    kr = thread_get_state(mainThread, x86_THREAD_STATE64, (thread_state_t)&machineContext.__ss, &stateCount);
    if (kr == KERN_SUCCESS) {
        uintptr_t pc = (uintptr_t)machineContext.__ss.__rip;
        uintptr_t bp = (uintptr_t)machineContext.__ss.__rbp;
        Dl_info info;
        if (dladdr((void *)pc, &info)) {
            [result addObject:[NSString stringWithFormat:@"RIP: %s + %ld (%s)",
                               info.dli_sname ?: "???", (long)(pc - (uintptr_t)info.dli_saddr),
                               info.dli_fname ? strrchr(info.dli_fname, '/') + 1 : "???"]];
        }
        for (int i = 0; i < 28 && bp != 0; i++) {
            uintptr_t *framePtr = (uintptr_t *)bp;
            uintptr_t nextBP = framePtr[0];
            uintptr_t retAddr = framePtr[1];
            if (retAddr == 0) break;
            if (dladdr((void *)retAddr, &info)) {
                [result addObject:[NSString stringWithFormat:@"#%d: %s + %ld (%s)",
                                   i, info.dli_sname ?: "???", (long)(retAddr - (uintptr_t)info.dli_saddr),
                                   info.dli_fname ? strrchr(info.dli_fname, '/') + 1 : "???"]];
            }
            bp = nextBP;
        }
    }
#endif

    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        mach_port_deallocate(mach_task_self(), threads[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads, threadCount * sizeof(thread_t));
    return result.count > 0 ? result : @[@"(调用栈为空)"];
}

@end
