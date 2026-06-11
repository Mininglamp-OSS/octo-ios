// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMainTabController.m
//  Octo
//
//  Created by tt on 2019/12/7.
//  Copyright 2026 MININGLAMP Technology and the OCTO contributors
//

#import "WKMainTabController.h"
#import <WuKongBase/WuKongBase.h>
#import <Lottie/Lottie.h>
#import "WKConversationListVC.h"
#import "WKContactsVC.h"
#import "WKMeVC.h"
@interface WKMainTabController ()<UITabBarControllerDelegate>

@property(nonatomic,strong) LOTAnimationView *currentLOTAnimationView;

// 浮岛: 白色容器 (light) / 深色容器 (dark) + 阴影。tabBar 自身置透明,实际"白底"由这个 view 渲染。
// 没合到 tabBar.layer 上是因为 capsule 圆角靠 cornerRadius + masksToBounds 实现,而 mask 会把
// 阴影也剪掉,所以阴影必须放到一个不 mask 的 sibling 上。
@property(nonatomic,strong) UIView *capsuleBackground;
// 选中态的灰色胶囊 pill, 滑动到当前选中 item 后面。在 capsuleBackground 之上、tabBar 之下。
@property(nonatomic,strong) UIView *pillIndicator;

@end

@implementation WKMainTabController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
    // 监听 viewConfigChange 通知（WKBaseVC 的 traitCollectionDidChange 会发这个）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStyleChange) name:@"WK_NOTIFY_STYLE_CHANGE" object:nil];
    // 切语言时 tabbar item title 不会自动刷新, 必须监听 WKNOTIFY_LANG_CHANGE 重新走 LLang
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLangChange) name:WKNOTIFY_LANG_CHANGE object:nil];

    [self setupChildVC:WKConversationListVC.class title:LLang(@"消息")
                 image:[UIImage imageNamed:@"消息"]
         selectedImage:[UIImage imageNamed:@"消息1"]];

    [self setupChildVC:WKContactsVC.class title:LLang(@"上下文")
                 image:[UIImage imageNamed:@"上下文"]
         selectedImage:[UIImage imageNamed:@"上下文1"]];

    [self setupChildVC:WKMeVC.class title:LLang(@"我的")
                 image:[UIImage imageNamed:@"我的"]
         selectedImage:[UIImage imageNamed:@"我的1"]];

    // 必须在 setupChildVC 之后，applySelectedTitleColor 要遍历 self.viewControllers
    [self updateTabBarAppearance];
}

- (void)onLangChange {
    // tab item 顺序 = setupChildVC 顺序: 消息 / 上下文 / 我的
    NSArray<NSString *> *titleKeys = @[@"消息", @"上下文", @"我的"];
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController *vc, NSUInteger idx, BOOL *stop) {
        if (idx < titleKeys.count) {
            vc.tabBarItem.title = LLang(titleKeys[idx]);
        }
    }];
}


