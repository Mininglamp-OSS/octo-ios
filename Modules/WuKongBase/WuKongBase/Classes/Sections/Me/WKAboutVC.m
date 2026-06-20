//
//  WKAboutVC.m
//  WuKongBase
//

#import "WKAboutVC.h"

@interface WKAboutVC ()

@property(nonatomic,strong) UIImageView *appIconView;
@property(nonatomic,strong) UILabel *appNameLbl;
@property(nonatomic,strong) UILabel *versionLbl;

@property(nonatomic,strong) UIView *menuContainer;
@property(nonatomic,strong) UIView *userAgreementRow;
@property(nonatomic,strong) UIView *privacyPolicyRow;

@end

@implementation WKAboutVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = [NSString stringWithFormat:@"%@%@", LLang(@"关于"), [WKApp shared].config.appName ?: @""];
    self.view.backgroundColor = WKApp.shared.config.backgroundColor;

    [self setupUI];
    [self layoutUI];
}

// 切语言时刷 nav title + 两行 menu row 标题 (用 tag 反查内嵌 label)
- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if (type != WKViewConfigChangeTypeLang) return;
    self.title = [NSString stringWithFormat:@"%@%@", LLang(@"关于"), [WKApp shared].config.appName ?: @""];
    UILabel *l1 = (UILabel *)[_userAgreementRow viewWithTag:9001];
    UILabel *l2 = (UILabel *)[_privacyPolicyRow viewWithTag:9001];
    l1.text = LLang(@"用户协议");
    l2.text = LLang(@"隐私政策");
}

- (void)setupUI {
    // App Icon
    [self.view addSubview:self.appIconView];

    // App Name
    [self.view addSubview:self.appNameLbl];

    // Version
    [self.view addSubview:self.versionLbl];

    // Menu container
    [self.view addSubview:self.menuContainer];
    [self.menuContainer addSubview:self.userAgreementRow];
    [self.menuContainer addSubview:self.privacyPolicyRow];
}

- (void)layoutUI {
    CGFloat navBottom = [self getNavBottom];
    CGFloat centerX = self.view.frame.size.width / 2.0;

    // App Icon - centered, 80pt below nav
    CGFloat iconSize = 80.0f;
    self.appIconView.frame = CGRectMake(centerX - iconSize / 2.0, navBottom + 50.0f, iconSize, iconSize);
    self.appIconView.layer.cornerRadius = 16.0f;
    self.appIconView.layer.masksToBounds = YES;

    // App Name
    [self.appNameLbl sizeToFit];
    self.appNameLbl.frame = CGRectMake(centerX - self.appNameLbl.frame.size.width / 2.0,
                                       CGRectGetMaxY(self.appIconView.frame) + 20.0f,
                                       self.appNameLbl.frame.size.width,
                                       self.appNameLbl.frame.size.height);

    // Version
    [self.versionLbl sizeToFit];
    self.versionLbl.frame = CGRectMake(centerX - self.versionLbl.frame.size.width / 2.0,
                                       CGRectGetMaxY(self.appNameLbl.frame) + 8.0f,
                                       self.versionLbl.frame.size.width,
                                       self.versionLbl.frame.size.height);

    // Menu container
    // 与「我的 / 通用」InsetGrouped + WKMeCardStyle 卡片样式对齐:
    //   - 侧边距 16pt (InsetGrouped 默认观感)
    //   - 圆角 16pt + masksToBounds (WKMeCardStyle:62-69)
    //   - 行高 52pt (与 WKCommonSettingVM cellHeight 一致)
    //   - 分割线 inset 17pt 左右 (与 WKCommonSettingVM bottomLeft/RightSpace 一致)
    //   - 分割线色用与卡片同源的 WKMeCardDividerColor 等价值
    // 之前是手写全宽 UIView (15pt 左 inset / 全屏宽 / 直角 / 配置色 lineColor),
    // 与父页的卡片视觉割裂。
    CGFloat menuSideInset = 16.0f;
    CGFloat menuTop = CGRectGetMaxY(self.versionLbl.frame) + 30.0f;
    CGFloat rowHeight = 52.0f;
    CGFloat menuWidth = self.view.frame.size.width - menuSideInset * 2;

    self.menuContainer.frame = CGRectMake(menuSideInset, menuTop, menuWidth, rowHeight * 2);
    self.menuContainer.layer.cornerRadius = 16.0f;
    self.menuContainer.layer.masksToBounds = YES;

    self.userAgreementRow.frame = CGRectMake(0, 0, menuWidth, rowHeight);
    self.privacyPolicyRow.frame = CGRectMake(0, rowHeight, menuWidth, rowHeight);
    [self layoutMenuRow:self.userAgreementRow showSeparator:YES];
    [self layoutMenuRow:self.privacyPolicyRow showSeparator:NO];
}

#pragma mark - Lazy Properties

- (UIImageView *)appIconView {
    if (!_appIconView) {
        _appIconView = [[UIImageView alloc] init];
        _appIconView.contentMode = UIViewContentModeScaleAspectFit;
        // 统一走 WKApp +appLaunchIcon (登录页也复用同一份解析逻辑)。
        _appIconView.image = [WKApp appLaunchIcon];
    }
    return _appIconView;
}

