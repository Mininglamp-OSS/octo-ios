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

// _layoutTabItemsIntoSlots 的重入保护, 见该方法注释。
@property(nonatomic,assign) BOOL isLayingOutTabItems;
// 命中重入时置位, 由外层调用返回前重跑一次 —— 不能直接丢弃, 见 _layoutTabItemsIntoSlots 注释。
@property(nonatomic,assign) BOOL needsTabItemRelayout;
// 切 tab 的 pill spring 动画进行中。此时任何 animated:NO 的 pill 定位都必须跳过,
// 否则滑动被打断变成硬跳。守卫统一在 _layoutPillIndicatorAnimated: 开头实施,
// 调用点不需要自己判 (曾经只在两个调用点之一判过, 漏掉的那个由 viewDidLayoutSubviews
// 触发, 旋转 / 键盘升降都能绕过标志把动画打断)。
@property(nonatomic,assign) BOOL isPillAnimating;
// pill spring 动画的代次。见 _layoutPillIndicatorAnimated: —— 用来分辨
// 「本次动画自己结束」和「被后一次动画打断」, 后者不能清 isPillAnimating。
@property(nonatomic,assign) NSUInteger pillAnimationGeneration;
// _verifyTabBarInstalledOnce 只跑一次的标记。
@property(nonatomic,assign) BOOL didVerifyTabBarInstall;

@end

// 双击判定窗口。系统双击间隔约 0.25s，留一点余量；再长会把「点一下看一眼、
// 过一会儿再点一下」误判成双击。
static NSTimeInterval const kWKMessageTabDoubleTapInterval = 0.35;

// tab 标题字号。唯一消费方是 updateTabBarAppearance 的 titleTextAttributes
// (normal / selected 两处要用同一个字号)。
// 【必须声明在 updateTabBarAppearance 之前】—— 文件作用域 C 标识符只按文本顺序查找,
// 声明写在使用点之后会直接编译不过 ("use of undeclared identifier")。曾经就放在下面
// 「胶囊外观」那组常量里, 编译中断。
static const CGFloat kWKItemTitleFontSize = 10;

// +tabConfigs 里每条配置的 key
static NSString *const kWKTabCfgClass    = @"cls";    // UIViewController 子类
static NSString *const kWKTabCfgTitleKey = @"titleKey"; // 传给 LLang 的中文 key
static NSString *const kWKTabCfgImage    = @"image";  // 普通态图标名; 选中态 = 该名 + "1"

#pragma mark - WKOctoTabBar

// 职责一: 拿到「系统排完 item 之后」这个唯一可靠的时机。
//
// 为什么必须要它: UITabBar 在 iPad 全屏 (横向 regular) 下按「item 宽 201pt + 整体居中
// 成一簇」排布, 而 _pillFrameForIndex: 按 barW/count 三等分算 pill。实测 (iPad Air 2 /
// iPadOS 15.8, 竖屏 736pt 宽) 两套口径差 44.3pt:
//     消息   item 中心 183   vs pill 中心 138.7  → +44.3 (偏右)
//     上下文 item 中心 384   vs pill 中心 384    →   0   (恰好重合, 所以只有它看着是正的)
//     我的   item 中心 585   vs pill 中心 629.3  → −44.3 (偏左)
// 在 viewDidLayoutSubviews 里改 item frame 无效 —— 那个时机早于 / 交织于 tabBar 自己的
// layoutSubviews, 写进去的值会被系统重排覆盖 (曾被诊断日志误导: 日志打在写入那一刻,
// 拍不到之后的回滚)。只有 layoutSubviews 内、super 之后能保证我们是最后一个写入者。
//
// 职责二: 把 horizontalSizeClass 报成 compact, 让 UIKit 自己选 stacked 布局。
// 见 -traitCollection 注释。
//
// 回退到原实现的路径: 删掉 viewDidLoad 里的 setValue:forKey:@"tabBar" 那一行即可 ——
// 系统换回原生 UITabBar, 行为退回「图标不居中 + 文字在图标右下」的原状, 其余功能
// (pill / 浮岛 / 角标 / 双击) 都不依赖本类。
@interface WKOctoTabBar : UITabBar
/// 每次 super layoutSubviews 之后回调, 供宿主接管 item 的水平/垂直布局。
@property(nonatomic,copy,nullable) void (^onDidLayoutSubviews)(UITabBar *bar);
@end

@implementation WKOctoTabBar {
    // traitCollection 的缓存。UIKit 在布局期间会极高频调用 traitCollection,
    // 每次返回**新对象**会让某些内部路径按 isEqual: 判成「trait 变了」, 触发
    // traitCollectionDidChange: → updateTabBarAppearance → 重新布局 → 又读 trait,
    // 而本项目 WKBaseVC.traitCollectionDidChange 还会发 WK_NOTIFY_STYLE_CHANGE
    // 全局通知, 代价被放大。缓存后同一个 base 始终返回同一个派生对象。
    UITraitCollection *_cachedBaseTraits;
    UITraitCollection *_cachedCompactTraits;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _installCompactSizeClassOverride];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self _installCompactSizeClassOverride];
    }
    return self;
}

