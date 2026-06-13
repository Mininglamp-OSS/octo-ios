//
//  OctoActionToast.m
//  OctoContext
//

#import "OctoActionToast.h"

static const NSTimeInterval kOctoActionToastDuration = 3.5;
static const CGFloat kOctoActionToastBottomMargin    = 80;
static const CGFloat kOctoActionToastSideMargin      = 16;
static const CGFloat kOctoActionToastHeight          = 48;
static const CGFloat kOctoActionToastCornerRadius    = 24;
static const NSInteger kOctoActionToastTag           = 0x0C70A57;

@interface OctoActionToastView : UIView
@property(nonatomic, copy, nullable) void (^onAction)(void);
@property(nonatomic, strong) UIButton *actionBtn;
@property(nonatomic, assign) BOOL fired;
@end

@implementation OctoActionToastView

- (instancetype)init {
    if ((self = [super init])) {
        self.tag = kOctoActionToastTag;
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithWhite:1.0 alpha:0.96];
            }
            return [UIColor colorWithWhite:0.0 alpha:0.92];
        }];
        self.layer.cornerRadius = kOctoActionToastCornerRadius;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.18;
        self.layer.shadowRadius = 12;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        self.alpha = 0;
    }
    return self;
}

- (void)tapAction {
    if (self.fired) return;
    self.fired = YES;
    void (^block)(void) = self.onAction;
    [self dismissAnimated:YES];
    if (block) block();
}

- (void)dismissAnimated:(BOOL)animated {
    if (self.superview == nil) return;
    if (!animated) { [self removeFromSuperview]; return; }
    [UIView animateWithDuration:0.22
                     animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeTranslation(0, 16);
    }
                     completion:^(BOOL finished) { [self removeFromSuperview]; }];
}

@end

@implementation OctoActionToast

+ (void)showText:(NSString *)text
     actionTitle:(NSString *)actionTitle
        onAction:(void (^)(void))onAction {
    UIView *host = [self defaultHost];
    if (!host) return;
    [self showInView:host text:text actionTitle:actionTitle onAction:onAction];
}

+ (void)showInView:(UIView *)host
              text:(NSString *)text
       actionTitle:(NSString *)actionTitle
          onAction:(void (^)(void))onAction {
    if (!host || text.length == 0) return;

    // 同一 host 上若有上一次未消失的 toast, 先收掉, 避免堆叠遮挡。
    for (UIView *v in [host.subviews copy]) {
        if (v.tag == kOctoActionToastTag) [v removeFromSuperview];
    }

    OctoActionToastView *capsule = [OctoActionToastView new];
    capsule.onAction = onAction;
    [host addSubview:capsule];

    UIColor *textColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark ? UIColor.blackColor : UIColor.whiteColor;
    }];
    // action 字色: 浅色 capsule 黑底 → 浅紫亮一点; 深色 capsule 白底 → 深紫
    UIColor *actionColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
        }
        return [UIColor colorWithRed:0xB6/255.0 green:0x95/255.0 blue:0xFF/255.0 alpha:1.0];
    }];

    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:14];
    label.textColor = textColor;
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [capsule addSubview:label];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:actionTitle.length > 0 ? actionTitle : @"" forState:UIControlStateNormal];
    [btn setTitleColor:actionColor forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
    [btn addTarget:capsule action:@selector(tapAction) forControlEvents:UIControlEventTouchUpInside];
    [capsule addSubview:btn];
    capsule.actionBtn = btn;

    capsule.translatesAutoresizingMaskIntoConstraints = NO;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    btn.translatesAutoresizingMaskIntoConstraints = NO;

    UILayoutGuide *guide = host.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [capsule.leadingAnchor  constraintEqualToAnchor:guide.leadingAnchor  constant:kOctoActionToastSideMargin],
        [capsule.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-kOctoActionToastSideMargin],
        [capsule.bottomAnchor   constraintEqualToAnchor:guide.bottomAnchor   constant:-kOctoActionToastBottomMargin],
        [capsule.heightAnchor   constraintEqualToConstant:kOctoActionToastHeight],

        [label.leadingAnchor    constraintEqualToAnchor:capsule.leadingAnchor constant:18],
        [label.centerYAnchor    constraintEqualToAnchor:capsule.centerYAnchor],
        [label.trailingAnchor   constraintLessThanOrEqualToAnchor:btn.leadingAnchor constant:-8],

        [btn.trailingAnchor     constraintEqualToAnchor:capsule.trailingAnchor constant:-12],
        [btn.centerYAnchor      constraintEqualToAnchor:capsule.centerYAnchor],
        [btn.heightAnchor       constraintEqualToConstant:kOctoActionToastHeight - 8],
    ]];

    capsule.transform = CGAffineTransformMakeTranslation(0, 16);
    [UIView animateWithDuration:0.28
                          delay:0
         usingSpringWithDamping:0.92
          initialSpringVelocity:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        capsule.alpha = 1;
        capsule.transform = CGAffineTransformIdentity;
    }
                     completion:nil];

    __weak OctoActionToastView *weakCap = capsule;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(kOctoActionToastDuration * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        OctoActionToastView *cap = weakCap;
        if (cap && !cap.fired) [cap dismissAnimated:YES];
    });
}

+ (UIView *)defaultHost {
    UIWindow *win = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if (s.activationState != UISceneActivationStateForegroundActive) continue;
            if (![s isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)s).windows) {
                if (w.isKeyWindow) { win = w; break; }
            }
            if (!win) win = ((UIWindowScene *)s).windows.firstObject;
            if (win) break;
        }
    }
    if (!win) win = UIApplication.sharedApplication.keyWindow;
    return win;
}

@end