- (void)setupChildVC:(Class)vc title:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage {
    UIViewController *vcInstall = [[vc alloc] init];
    // 用 AlwaysTemplate 而不是 AlwaysOriginal:
    //   PNG 是单色剪影 + alpha,Template 模式下系统会用 appearance.iconColor /
    //   tabBar.tintColor 重染。原来 AlwaysOriginal 把图标颜色锁死成设计稿写死的
    //   RGB(28,28,35) / RGB(187,187,189),深色模式下深图标贴深背景就隐身。
    //   走 Template 让色由 updateTabBarAppearance 里的 dynamic UIColor 决定。
    vcInstall.tabBarItem = [[UITabBarItem alloc] initWithTitle:title
                                                        image:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                                selectedImage:[selectedImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    [self addChildViewController:vcInstall];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self onStyleChange];
}

- (void)onStyleChange {
    [self updateTabBarAppearance];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateTabBarAppearance {
    // Liquid Glass 已在 Info.plist 用 UIDesignRequiresCompatibility=true 关掉
    // (iOS 26 Liquid Glass tabbar 在深色模式下漏光、tab 切换闪浅色 等 bug 太多,
    // 撤回到 iOS 18 兼容渲染)。统一走 iOS 13+ appearance API。
    //
    // 浮岛白底 + pill 选中胶囊由我们自己渲染 (见 _applyCapsuleStyleToTabBar):
    // - tabBar.standardAppearance = configureWithTransparentBackground —— 系统不再画
    //   blur/material, 让背后的 self.capsuleBackground (白色 + 阴影) 透出来。
    // - 选中胶囊用 self.pillIndicator (灰色圆角 view) 滑动定位, 不依赖系统 selectionIndicatorImage。
    //
    // 颜色全部走 dynamic UIColor,trait 变化时系统自动 resolve。
    // 浅色: selected = #1C1C23, normal = #BBBBBD (设计稿原色)
    // 深色: selected = 白, normal = 白 α 0.55
    UIColor *selectedTextColor;
    UIColor *normalTextColor;
    if (@available(iOS 13.0, *)) {
        selectedTextColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
                          || ([WKApp shared].config.style == WKSystemStyleDark);
            return isDark
                ? [UIColor whiteColor]
                : [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:35.0/255.0 alpha:1.0];
        }];
        normalTextColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
                          || ([WKApp shared].config.style == WKSystemStyleDark);
            return isDark
                ? [UIColor colorWithWhite:1.0 alpha:0.55]
                : [UIColor colorWithRed:187.0/255.0 green:187.0/255.0 blue:189.0/255.0 alpha:1.0];
        }];
    } else {
        selectedTextColor = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:35.0/255.0 alpha:1.0];
        normalTextColor   = [UIColor colorWithRed:187.0/255.0 green:187.0/255.0 blue:189.0/255.0 alpha:1.0];
    }
    NSDictionary *normalAttrs   = @{ NSForegroundColorAttributeName: normalTextColor,
                                     NSFontAttributeName: [UIFont systemFontOfSize:10] };
    NSDictionary *selectedAttrs = @{ NSForegroundColorAttributeName: selectedTextColor,
                                     NSFontAttributeName: [UIFont systemFontOfSize:10] };

    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        // transparent —— 系统不再画 blur/material, 背后的 self.capsuleBackground (白色 +
        // 阴影 + 圆角) 透出来作为浮岛底。
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = [UIColor clearColor];
        appearance.shadowColor = [UIColor clearColor];

        // titlePositionAdjustment.vertical < 0 把文字往上挪。系统在 stacked 布局下默认
        // 把 title 紧贴 bar 底,只留 ~3pt margin —— 即使 pill 内缩 8pt, title 底缘距 pill
        // 底缘也只有 ~3pt, 视觉上文字"压在"胶囊边框。-12pt 让 title 上抬 12pt, 在 pill 底
        // 留出 ~7pt 喘息。注意:offset 只影响 title, 不影响 icon, 所以把 bar 高度 (76) 保留
        // 给 icon 上方多出来的空白。
        UIOffset titleOffset = UIOffsetMake(0, -12);
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs;
        appearance.stackedLayoutAppearance.normal.iconColor = normalTextColor;
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = titleOffset;
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs;
        appearance.stackedLayoutAppearance.selected.iconColor = selectedTextColor;
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = titleOffset;
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttrs;
        appearance.inlineLayoutAppearance.normal.iconColor = normalTextColor;
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs;
        appearance.inlineLayoutAppearance.selected.iconColor = selectedTextColor;
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttrs;
        appearance.compactInlineLayoutAppearance.normal.iconColor = normalTextColor;
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs;
        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedTextColor;

        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
        self.tabBar.tintColor = selectedTextColor;
        self.tabBar.unselectedItemTintColor = normalTextColor;
    }
    self.tabBar.translucent = YES;
    [self applyTitleColorsNormal:normalAttrs selected:selectedAttrs];
}

