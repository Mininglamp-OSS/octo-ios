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

@implementation WKFloatingMenu

+ (UIWindow *)hostWindow {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    return window;
}

+ (void)showItems:(NSArray<NSDictionary *> *)items atPoint:(CGPoint)point {
    if (items.count == 0) return;
    UIWindow *window = [self hostWindow];
    if (!window) return;

    // 切到新菜单前先关掉旧的（避免叠层）
    [self dismiss];

    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
    overlay.alpha = 0;
    overlay.tag = kOverlayTag;
    [window addSubview:overlay];

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
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
    UIWindow *window = [self hostWindow];
    UIView *overlay = [window viewWithTag:kOverlayTag];
    NSArray *items = objc_getAssociatedObject(overlay, kMenuItemsKey);

    [self dismiss];

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