/// iOS 17+ 走受支持的 traitOverrides;更老的系统没有这个 API, 落到 -traitCollection
/// 覆写兜底 (见该方法注释)。
///
/// 为什么优先用 traitOverrides: 覆写 traitCollection getter 不是受支持的扩展点 ——
/// UIKit 自己维护一份 trait 状态, 内部布局路径到底读 self.traitCollection (会命中我们的
/// 覆写) 还是读传播下来的环境 (不受影响) 是无文档的, 且 iOS 17 已重写整套 trait 系统。
/// traitOverrides 是官方为「改本 view 及其后代的 trait」提供的入口, 会正确参与传播,
/// 不依赖任何内部实现细节。
///
/// 装上之后 [super traitCollection] 本身就报 compact, 下面的 getter 会走
/// 「本来就是 compact → 原样返回」那一条分支, 不再包装, 两条路不会打架。
- (void)_installCompactSizeClassOverride {
    if (@available(iOS 17.0, *)) {
        self.traitOverrides.horizontalSizeClass = UIUserInterfaceSizeClassCompact;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.onDidLayoutSubviews) {
        self.onDidLayoutSubviews(self);
    }
}

/// 【iOS 17 以下的兜底路径】iOS 17+ 已由 -_installCompactSizeClassOverride 用
/// traitOverrides 处理, 那时 super 已经报 compact, 本方法直接原样返回。
///
/// 只把 horizontalSizeClass 改成 compact, 其余 trait (userInterfaceStyle / 缩放等)
/// 原样从 super 带过来。
///
/// 为什么: UITabBar 的内容布局按 horizontalSizeClass 分支 ——
///     compact (iPhone 竖屏) → stacked  : 图标在上、文字在下, 都居中  ← 设计要的
///     regular (iPad 全屏)   → inline   : 图标和文字横向并排, 整对居中
/// 实测 (iPad Air 2 / iPadOS 15.8) 走的是 inline, 所以文字落在图标右下方且与图标
/// 纵向重叠 5.5pt:
///     icon  x 94..124   y 23..53
///     label x 130..150.5 y 47.5..59.5
/// 这不是 bug 而是 iPad 原生 tab bar 的传统样式, 但与本项目设计 (kWKCapsuleHeight
/// 注释里的「icon + 间距 4 + 标题」竖排) 不符。
///
/// 走这条路而不是用 imageInsets / titlePositionAdjustment 去补偏移: 改 UIKit 的**输入**
/// 让它自己排出我们要的布局, 而不是补它的**输出** —— 后者已多次被证明会在事务提交后
/// 被系统改回去, 且偏移量随标题文字宽度变化 (中文 −13.67 / −18.67, 换语言又是另一组)。
///
/// 影响范围仅限本 view: 子 VC 的 trait 不受影响, iPad 上会话列表等仍按 regular 布局。
/// stackedLayoutAppearance 的 titlePositionAdjustment (0,-12) 会因此真正生效 ——
/// 它本来就是为 stacked 布局写的, 走 inline 时一直在空转。
- (UITraitCollection *)traitCollection {
    UITraitCollection *base = [super traitCollection];
    if (base.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        return base;   // 本来就是 compact (iPhone / iPad 分屏窄态) —— 原样返回, 不做包装
    }
    // 同一个 base 复用同一个派生对象, 避免每次调用都造新对象 (见 ivar 处注释)
    if (_cachedCompactTraits && _cachedBaseTraits && [_cachedBaseTraits isEqual:base]) {
        return _cachedCompactTraits;
    }
    UITraitCollection *derived = [UITraitCollection traitCollectionWithTraitsFromCollections:@[
        base,
        [UITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassCompact]
    ]];
    _cachedBaseTraits = base;
    _cachedCompactTraits = derived;
    return derived;
}

@end