- (void)applyTitleColorsNormal:(NSDictionary *)normalAttrs selected:(NSDictionary *)selectedAttrs {
    for (UIViewController *vc in self.viewControllers) {
        [vc.tabBarItem setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
        [vc.tabBarItem setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
    }
}

#pragma mark - 胶囊外观 (替代关掉的 Liquid Glass 浮岛)

// 浮岛尺寸常量 (统一一处,layout / safeArea 注入都用同一组数字)
static const CGFloat kWKCapsuleInsetX        = 16;   // 左右内缩
static const CGFloat kWKCapsuleHeight        = 76;   // 浮岛高度: icon(25) + 间距(4) + 标题(12) + 上下呼吸 ~ 76
static const CGFloat kWKCapsuleBottomGap     = 8;    // 浮岛距 safeArea 底缘的视觉间距
static const CGFloat kWKCapsuleShadowYOffset = 6;
static const CGFloat kWKCapsuleShadowRadius  = 14;
static const CGFloat kWKCapsuleShadowOpacity = 0.12;
// child VC 的 additionalSafeAreaInsets.bottom: 让 scrollView 底部内容不被浮岛遮。
// 系统给 child 的 safeArea.bottom 只算 tabBar.frame.size.height + windowSafeBottom,
// 漏掉浮岛距 safeArea 底缘的 bottomGap (8) 与视觉余量 (~16),最终多补 24pt。
// (注: WKConversationListVC 自己关掉了 contentInsetAdjustmentBehavior, 在那里另外
//  处理。)
static const CGFloat kWKContentBottomPadding = 24;
// pill 内缩 —— pill 比单个 item 区略小, 给 capsule 边缘留点呼吸
static const CGFloat kWKPillVerticalInset    = 8;    // 上下各 8pt: 圆形端帽外露 ~6pt
static const CGFloat kWKPillHorizontalInset  = 14;   // 左右各 14pt: 让 pill 视觉上"包住" icon+标题, 不顶到胶囊端帽

// Liquid Glass 关闭后,标准 UITabBar 是横贯全宽的扁平条。这里手工把它做成"浮岛胶囊":
// 白底 capsuleBackground + pill 选中胶囊 + tabBar 透明在最上层承接事件。
// viewDidLayoutSubviews 每次 layout 都重 apply,因为 UITabBarController 自己会按
// safeArea / orientation 反复重排 tabBar.frame。
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self _applyCapsuleStyleToTabBar];
}

- (UIColor *)_capsuleBackgroundColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
                      || ([WKApp shared].config.style == WKSystemStyleDark);
        // 浅色: 设计稿要求纯白 + 阴影。深色: 沿用 #1C1C23 暗底, 与设计深色态一致。
        return isDark
            ? [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:35.0/255.0 alpha:1.0]
            : [UIColor whiteColor];
    }];
}

- (UIColor *)_pillBackgroundColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
                      || ([WKApp shared].config.style == WKSystemStyleDark);
        // 浅色: 设计稿 #ECECEC 浅灰胶囊。深色: 白色 α 0.12, 弱化以不抢图标。
        return isDark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : [UIColor colorWithRed:0xEC/255.0 green:0xEC/255.0 blue:0xEC/255.0 alpha:1.0];
    }];
}

- (void)_setupCapsuleViewsIfNeeded {
    if (self.capsuleBackground) return;
    UIView *bg = [[UIView alloc] init];
    bg.userInteractionEnabled = NO;
    bg.backgroundColor = [self _capsuleBackgroundColor];
    // 阴影画在 layer, masksToBounds=NO (默认), cornerRadius 只剪 backgroundColor 区域,
    // 阴影沿 shadowPath 在外侧扩散。
    bg.layer.shadowColor   = [UIColor blackColor].CGColor;
    bg.layer.shadowOffset  = CGSizeMake(0, kWKCapsuleShadowYOffset);
    bg.layer.shadowRadius  = kWKCapsuleShadowRadius;
    bg.layer.shadowOpacity = kWKCapsuleShadowOpacity;
    [self.tabBar.superview insertSubview:bg belowSubview:self.tabBar];
    self.capsuleBackground = bg;

    UIView *pill = [[UIView alloc] init];
    pill.userInteractionEnabled = NO;
    pill.backgroundColor = [self _pillBackgroundColor];
    // pill 在 capsuleBackground 之上、tabBar 之下: tabBar 透明, 事件仍走 tabBar items。
    [self.tabBar.superview insertSubview:pill belowSubview:self.tabBar];
    self.pillIndicator = pill;
}

