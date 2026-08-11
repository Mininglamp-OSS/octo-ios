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
#import "OctoContextEntryVC.h"
#import "WKMeVC.h"
@interface WKMainTabController ()<UITabBarControllerDelegate>

@property(nonatomic,strong) LOTAnimationView *currentLOTAnimationView;

// 浮岛: 白色容器 (light) / 深色容器 (dark) + 阴影。tabBar 自身置透明,实际"白底"由这个 view 渲染。
// 没合到 tabBar.layer 上是因为 capsule 圆角靠 cornerRadius + masksToBounds 实现,而 mask 会把
// 阴影也剪掉,所以阴影必须放到一个不 mask 的 sibling 上。
@property(nonatomic,strong) UIView *capsuleBackground;
// 选中态的灰色胶囊 pill, 滑动到当前选中 item 后面。在 capsuleBackground 之上、tabBar 之下。
@property(nonatomic,strong) UIView *pillIndicator;

// 「消息」item icon 右上角的未读角标。系统 tabBarItem.badgeValue 不能定制配色,
// 而设计要求与会话列表 cell 同款（粉色背景 + 红色文字, WKUnreadBadge*Color),
// 所以自绘一个 WKBadgeView 浮在 icon 上。位置在 _layoutMessageTabBadge 里
// 按 tabBar 内 button view → image view 的实测 frame 计算,不写死 item 索引外的常量。
@property(nonatomic,strong) WKBadgeView *messageTabBadge;

// 「消息」item 双击判定用。见 _handlePossibleMessageTabDoubleTap:。
// lastSelectedViewController 记「本次点击之前停在哪个 tab」，用来区分
// 「切 tab」和「重复点当前 tab」；weak 是因为 tab 的子 VC 由 self.viewControllers 持有。
@property(nonatomic,weak,nullable) UIViewController *lastSelectedViewController;
@property(nonatomic,assign) NSTimeInterval lastMessageTabReselectAt; // CACurrentMediaTime 单位秒

@end

// 双击判定窗口。系统双击间隔约 0.25s，留一点余量；再长会把「点一下看一眼、
// 过一会儿再点一下」误判成双击。
static NSTimeInterval const kWKMessageTabDoubleTapInterval = 0.35;

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

    [self setupChildVC:OctoContextEntryVC.class title:LLang(@"上下文")
                 image:[UIImage imageNamed:@"上下文"]
         selectedImage:[UIImage imageNamed:@"上下文1"]];

    [self setupChildVC:WKMeVC.class title:LLang(@"我的")
                 image:[UIImage imageNamed:@"我的"]
         selectedImage:[UIImage imageNamed:@"我的1"]];

    // 必须在 setupChildVC 之后，applySelectedTitleColor 要遍历 self.viewControllers
    [self updateTabBarAppearance];

    // 启动就停在「消息」tab（selectedIndex 默认 0）。种下这个初值，第一次双击「消息」
    // 才能被正确判成「两下重选」；否则第一下会被当成切 tab 吃掉。
    self.lastSelectedViewController = self.viewControllers.firstObject;
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
    // 浅色: selected = #1C1C23, normal = rgb(140, 140, 145) —— 比 rgba(28,28,35,0.3)
    //   合成的 #BBBBBD 深一档,在浮岛白底上视觉对比清晰、又明显弱于 selected。
    //   接近原生 UITabBar 的 inactive (rgba(0,0,0,0.45)) 视觉。
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
                : [UIColor colorWithRed:140.0/255.0 green:140.0/255.0 blue:145.0/255.0 alpha:1.0];
        }];
    } else {
        selectedTextColor = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:35.0/255.0 alpha:1.0];
        normalTextColor   = [UIColor colorWithRed:140.0/255.0 green:140.0/255.0 blue:145.0/255.0 alpha:1.0];
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

    // 「消息」item icon 右上角的未读角标位置 — tabBar 每次 layout 都重定位,
    // 屏幕旋转 / Dynamic Type 切换 / iPad split 都会重排。
    [self _layoutMessageTabBadge];
}

#pragma mark - Message Tab Badge

-(void) setMessageUnreadCount:(NSInteger)count {
    if (count <= 0) {
        // 不存在 badge 实例时无需懒加载 — 直接 return,避免 0 → hidden 也分配一个 view
        if (!_messageTabBadge) return;
        _messageTabBadge.hidden = YES;
        return;
    }
    WKBadgeView *badge = self.messageTabBadge;
    badge.hidden = NO;
    badge.badgeValue = count > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
    [self _layoutMessageTabBadge];
}

- (WKBadgeView *)messageTabBadge {
    if (!_messageTabBadge) {
        _messageTabBadge = [WKBadgeView viewWithoutBadgeTip];
        _messageTabBadge.userInteractionEnabled = NO; // 不能挡住 tab item 点击
        // 与会话列表 cell 同源配色（WKUnreadBadge*Color：粉色背景 + 红色文字）
        [_messageTabBadge setBadgeBackgroundColor:WKUnreadBadgeBgColor()];
        [_messageTabBadge setBadgeTextColor:WKUnreadBadgeFgColor()];
        // tabBar 已 masksToBounds=NO（见 _applyCapsuleStyleToTabBar），badge 溢出 icon 右上角不会被裁
        [self.tabBar addSubview:_messageTabBadge];
    }
    return _messageTabBadge;
}

