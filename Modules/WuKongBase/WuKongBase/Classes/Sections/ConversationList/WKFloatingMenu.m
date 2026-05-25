//
//  WKFloatingMenu.m
//  WuKongBase
//

#import "WKFloatingMenu.h"
#import "WKApp.h"
#import "UIView+WK.h"
#import <objc/runtime.h>

static const NSInteger kOverlayTag = 77700;
static const NSInteger kMenuContainerTag = 77701;
static const NSInteger kMenuItemTagBase = 77710;
static const void *kMenuItemsKey = &kMenuItemsKey;

/// 浮层上的 dismiss-tap 用一个 static 共享 delegate，把 menuContainer 子树里的
/// touch 全部拒掉 —— 否则 UITapGestureRecognizer 的默认行为
/// （cancelsTouchesInView=YES + delaysTouchesEnded=YES）在某些时序下会把按钮的
/// TouchUpInside 改成 touchesCancelled，导致点关注/取消/重命名/删除菜单项时只关菜单
/// 不触发 action（PR review #2 critical）。
@interface WKFloatingMenuTapFilter : NSObject <UIGestureRecognizerDelegate>
@end
@implementation WKFloatingMenuTapFilter
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    // 只关心 overlay 上挂的 dismiss-tap：若 touch 落在 menuContainer 子树内，
    // 直接放行让按钮自己处理 TouchUpInside，gesture 完全不参与本次 touch
    UIView *menuContainer = [gestureRecognizer.view viewWithTag:kMenuContainerTag];
    if (menuContainer) {
        UIView *hit = touch.view;
        while (hit) {
            if (hit == menuContainer) return NO;
            hit = hit.superview;
        }
    }
    return YES;
}
@end

@implementation WKFloatingMenu

+ (WKFloatingMenuTapFilter *)sharedTapFilter {
    static WKFloatingMenuTapFilter *f;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ f = [WKFloatingMenuTapFilter new]; });
    return f;
}

+ (UIWindow *)hostWindow {
    // 优先取当前 foregroundActive 的 UIWindowScene（多窗口 / iPad 拆分屏下不会
    // 把菜单挂到不可见 / 错的 scene 上）。退回 UIApplication.keyWindow / windows
    // 兜底（单窗口或拿不到 scene 信息时与原行为一致）—— PR review #14 warning。
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            // iOS 15+ 直接拿 .keyWindow；否则在 windows 里找 isKeyWindow 的
            UIWindow *key = nil;
            if (@available(iOS 15.0, *)) {
                key = ws.keyWindow;
            }
            if (!key) {
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) { key = w; break; }
                }
            }
            if (!key) key = ws.windows.firstObject;
            if (key) return key;
        }
    }
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    return window;
}

