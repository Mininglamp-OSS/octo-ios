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
    CGFloat menuTop = CGRectGetMaxY(self.versionLbl.frame) + 30.0f;
    CGFloat rowHeight = 50.0f;
    CGFloat menuWidth = self.view.frame.size.width;

    self.menuContainer.frame = CGRectMake(0, menuTop, menuWidth, rowHeight * 2 + 0.5f);
    self.userAgreementRow.frame = CGRectMake(0, 0, menuWidth, rowHeight);
    self.privacyPolicyRow.frame = CGRectMake(0, rowHeight + 0.5f, menuWidth, rowHeight);
}

#pragma mark - Lazy Properties

- (UIImageView *)appIconView {
    if (!_appIconView) {
        _appIconView = [[UIImageView alloc] init];
        _appIconView.contentMode = UIViewContentModeScaleAspectFit;
        // 加载App图标（Xcode编译后的AppIcon名称为 AppIcon60x60）
        UIImage *appIcon = [UIImage imageNamed:@"AppIcon60x60"];
        _appIconView.image = appIcon;
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

        // Bottom separator
        UIView *separator = [[UIView alloc] init];
        separator.backgroundColor = WKApp.shared.config.lineColor;
        separator.frame = CGRectMake(15.0f, 49.5f, [UIScreen mainScreen].bounds.size.width - 15.0f, 0.5f);
        [_userAgreementRow addSubview:separator];
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
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16.0f];
    titleLabel.textColor = WKApp.shared.config.defaultTextColor;
    titleLabel.frame = CGRectMake(15.0f, 0, 200.0f, 50.0f);
    [row addSubview:titleLabel];

    // Arrow
    UIImageView *arrowView = [[UIImageView alloc] init];
    arrowView.image = [WKApp.shared loadImage:@"Common/Index/ArrowRight" moduleID:@"WuKongBase"];
    arrowView.contentMode = UIViewContentModeScaleAspectFit;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    arrowView.frame = CGRectMake(screenWidth - 30.0f, 17.0f, 16.0f, 16.0f);
    [row addSubview:arrowView];

    return row;
}

#pragma mark - Actions

- (void)userAgreementTapped {
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.url = [NSURL URLWithString:WKApp.shared.config.userAgreementUrl];
    [WKNavigationManager.shared pushViewController:vc animated:YES];
}

- (void)privacyPolicyTapped {
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.url = [NSURL URLWithString:WKApp.shared.config.privacyAgreementUrl];
    [WKNavigationManager.shared pushViewController:vc animated:YES];
}

@end