@implementation WKMainTabController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;

    // 换成 WKOctoTabBar, 拿到「系统排完 item 之后」的回调 (见该类注释)。
    //
    // 【私有 API 提示】tabBar 是只读属性, 这里走的是 UITabBarController 的私有
    // setTabBar: —— 是一个有意识的取舍, 不是顺手写的。必须在 addChildViewController
    // 之前, 否则 item 会先挂到原生 bar 上。
    //
    // 两条失败路径, 后果不同, 都要能看出来:
    //   1) setValue:forKey: 抛异常 → self.tabBar 仍是系统实例, 下面的判等跳过 hook,
    //      功能降级为「图标不居中」, 其余 (pill / 浮岛 / 角标 / 双击) 照常。
    //   2) 私有 setter 消失 → KVC **不抛异常**, 退化成直接写 backing ivar。此时
    //      self.tabBar 返回新 bar, 但它从未被接入视图层级, bar.superview == nil,
    //      _applyCapsuleStyleToTabBar 会一直提前返回 —— 浮岛 / pill / 角标全部消失,
    //      比第 1 种严重得多。所以视图层级那一项在首次 layout 后另行核验
    //      (见 _verifyTabBarInstalledOnce)。
    WKOctoTabBar *octoBar = [[WKOctoTabBar alloc] init];
    @try {
        [self setValue:octoBar forKey:@"tabBar"];
    } @catch (NSException *e) {
        NSLog(@"[WKMainTabController] 安装 WKOctoTabBar 失败, 退回系统 UITabBar: %@", e.reason);
    }
    if (self.tabBar == octoBar) {
        __weak typeof(self) weakSelf = self;
        [octoBar setOnDidLayoutSubviews:^(UITabBar *bar) {
            __strong typeof(weakSelf) self_ = weakSelf;
            if (!self_) return;
            // item 槽位与 pill 都从 _islandFrameInParent 取几何 (唯一真源), 且在同一个
            // 回调里紧邻执行 —— 两者不可能再读到不同的宽度。
            [self_ _layoutTabItemsIntoSlots];
            // spring 滑动进行中会被 _layoutPillIndicatorAnimated: 内部的守卫挡掉,
            // 这里不再重复判 isPillAnimating (不变量集中在那个方法里实施)。
            [self_ _layoutPillIndicatorAnimated:NO];
            // 角标锚在 icon 上, 而上面刚挪过 button —— 必须跟着重定位, 且必须排在
            // _layoutTabItemsIntoSlots 之后 (读的是修正后的 icon frame)。
            // 少了这一句, 本路径会把角标留在上一帧的位置, 靠下一次
            // _applyCapsuleStyleToTabBar 才收敛。
            [self_ _layoutMessageTabBadge];
        }];
    } else {
        NSLog(@"[WKMainTabController] tabBar 未被替换成 WKOctoTabBar (实际: %@), "
              @"降级为图标不居中", NSStringFromClass([self.tabBar class]));
    }

    // 监听 viewConfigChange 通知（WKBaseVC 的 traitCollectionDidChange 会发这个）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStyleChange) name:@"WK_NOTIFY_STYLE_CHANGE" object:nil];
    // 切语言时 tabbar item title 不会自动刷新, 必须监听 WKNOTIFY_LANG_CHANGE 重新走 LLang
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLangChange) name:WKNOTIFY_LANG_CHANGE object:nil];

    // tab 列表的唯一声明处 —— 见 +tabConfigs。
    // 【以后加 tab 只改那个数组，本方法不用动】
    for (NSDictionary *cfg in [self.class tabConfigs]) {
        NSString *imageName = cfg[kWKTabCfgImage];
        [self setupChildVC:cfg[kWKTabCfgClass]
                     title:LLang(cfg[kWKTabCfgTitleKey])
                     image:[UIImage imageNamed:imageName]
             selectedImage:[UIImage imageNamed:[imageName stringByAppendingString:@"1"]]];
    }

    // 必须在 setupChildVC 之后，applySelectedTitleColor 要遍历 self.viewControllers
    [self updateTabBarAppearance];

    // 启动就停在「消息」tab（selectedIndex 默认 0）。种下这个初值，第一次双击「消息」
    // 才能被正确判成「两下重选」；否则第一下会被当成切 tab 吃掉。
    self.lastSelectedViewController = self.viewControllers.firstObject;
}

/// tab 配置：**本类里唯一声明 tab 列表的地方**。
///
/// 【以后新增底部 tab 只需在这个数组里加一条】—— viewDidLoad 建 childVC、onLangChange
/// 刷标题、pill / item 槽位宽度、未读角标定位全部自动跟上, 不需要再改任何按数量写死的
/// 常量或索引。
///
/// 位置自适应的原理: pill 和 item 槽位都按 islandWidth / viewControllers.count 等分
/// (见 _islandFrameInParent / _pillFrameForIndex: / _applyTabItemSlotsOnce), count 变化
/// 时两边同步变, 天然对齐。
///
/// 选中态图标按现有命名约定 = image + "1" (消息 / 消息1)。新图标请沿用:
///   - 60×60 @2x + 90×90 @3x (现有 imageset 只填了 2x, @3x 设备上会放大发糊)
///   - 图形在画布内**居中** (现有 消息1 偏右 0.75pt、我的1 偏左 0.5pt, 是资源本身不对称)
///   - 单色剪影 + alpha (代码用 AlwaysTemplate 重染, 颜色由 appearance 控制)
///
/// 数量上限提醒: pill 宽 = islandW / count − 28。「上下文」三字 @10pt 约 31pt 宽,
/// 所以需要 islandW ≥ 59 × count。iPhone SE 一代 (islandW 288) 到 4 个仍有余量,
/// 5 个开始文字会顶出 pill —— 那时才需要把 kWKPillHorizontalInset 改成自适应。
+ (NSArray<NSDictionary *> *)tabConfigs {
    return @[
        @{ kWKTabCfgClass: WKConversationListVC.class, kWKTabCfgTitleKey: @"消息",   kWKTabCfgImage: @"消息"   },
        @{ kWKTabCfgClass: OctoContextEntryVC.class,   kWKTabCfgTitleKey: @"上下文", kWKTabCfgImage: @"上下文" },
        @{ kWKTabCfgClass: WKMeVC.class,               kWKTabCfgTitleKey: @"我的",   kWKTabCfgImage: @"我的"   },
    ];
}