+ (void)showItems:(NSArray<NSDictionary *> *)items atPoint:(CGPoint)point {
    if (items.count == 0) return;
    UIWindow *window = [self hostWindow];
    if (!window) return;

    // 切到新菜单前先同步关掉所有旧的 overlay。不再用动画 dismiss —— 那 150ms 内
    // viewWithTag:kOverlayTag 会查到旧 overlay（新 overlay 也已加进 window），
    // onItemTapped: / dismiss 通过 tag 反查就可能命中旧那一层 → action 错位或
    // dismiss 错层（PR review #11 warning）。这里直接 stop animations + remove,
    // 保证 window 里至多只有一个 kOverlayTag 视图。
    UIView *stale;
    while ((stale = [window viewWithTag:kOverlayTag])) {
        [stale.layer removeAllAnimations];
        [stale removeFromSuperview];
    }

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
    overlay.alpha = 0;
    overlay.tag = kOverlayTag;
    [window addSubview:overlay];

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    dismissTap.delegate = [self sharedTapFilter]; // 拦截 menuContainer 子树里的 touch，让按钮 TouchUpInside 正常派发
    [overlay addGestureRecognizer:dismissTap];

    CGFloat menuWidth = 160;
    CGFloat rowHeight = 44;
    CGFloat menuHeight = items.count * rowHeight;
    CGFloat cornerRadius = 12;

    UIView *menuContainer = [[UIView alloc] init];
    menuContainer.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    menuContainer.layer.cornerRadius = cornerRadius;
    menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    menuContainer.layer.shadowOpacity = 0.15;
    menuContainer.layer.shadowOffset = CGSizeMake(0, 4);
    menuContainer.layer.shadowRadius = 12;
    menuContainer.tag = kMenuContainerTag;

    // 优先放在锚点上方；上方剩余空间不够（< 60pt）就落到下方
    BOOL showAbove = (point.y - menuHeight - 12 > 60);
    CGFloat menuX = point.x - menuWidth / 2.0;
    if (menuX < 10) menuX = 10;
    if (menuX + menuWidth > window.lim_width - 10) menuX = window.lim_width - menuWidth - 10;
    CGFloat menuY = showAbove ? (point.y - menuHeight - 10) : (point.y + 10);
    menuContainer.frame = CGRectMake(menuX, menuY, menuWidth, menuHeight);

    for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
        NSDictionary *item = items[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(0, i * rowHeight, menuWidth, rowHeight);
        btn.tag = kMenuItemTagBase + i;
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        btn.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);

        [btn setTitle:item[@"title"] forState:UIControlStateNormal];
        UIImage *icon = item[@"icon"];
        if (icon) {
            [btn setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        }
        BOOL isDestructive = [item[@"isDestructive"] boolValue];
        btn.tintColor = isDestructive ? [UIColor redColor] : [WKApp shared].config.defaultTextColor;
        [btn setTitleColor:btn.tintColor forState:UIControlStateNormal];
        btn.titleLabel.font = [[WKApp shared].config appFontOfSize:15.0f];
        [btn addTarget:self action:@selector(onItemTapped:) forControlEvents:UIControlEventTouchUpInside];
        [menuContainer addSubview:btn];

        if (i < (NSInteger)items.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(16, (i + 1) * rowHeight - 0.5, menuWidth - 32, 0.5)];
            sep.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
            [menuContainer addSubview:sep];
        }
    }

    objc_setAssociatedObject(overlay, kMenuItemsKey, items, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [overlay addSubview:menuContainer];

    menuContainer.transform = CGAffineTransformMakeScale(0.8, 0.8);
    menuContainer.alpha = 0;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        overlay.alpha = 1;
        menuContainer.transform = CGAffineTransformIdentity;
        menuContainer.alpha = 1;
    } completion:nil];
}

+ (void)onItemTapped:(UIButton *)btn {
    NSInteger index = btn.tag - kMenuItemTagBase;
    // 按钮在 menuContainer 里，menuContainer 在 overlay 里 —— 沿 superview 链
    // 反查到 overlay，避免依赖 viewWithTag: 在多层 overlay race 下命中错误层
    // （PR review #11 warning）。新 overlay 已强制把旧的同步移走，这里同样走
    // scoped 查找作为第二道保险。
    UIView *overlay = btn.superview;
    while (overlay && overlay.tag != kOverlayTag) overlay = overlay.superview;
    NSArray *items = overlay ? objc_getAssociatedObject(overlay, kMenuItemsKey) : nil;

    // 移除自身这一层 overlay；不走 window viewWithTag 全局 dismiss，避免误关其他
    [overlay.layer removeAllAnimations];
    [UIView animateWithDuration:0.15 animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];

    if (index >= 0 && index < (NSInteger)items.count) {
        void(^action)(void) = items[index][@"action"];
        if (action) action();
    }
}

+ (void)dismiss {
    UIWindow *window = [self hostWindow];
    UIView *overlay = [window viewWithTag:kOverlayTag];
    if (!overlay) return;
    [UIView animateWithDuration:0.15 animations:^{
        overlay.alpha = 0;
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

#pragma mark - Icons

+ (UIImage *)iconFollow {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGFloat cx = 10, cy = 10, r = 7;
    for (int i = 0; i < 5; i++) {
        CGFloat a = -M_PI/2 + i * 2*M_PI/5;
        CGFloat x = cx + r * cos(a);
        CGFloat y = cy + r * sin(a);
        if (i == 0) CGContextMoveToPoint(ctx, x, y);
        else CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextClosePath(ctx);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconUnfollow {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGFloat cx = 10, cy = 10, r = 6;
    for (int i = 0; i < 5; i++) {
        CGFloat a = -M_PI/2 + i * 2*M_PI/5;
        CGFloat x = cx + r * cos(a);
        CGFloat y = cy + r * sin(a);
        if (i == 0) CGContextMoveToPoint(ctx, x, y);
        else CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextClosePath(ctx);
    CGContextStrokePath(ctx);
    CGContextMoveToPoint(ctx, 3, 17);
    CGContextAddLineToPoint(ctx, 17, 3);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