- (void)_applyCapsuleStyleToTabBar {
    UITabBar *bar = self.tabBar;
    if (!bar.superview || CGRectIsEmpty(self.view.bounds)) {
        return;
    }
    [self _setupCapsuleViewsIfNeeded];

    CGFloat bottomSafe = self.view.safeAreaInsets.bottom;
    CGFloat parentW    = self.view.bounds.size.width;
    CGFloat parentH    = self.view.bounds.size.height;

    CGRect target = CGRectMake(kWKCapsuleInsetX,
                               parentH - kWKCapsuleHeight - bottomSafe - kWKCapsuleBottomGap,
                               parentW - kWKCapsuleInsetX * 2,
                               kWKCapsuleHeight);
    if (!CGRectEqualToRect(bar.frame, target)) {
        bar.frame = target;
    }

    // tabBar 自身不再 mask / 不再画自己的圆角 —— 浮岛形状由 capsuleBackground 承担。
    // 不 mask 还有一个好处: badge 红点 (tabBarItem.badgeValue) 能溢出 item 框, 不会被
    // 裁掉一半。
    bar.layer.cornerRadius  = 0;
    bar.layer.masksToBounds = NO;
    bar.backgroundImage     = [UIImage new];
    bar.shadowImage         = [UIImage new];

    // capsuleBackground 与 tabBar 同 frame, 圆角 + shadowPath 让阴影沿胶囊形状外扩。
    self.capsuleBackground.frame = target;
    self.capsuleBackground.layer.cornerRadius = kWKCapsuleHeight / 2.0;
    self.capsuleBackground.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, target.size.width, target.size.height)
                                   cornerRadius:kWKCapsuleHeight / 2.0].CGPath;

    // pill 跟随当前 selectedIndex 定位 (无动画, layout 阶段)
    [self _layoutPillIndicatorAnimated:NO];

    // child 内容向上避让浮岛: 系统给的 safeArea.bottom 不足以盖住浮岛上沿 + 视觉余量。
    UIEdgeInsets desired = UIEdgeInsetsMake(0, 0, kWKContentBottomPadding, 0);
    for (UIViewController *vc in self.viewControllers) {
        if (!UIEdgeInsetsEqualToEdgeInsets(vc.additionalSafeAreaInsets, desired)) {
            vc.additionalSafeAreaInsets = desired;
        }
    }
}

- (CGRect)_pillFrameForIndex:(NSInteger)index {
    UITabBar *bar = self.tabBar;
    NSInteger count = MAX(1, (NSInteger)self.viewControllers.count);
    if (index < 0) index = 0;
    if (index >= count) index = count - 1;
    CGFloat itemW = bar.bounds.size.width / (CGFloat)count;
    // pill 坐标在 tabBar.superview 下 (capsuleBackground / pillIndicator 都是它的 sibling)
    CGFloat x = bar.frame.origin.x + (CGFloat)index * itemW + kWKPillHorizontalInset;
    CGFloat y = bar.frame.origin.y + kWKPillVerticalInset;
    CGFloat w = itemW - 2 * kWKPillHorizontalInset;
    CGFloat h = bar.bounds.size.height - 2 * kWKPillVerticalInset;
    return CGRectMake(x, y, w, h);
}

- (void)_layoutPillIndicatorAnimated:(BOOL)animated {
    if (!self.pillIndicator) return;
    if (CGRectIsEmpty(self.tabBar.bounds)) return;
    CGRect target = [self _pillFrameForIndex:self.selectedIndex];
    CGFloat radius = target.size.height / 2.0;
    if (!animated) {
        self.pillIndicator.frame = target;
        self.pillIndicator.layer.cornerRadius = radius;
        return;
    }
    // 切换 tab: spring 滑动。damping/velocity 取偏跟手不晃的取值。
    [UIView animateWithDuration:0.34
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                                | UIViewAnimationOptionBeginFromCurrentState
                                | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.pillIndicator.frame = target;
        self.pillIndicator.layer.cornerRadius = radius;
    } completion:nil];
}


#pragma mark - UITabBarControllerDelegate

static UIImpactFeedbackGenerator *impactFeedBack;
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    if(!impactFeedBack) {
        impactFeedBack = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    [impactFeedBack prepare];
    [impactFeedBack impactOccurred];
    [self _layoutPillIndicatorAnimated:YES];
}

@end