- (UILabel *)appNameLbl {
    if (!_appNameLbl) {
        _appNameLbl = [[UILabel alloc] init];
        _appNameLbl.text = [WKApp shared].config.appName ?: @"";
        _appNameLbl.font = [UIFont boldSystemFontOfSize:22.0f];
        _appNameLbl.textColor = WKApp.shared.config.defaultTextColor;
        _appNameLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _appNameLbl;
}

- (UILabel *)versionLbl {
    if (!_versionLbl) {
        _versionLbl = [[UILabel alloc] init];
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *appVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
        NSString *buildNumber = [infoDictionary objectForKey:@"CFBundleVersion"];
        _versionLbl.text = [NSString stringWithFormat:@"version %@（%@）", appVersion ?: @"", buildNumber ?: @""];
        _versionLbl.font = [UIFont systemFontOfSize:16.0f];
        _versionLbl.textColor = [UIColor grayColor];
        _versionLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _versionLbl;
}

- (UIView *)menuContainer {
    if (!_menuContainer) {
        _menuContainer = [[UIView alloc] init];
        _menuContainer.backgroundColor = WKApp.shared.config.cellBackgroundColor;
    }
    return _menuContainer;
}

- (UIView *)userAgreementRow {
    if (!_userAgreementRow) {
        _userAgreementRow = [self createMenuRowWithTitle:LLang(@"用户协议")];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(userAgreementTapped)];
        [_userAgreementRow addGestureRecognizer:tap];
    }
    return _userAgreementRow;
}

- (UIView *)privacyPolicyRow {
    if (!_privacyPolicyRow) {
        _privacyPolicyRow = [self createMenuRowWithTitle:LLang(@"隐私政策")];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(privacyPolicyTapped)];
        [_privacyPolicyRow addGestureRecognizer:tap];
    }
    return _privacyPolicyRow;
}

#pragma mark - Helper

- (UIView *)createMenuRowWithTitle:(NSString *)title {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = WKApp.shared.config.cellBackgroundColor;
    row.userInteractionEnabled = YES;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.tag = 9001;     // viewConfigChange 切语言时按 tag 反查重置文案
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16.0f];
    titleLabel.textColor = WKApp.shared.config.defaultTextColor;
    [row addSubview:titleLabel];

    UIImageView *arrowView = [[UIImageView alloc] init];
    arrowView.image = [WKApp.shared loadImage:@"Common/Index/ArrowRight" moduleID:@"WuKongBase"];
    arrowView.contentMode = UIViewContentModeScaleAspectFit;
    arrowView.tag = 9002;
    [row addSubview:arrowView];

    UIView *separator = [[UIView alloc] init];
    separator.tag = 9003;
    separator.backgroundColor = [WKAboutVC cardDividerColor];
    [row addSubview:separator];

    return row;
}

/// row 内部子视图布局: 标题 / 箭头 / 底部分割线 —— 都依赖 row.frame.size.width,
/// 在 layoutUI 拿到 row 真宽后调用一次 (容器 16pt 侧边距让 row 不再等于全屏宽)。
- (void)layoutMenuRow:(UIView *)row showSeparator:(BOOL)showSeparator {
    CGFloat w = row.frame.size.width;
    CGFloat h = row.frame.size.height;

    UILabel *titleLabel = (UILabel *)[row viewWithTag:9001];
    UIImageView *arrowView = (UIImageView *)[row viewWithTag:9002];
    UIView *separator = [row viewWithTag:9003];

    titleLabel.frame = CGRectMake(17.0f, 0, w - 17.0f - 30.0f, h);
    arrowView.frame = CGRectMake(w - 17.0f - 16.0f, (h - 16.0f) / 2.0f, 16.0f, 16.0f);
    // 分割线左右 inset 17pt, 与 WKCommonSettingVM bottomLeft/RightSpace 对齐;
    // 最后一行不画分割线 (与 WKMeCardStyle 卡片末行同款)。
    separator.hidden = !showSeparator;
    if (showSeparator) {
        separator.frame = CGRectMake(17.0f, h - 0.5f, w - 34.0f, 0.5f);
    }
}

/// 与 WKMeCardStyle.m 内 static WKMeCardDividerColor 同源 —— static 函数没法跨文件
/// 复用, 这里复刻同一份动态色: 浅色 #F5F5FA, 深色 white α0.06。把 about 页和卡片
/// 列表分割线视觉拉齐 (之前用全局 lineColor, 与父列表 cell 分割线不一致)。
+ (UIColor *)cardDividerColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            BOOL isDark = (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
                       || ([WKApp shared].config.style == WKSystemStyleDark);
            if (isDark) return [UIColor colorWithWhite:1.0 alpha:0.06];
            return [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xFA/255.0 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xFA/255.0 alpha:1.0];
}

#pragma mark - Actions

- (void)userAgreementTapped {
    // 与登录页 (WKLoginView termsPressed) 同源: 走静态 CDN 上的 PDF (octoTermsURL),
    // 而非 server-side userAgreementUrl。后者会被 SSO 接管, 静态 CDN 这条更稳。
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.url = [NSURL URLWithString:[WKApp shared].config.octoTermsURL];
    [WKNavigationManager.shared pushViewController:vc animated:YES];
}

- (void)privacyPolicyTapped {
    // 与登录页 (WKLoginView privacyPressed) 同源: octoPrivacyURL (CDN PDF), 不是
    // server-side privacyAgreementUrl。
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.url = [NSURL URLWithString:[WKApp shared].config.octoPrivacyURL];
    [WKNavigationManager.shared pushViewController:vc animated:YES];
}

@end