- (void)onLangChange {
    // 标题 key 与顺序都来自 +tabConfigs, 不再单独维护一份数组 —— 原实现在这里硬编码了
    // @[@"消息", @"上下文", @"我的"], 加第 4 个 tab 时极易漏改, 后果是新 tab 切语言不刷新。
    NSArray<NSDictionary *> *cfgs = [self.class tabConfigs];
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController *vc, NSUInteger idx, BOOL *stop) {
        if (idx < cfgs.count) {
            vc.tabBarItem.title = LLang(cfgs[idx][kWKTabCfgTitleKey]);
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
                                     NSFontAttributeName: [UIFont systemFontOfSize:kWKItemTitleFontSize] };
    NSDictionary *selectedAttrs = @{ NSForegroundColorAttributeName: selectedTextColor,
                                     NSFontAttributeName: [UIFont systemFontOfSize:kWKItemTitleFontSize] };

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
        //
        // (曾一度删掉这三行, 改成在 _applyTabItemSlotsOnce 里直接写 icon/label 的 frame 来
        //  做垂直居中 —— 那条路已证明是错的: UIKit 会在事务提交后重排 button 内容并沿用
        //  我们硬写的 label 宽度, 把图标挤到负坐标。纵向微调必须走这个受支持的 API。)
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
// (kWKItemTitleFontSize 见文件顶部 —— 必须声明在 updateTabBarAppearance 之前)

// Liquid Glass 关闭后,标准 UITabBar 是横贯全宽的扁平条。这里手工把它做成"浮岛胶囊":
// 白底 capsuleBackground + pill 选中胶囊 + tabBar 透明在最上层承接事件。
// viewDidLayoutSubviews 每次 layout 都重 apply,因为 UITabBarController 自己会按
// safeArea / orientation 反复重排 tabBar.frame。
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self _verifyTabBarInstalledOnce];
    [self _applyCapsuleStyleToTabBar];
}