- (void)_layoutMessageTabBadge {
    if (!_messageTabBadge || _messageTabBadge.hidden) return;
    UIView *iconView = [self _iconViewForTabIndex:0];
    if (!iconView || !iconView.window) return; // tabBar 还没真正上屏，下次 layout 再试
    // 把 icon frame 转换到 tabBar 坐标系（badge 加在 tabBar 上）
    CGRect iconInTab = [self.tabBar convertRect:iconView.bounds fromView:iconView];
    CGSize size = _messageTabBadge.bounds.size;
    if (size.width <= 0 || size.height <= 0) return; // setBadgeValue 还没 setNeedsDisplay
    // badge 中心 ≈ icon 右上角再向外推一点（让 badge 一半溢出 icon 框，与微信 / Telegram 风格一致）
    CGFloat x = CGRectGetMaxX(iconInTab) - size.width * 0.35f;
    CGFloat y = CGRectGetMinY(iconInTab) - size.height * 0.35f;
    CGRect target = CGRectMake(x, y, size.width, size.height);
    if (!CGRectEqualToRect(_messageTabBadge.frame, target)) {
        _messageTabBadge.frame = target;
    }
}

/// 找到 tab item 在 tabBar 内的 icon UIImageView。系统给 tab item 渲染的容器
/// 是私有类 UITabBarButton，里面装一个 UITabBarSwappableImageView（UIImageView 子类）。
/// 不直接判类名 — 类名可能随 iOS 版本变。按 frame 排序找第 N 个 button-like 子视图,
/// 再在 button 子视图里找第一个 UIImageView 即可（label 是 UITabBarButtonLabel，
/// 不是 UIImageView）。找不到时返回 nil，layout 跳过等下一拍。
- (UIView *)_iconViewForTabIndex:(NSInteger)index {
    if (index < 0) return nil;
    NSMutableArray<UIView *> *itemViews = [NSMutableArray array];
    for (UIView *v in self.tabBar.subviews) {
        // tabBar.subviews 含 _UIBarBackground 等装饰视图 — 用尺寸 / 是否含 imageView 子视图过滤
        if (v.bounds.size.width <= 0 || v.bounds.size.height <= 0) continue;
        BOOL hasImage = NO;
        for (UIView *sub in v.subviews) {
            if ([sub isKindOfClass:[UIImageView class]]) { hasImage = YES; break; }
        }
        if (hasImage) [itemViews addObject:v];
    }
    if (itemViews.count <= (NSUInteger)index) return nil;
    [itemViews sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return [@(a.frame.origin.x) compare:@(b.frame.origin.x)];
    }];
    UIView *button = itemViews[index];
    for (UIView *sub in button.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) return sub;
    }
    return nil;
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
    [self _handlePossibleMessageTabDoubleTap:viewController];
}

/// 双击「消息」item = 定位下一个未读会话（与会话页内双击「最近」同一交互）。
///
/// 为什么不挂手势：UITabBarController 每次点击 item 都会回调
/// didSelectViewController:（**包括重复点当前已选中项**），所以时间戳判定就够了 ——
/// 不引入 UITapGestureRecognizer，就不会有「双击 GR 延迟单击」那类副作用，
/// 系统切 tab 的行为字面上不变。
///
/// 只认「两下都落在已经选中的消息 tab 上」：从别的 tab 双击「消息」时第一下是切
/// tab，不当成双击的第一下 —— 否则用户不耐烦快点两下切 tab 就会莫名跳一次。
/// （这一点与页内双击「最近」的语义有意不同：那边第一下切 tab、第二下就跳。）
- (void)_handlePossibleMessageTabDoubleTap:(UIViewController *)viewController {
    // 本次点击前是否已经停在这个 tab 上。主 tabbar 的 selectedIndex 全程没有任何
    // 程序化修改（只有用户点击），所以自己记一份 last selected 就是可信的。
    BOOL isReselect = (viewController == self.lastSelectedViewController);
    self.lastSelectedViewController = viewController;

    if (!isReselect || ![viewController isKindOfClass:[WKConversationListVC class]]) {
        self.lastMessageTabReselectAt = 0;
        return;
    }
    NSTimeInterval now = CACurrentMediaTime();
    if (self.lastMessageTabReselectAt > 0
        && (now - self.lastMessageTabReselectAt) < kWKMessageTabDoubleTapInterval) {
        self.lastMessageTabReselectAt = 0; // 消费掉，三击不会被算成两次双击
        [(WKConversationListVC *)viewController handleMessageTabDoubleTap];
    } else {
        self.lastMessageTabReselectAt = now;
    }
}

@end