/// 核验 KVC 换 bar 的第 2 条失败路径 (见 viewDidLoad 注释): 私有 setter 消失时 KVC 会
/// 静默退化成直接写 ivar, self.tabBar 是新 bar 但从未接入视图层级 —— 表现是浮岛 / pill /
/// 角标整体消失, 而代码里到处都是「superview 为 nil 就 return 等下一拍」的软失败,
/// 不吭声就很难归因。上屏后核验一次, 出问题时大声报出来。
- (void)_verifyTabBarInstalledOnce {
    if (self.didVerifyTabBarInstall) return;
    if (!self.view.window) return;   // 还没上屏, 此时 superview 为 nil 是正常的, 不能下结论
    self.didVerifyTabBarInstall = YES;
    if (self.tabBar.superview == nil) {
        NSLog(@"[WKMainTabController] tabBar (%@) 不在视图层级里 —— KVC 换 bar 可能已退化成"
              @"直接写 ivar, 浮岛 / pill / 角标都不会出现。请检查 setTabBar: 是否仍存在。",
              NSStringFromClass([self.tabBar class]));
    }
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

/// 浮岛（= tabBar / capsuleBackground 的目标 frame）在 tabBar.superview 坐标系下的位置。
///
/// 【本方法是整个 tabbar 布局的唯一几何真源，务必保持所有消费方都走它】
///
/// 为什么必须集中到一处: 原实现里 _pillFrameForIndex: 读 bar.frame / bar.bounds,
/// _applyTabItemSlotsOnce 读 bar.bounds —— 都是「UIKit 当前摆到哪儿」的可变中间状态。
/// 这两段在**不同时机**跑 (item 在 WKOctoTabBar.layoutSubviews 里, pill 曾在
/// viewDidLayoutSubviews 里), 而 UITabBarController 会先给 tabBar 一个它自己的 frame
/// (全宽 768 / 1024), 之后才被 _applyCapsuleStyleToTabBar 改成浮岛宽度 (736 / 992)。
/// 于是两边可能读到不同的宽度, 算出不同的 itemW:
///     竖屏 pill 按 768/3=256 算、图标按 736/3=245.33 算
///     → pill 中心 144 / 400 / 656, 图标中心 138.67 / 384 / 629.33
///     → 偏差 −5.33 / −16 / −26.67, **三个图标全部偏左**, 且越往右偏得越多
/// 这正是「刚进入时图标都偏左, 点一下才正常」的成因 (点击触发的新 layout 里两边都已
/// 收敛到浮岛宽度)。
///
/// 改成从 self.view.bounds + safeAreaInsets 直接算, 不读任何 bar 的实时 frame ——
/// 布局结果就与「什么时候跑」彻底无关, 这类时序 bug 从根上消掉。
- (CGRect)_islandFrameInParent {
    CGFloat bottomSafe = self.view.safeAreaInsets.bottom;
    CGFloat parentW    = self.view.bounds.size.width;
    CGFloat parentH    = self.view.bounds.size.height;
    return CGRectMake(kWKCapsuleInsetX,
                      parentH - kWKCapsuleHeight - bottomSafe - kWKCapsuleBottomGap,
                      parentW - kWKCapsuleInsetX * 2,
                      kWKCapsuleHeight);
}

- (void)_applyCapsuleStyleToTabBar {
    UITabBar *bar = self.tabBar;
    if (!bar.superview || CGRectIsEmpty(self.view.bounds)) {
        return;
    }
    [self _setupCapsuleViewsIfNeeded];

    CGRect target = [self _islandFrameInParent];
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

    // item button 的 frame (槽位 + 热区) 由我们接管, 必须在 pill 和 badge 之前 ——
    // badge 要读修正后的 icon frame。button 内部的 icon / label 不碰。
    [self _layoutTabItemsIntoSlots];

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


#pragma mark - item 水平布局接管

/// tabBar 内的 item 容器 (系统私有类 UITabBarButton), 按 x 升序 == tab 顺序。
/// 结构化过滤而非判类名 (类名可能随 iOS 版本变): 是 UIControl + 有尺寸 + 含 UIImageView 子视图。
///
/// UIControl 这一条是必须的, 不只是收紧:
///   _UIBarBackground 也是 bar 的兄弟子视图, 也有非零 bounds, 且当 bar 设了
///   backgroundImage / shadowImage 时它内部会挂 UIImageView —— 而
///   _applyCapsuleStyleToTabBar 恰好把这两个都设成了 [UIImage new]。只靠
///   「有尺寸 + 含 UIImageView」在某些系统版本上会把它一并收进来, 于是 buttons.count
///   变成 count+1, _applyTabItemSlotsOnce 的数量闸门触发, **整个槽位修正静默失效**。
///   UITabBarButton 是 UIControl, _UIBarBackground 是普通 UIView, 这一条把两者分开,
///   同时保住「不写死私有类名」。
///
/// 显式排除 _messageTabBadge —— 它是 addSubview 到 tabBar 上的兄弟视图 (见
/// messageTabBadge getter), 内部若含 UIImageView 会被误当成 item button。
/// (它不是 UIControl, 已被上面那条挡掉, 这里保留是双保险。)
- (NSArray<UIView *> *)_sortedItemButtons {
    NSMutableArray<UIView *> *itemViews = [NSMutableArray array];
    for (UIView *v in self.tabBar.subviews) {
        if (v == _messageTabBadge) continue;
        if (![v isKindOfClass:[UIControl class]]) continue;
        if (v.bounds.size.width <= 0 || v.bounds.size.height <= 0) continue;
        BOOL hasImage = NO;
        for (UIView *sub in v.subviews) {
            if ([sub isKindOfClass:[UIImageView class]]) { hasImage = YES; break; }
        }
        if (hasImage) [itemViews addObject:v];
    }
    [itemViews sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        // 必须 stable: 首次 layout 前三个 button 的 origin.x 可能全是 0, 非稳定排序会
        // 打乱顺序, 导致槽位分配到错的 tab 上。相等时保留 bar.subviews 的原始顺序
        // (系统按 item 顺序添加), 即 tab 顺序。
        return [@(a.frame.origin.x) compare:@(b.frame.origin.x)];
    }];
    return itemViews;
}

/// 把每个 item button 摆到与 _pillFrameForIndex: 同源的槽位 (islandW/count)。
/// **只写 button.frame, 不碰它内部的 icon / label** —— 原因见 _applyTabItemSlotsOnce
/// 循环里那段注释 (硬写 icon/label frame 会被 UIKit 在事务提交后重排, 把图标挤到负坐标)。
///
/// 为什么要接管而不是用 itemPositioning / itemWidth:
///   iPad 全屏 (横向 regular) 下 UITabBar 默认 Centered 排布, item 居中挤成一簇, 与
///   _pillFrameForIndex: 的 barW/count 口径不一致 → 图标不在 pill 正中。实测 (iPad Air 2 /
///   iPadOS 15.8) 改 itemPositioning=Fill 或 Centered+显式 itemWidth 都不解决, 反而让
///   label 拿到近 0 的排版宽度 —— 「上下文」截断成「上…」、「我的」截断成「…」
///   (两个等长标题表现不同, 说明不是宽度不足, 是 item frame 本身不对)。
///   根因大概率是 _applyCapsuleStyleToTabBar 手工把 bar.frame 改成「宽度 −32 / 高度 76」
///   这个非标准值, 而 UITabBar 已按 controller 给的原始 frame 排过一轮, 两套基准不一致。
///   iPhone (compact / Fill) 上数字恰好对得上, 所以只有 iPad 暴露。
///
/// 只改 button 的 frame (= 槽位 + 热区), 内部内容排版交回 UIKit —— 它在一个 itemW 宽的
/// button 里排 stacked 布局, 本来就会把图标水平居中。纵向微调走 stackedLayoutAppearance
/// 的 titlePositionAdjustment (0,-12), 不在这里写 frame。
///
/// button.frame 就是热区, 所以点击位置自动跟着图标走 (这是不用 imageInsets 的原因:
/// imageInsets 只移动图标绘制位置, 热区留在原处, 会造成点图标没反应)。
///
/// 同源保证: 槽位算法与 _pillFrameForIndex: 都用 _islandFrameInParent 的宽度 / count,
/// 改一处必须同步改另一处。
- (void)_layoutTabItemsIntoSlots {
    // 重入保护 + 延迟重跑。
    //
    // 为什么不能命中重入就直接丢弃: 曾经这么写过, 造成「旋转后要点一下 tab 才对位」。
    // 当时循环里还有 [button layoutIfNeeded], 而 layoutIfNeeded 会先把标记为脏的**祖先**
    // 排一遍 —— _applyCapsuleStyleToTabBar 刚改过 bar.frame, tabBar 正脏, 于是嵌套成:
    //     _layoutTabItemsIntoSlots (guard=YES)
    //       └ [button layoutIfNeeded] → bar.layoutSubviews
    //           └ super 把 item 排回「201pt 居中一簇」
    //           └ onDidLayoutSubviews → _layoutTabItemsIntoSlots → 撞 guard, 直接 return
    // 真正需要做的修正被吞掉, item 停在系统的聚拢布局上; 点一下 tab 触发一次非嵌套的
    // layoutSubviews 才恢复。
    // 现在 layoutIfNeeded 已删 (我们跑在 layoutSubviews 内、super 之后, button 内部布局
    // 刚被 super 排完, 不需要再强制), 同时把 guard 改成记账 + 重跑, 双保险。
    if (_isLayingOutTabItems) {
        _needsTabItemRelayout = YES;
        return;
    }
    _isLayingOutTabItems = YES;

    // 必须有次数上限。原实现是裸 do/while(_needsTabItemRelayout) —— 一旦
    // _applyTabItemSlotsOnce 每次都套出嵌套调用 (嵌套那次撞 guard 后会把
    // _needsTabItemRelayout 重新置 YES), 循环永不退出, 主线程直接卡死。
    // 实测表现: App 界面还在但 IM 连不上 (心跳线程拿不到主线程时间片),
    // Bugly 开始抓栈 (jce_allStacks)。
    // 3 次足够收敛 (正常情况第 1 次就够); 到顶还没稳定就放手, 等下一拍 layout 再来,
    // 宁可这一帧布局不完美, 也绝不能卡住主线程。
    NSInteger pass = 0;
    do {
        _needsTabItemRelayout = NO;
        [self _applyTabItemSlotsOnce];
        pass++;
    } while (_needsTabItemRelayout && pass < 3);

    _isLayingOutTabItems = NO;
}

- (void)_applyTabItemSlotsOnce {
    NSInteger count = (NSInteger)self.viewControllers.count;
    NSArray<UIView *> *buttons = [self _sortedItemButtons];
    // 数量不符说明 tabBar 还没排完 (或系统换了内部结构) —— 整段跳过, 等下一拍 layout,
    // 宁可维持系统原样也不要摆出错位的半成品。
    CGRect island = [self _islandFrameInParent];
    if (CGRectIsEmpty(island) || count <= 0 || (NSInteger)buttons.count != count) {
#if DEBUG
        // 数量对不上而且不是「还没排」(0 个) 时留一声 —— 若将来 UIKit 换了内部结构,
        // 让 _sortedItemButtons 多收/少收一个, 这个闸门会让整段修正静默失效,
        // 表现就是「图标又不居中了」却没有任何线索。
        if (buttons.count > 0 && (NSInteger)buttons.count != count) {
            NSLog(@"[WKMainTabController] item button 数量不符 (识别到 %lu, 期望 %ld), "
                  @"本轮跳过槽位修正 —— 检查 _sortedItemButtons 的过滤条件。",
                  (unsigned long)buttons.count, (long)count);
        }
#endif
        return;
    }

    // 槽位尺寸取 _islandFrameInParent, 与 _pillFrameForIndex: 同一真源 ——
    // 不读 bar.bounds, 否则两者在不同时机会拿到不同宽度 (见 _islandFrameInParent 注释)。
    //
    // 坐标系: island 在 tabBar.superview 下, 而 button.frame 在 tabBar.bounds 下, 两者
    // 只有在 bar.frame == island 时才等价。当前调用顺序下这个前提确实成立
    // (_applyCapsuleStyleToTabBar 先把 bar.frame 改成 island 再调本方法; layoutSubviews
    // 回调路径上 bar 早已是浮岛尺寸), 但那是**另一个方法、另一个入口点**建立的顺序保证,
    // 在这里不可见 —— 靠它就等于埋一个「哪天顺序变了就整帧错位」的雷,
    // 而错位一帧正是本次要根除的那类 bug。
    // 所以直接把 island 换算到 bar 坐标系, 不依赖任何前提: 即使某一拍 bar.frame 还是
    // 系统给的全宽值, 算出来的槽位落在屏幕上的位置依然正确。
    UIView *parent = self.tabBar.superview;
    if (!parent) return;
    CGRect islandInBar = [self.tabBar convertRect:island fromView:parent];

    CGFloat itemW = islandInBar.size.width / (CGFloat)count;
    CGFloat itemH = islandInBar.size.height;

    for (NSInteger i = 0; i < count; i++) {
        UIView *button = buttons[i];
        CGRect slot = CGRectMake(islandInBar.origin.x + (CGFloat)i * itemW,
                                 islandInBar.origin.y,
                                 itemW,
                                 itemH);
        if (!CGRectEqualToRect(button.frame, slot)) {
            button.frame = slot;
        }
        // button 内部的 icon / label **一律不碰**, 交回 UIKit 自己排。
        //
        // 曾经在这里写过 icon.frame 和 label.frame (为了水平居中 + 垂直整组居中 +
        // 把 label 撑到槽位全宽防截断)。实测那是错的, 而且是「点几次就错位」的直接成因:
        //
        //   【事务提交前】icon={{107.67,15},{30,30}}  label={{14,49},{217.33,12}}   ← 我们写的
        //   【事务提交后】icon={{ -4.5,23},{30,30}}   label={{31.5,47.5},{217.5,12}} ← UIKit 重写
        //
        // UIKit 在提交后会重排 button 内容, 并且**沿用我们硬写给 label 的宽度**当内容宽度:
        //     icon(30) + 间隔(6) + label(217.5) = 253.5 > button 245.33
        //     在 button 内居中 → icon.x = (245.33 − 253.5)/2 = −4.08 ≈ −4.5
        // 图标被挤到负坐标、跑出 button 外, label 右移 17.58pt。每次点击触发新一轮
        // layout 就再犯一次。
        //
        // 而 label 加宽本来就是多余的: 当初加它是为了修文字截断, 但截断的真因是更早那两次
        // itemPositioning / itemWidth 改动 (已撤销), 与 label 宽度无关。button 现在是
        // 245.33pt (竖屏) / 330.67pt (横屏), 而「上下文」10pt 字号只需约 36pt, 空间远够。
        //
        // 结论: 我们只负责 button 的 frame (= 槽位 + 热区), 内容排版是 UIKit 的职责 ——
        // 它在一个 itemW 宽的 button 里排 stacked 布局, 本来就会把图标水平居中。
        // 纵向若需微调, 走 appearance 的 titlePositionAdjustment (受支持的 API),
        // 不要再回来改 frame。
    }
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

/// 「消息」tab 在 viewControllers 里的下标, 按 VC 类型查而不是写死 0。
///
/// 原实现是 _iconViewForTabIndex:0 —— 隐含「消息一定是第一个」。以后往前面插 tab
/// (比如加个「工作台」放在最左) 时, 未读角标会贴到错的图标上, 而且这种错很难被想到。
/// 按类型查之后, 顺序怎么调都不会错。
- (NSInteger)_indexOfMessageTab {
    NSArray<UIViewController *> *vcs = self.viewControllers;
    for (NSInteger i = 0; i < (NSInteger)vcs.count; i++) {
        if ([vcs[i] isKindOfClass:[WKConversationListVC class]]) return i;
    }
    return NSNotFound;
}

- (void)_layoutMessageTabBadge {
    if (!_messageTabBadge || _messageTabBadge.hidden) return;
    NSInteger messageIndex = [self _indexOfMessageTab];
    if (messageIndex == NSNotFound) return;
    UIView *iconView = [self _iconViewForTabIndex:messageIndex];
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
/// 容器的识别与排序复用 _sortedItemButtons（结构化过滤，不判类名），这里只负责在
/// 第 N 个 button 里取第一个 UIImageView（label 是 UITabBarButtonLabel，不是 UIImageView）。
/// 找不到时返回 nil，layout 跳过等下一拍。
- (UIView *)_iconViewForTabIndex:(NSInteger)index {
    if (index < 0) return nil;
    NSArray<UIView *> *itemViews = [self _sortedItemButtons];
    if (itemViews.count <= (NSUInteger)index) return nil;
    UIView *button = itemViews[index];
    for (UIView *sub in button.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) return sub;
    }
    return nil;
}

- (CGRect)_pillFrameForIndex:(NSInteger)index {
    // 几何一律取 _islandFrameInParent, 不读 bar.frame / bar.bounds —— 见该方法注释,
    // 读实时 bar frame 会与 _applyTabItemSlotsOnce 在不同时机拿到不同宽度。
    CGRect island = [self _islandFrameInParent];
    NSInteger count = MAX(1, (NSInteger)self.viewControllers.count);
    if (index < 0) index = 0;
    if (index >= count) index = count - 1;
    CGFloat itemW = island.size.width / (CGFloat)count;
    // pill 坐标在 tabBar.superview 下 (capsuleBackground / pillIndicator 都是它的 sibling)
    CGFloat x = island.origin.x + (CGFloat)index * itemW + kWKPillHorizontalInset;
    CGFloat y = island.origin.y + kWKPillVerticalInset;
    CGFloat w = itemW - 2 * kWKPillHorizontalInset;
    CGFloat h = island.size.height - 2 * kWKPillVerticalInset;
    return CGRectMake(x, y, w, h);
}

- (void)_layoutPillIndicatorAnimated:(BOOL)animated {
    if (!self.pillIndicator) return;
    if (CGRectIsEmpty(self.tabBar.bounds)) return;

    // 不变量「spring 动画进行中不得被 animated:NO 覆盖」在这里集中实施, 不放在调用点。
    //
    // 之前只在 WKOctoTabBar.layoutSubviews 回调那一处加了守卫, 漏掉了
    // _applyCapsuleStyleToTabBar 里的这一处 —— 而后者由 viewDidLayoutSubviews 触发,
    // 于是 0.34s 窗口内任何控制器级布局 (旋转 / Split View 改尺寸 / 键盘升降 /
    // additionalSafeAreaInsets 变化) 都会绕过标志把动画打成硬跳。
    // 两个调用点各写一遍守卫只是把漏写的概率推到下一个人身上, 所以收到这里 ——
    // 以后新增调用点自动继承这条不变量。
    if (!animated && self.isPillAnimating) {
        return;
    }

    CGRect target = [self _pillFrameForIndex:self.selectedIndex];
    CGFloat radius = target.size.height / 2.0;
    if (!animated) {
        self.pillIndicator.frame = target;
        self.pillIndicator.layer.cornerRadius = radius;
        return;
    }
    // 切换 tab: spring 滑动。damping/velocity 取偏跟手不晃的取值。
    // 滑动期间所有 animated:NO 的定位都被本方法开头的守卫挡掉, 否则刚启动的滑动
    // 会被立刻覆盖成硬跳。
    //
    // 为什么要 generation 而不是裸 BOOL: 0.34s 内快速连切两次时, 动画 B 会打断 A,
    // A 的 completion 以 finished == NO 立刻回调 —— 裸 BOOL 会在 B 还在飞的时候把
    // isPillAnimating 清成 NO, 于是 layoutSubviews 回调恢复用 animated:NO 覆盖 pill,
    // B 当场变硬跳, 正好是这个标志要防的事。只有「自己是最新一代」的 completion
    // 才有资格清标志; 被打断的那一代直接放行, 由打断它的那一代负责收尾。
    // (注意仍然不看 finished —— 最新一代即使被系统中途取消也必须清, 否则一次打断就
    //  永久卡在 YES, 旋转时 pill 再也不会跟着重排。)
    NSUInteger generation = self.pillAnimationGeneration + 1;
    self.pillAnimationGeneration = generation;
    self.isPillAnimating = YES;
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.34
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseOut
                                | UIViewAnimationOptionBeginFromCurrentState
                                | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;
        self_.pillIndicator.frame = target;
        self_.pillIndicator.layer.cornerRadius = radius;
    } completion:^(BOOL finished) {
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_ || self_.pillAnimationGeneration != generation) return;
        self_.isPillAnimating = NO;
        // 收尾必须重新定位一次, 不能就这么停下。
        //
        // 守卫收到方法内部之后, 动画期间**所有** animated:NO 都被挡掉了 —— 包括旋转 /
        // Split View 改尺寸带来的那些, 而它们是真的改了 target 几何。若不在这里补一次,
        // pill 会停在按旧几何算出的位置, 且之后不保证还有 layout 来纠正
        // (旋转的 layout 已经在动画期间发生过了), 表现是「转屏后 pill 错位, 要点一下才回正」。
        // 此时 isPillAnimating 已是 NO, 这次调用不会被自己的守卫挡掉, 也不会再递归。
        [self_ _layoutPillIndicatorAnimated:NO];
    }];
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
    // 这里不需要 setNeedsLayout —— WKOctoTabBar.layoutSubviews 会在系统换完
    // selectedImage / 重排 item 之后自动回调 _layoutTabItemsIntoSlots。
    // (曾经加过, 它会立刻触发 viewDidLayoutSubviews → _layoutPillIndicatorAnimated:NO,
    //  把上面这行刚启动的 spring 滑动打断, 切 tab 变成硬跳。)
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

