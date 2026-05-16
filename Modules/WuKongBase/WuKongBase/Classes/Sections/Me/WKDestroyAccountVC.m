//
//  WKDestroyAccountVC.m
//  WuKongBase
//

#import "WKDestroyAccountVC.h"
#import "WKActionSheetView2.h"
#import "WKApp.h"
#import "WuKongBase.h"

typedef NS_ENUM(NSInteger, WKDestroyStatus) {
    WKDestroyStatusNormal = 0,
    WKDestroyStatusApplying = 1,
    WKDestroyStatusDone = 2,
};

@interface WKDestroyAccountVC ()

@property (nonatomic, assign) WKDestroyStatus destroyStatus;
@property (nonatomic, assign) NSInteger remainingDays;
@property (nonatomic, copy) NSString *expireAt;

// 通用
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *iconCircleView;
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *cardView;

// 申请状态
@property (nonatomic, strong) UIView *applyContainer;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UIButton *applyButton;

// 冷静期状态
@property (nonatomic, strong) UIView *coolingContainer;
@property (nonatomic, strong) UILabel *remainingLabel;
@property (nonatomic, strong) UILabel *expireDateLabel;
@property (nonatomic, strong) UILabel *coolingTipLabel;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UILabel *bottomTipLabel;

@property (nonatomic, assign) BOOL isRequesting;

@end

@implementation WKDestroyAccountVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LLang(@"注销账号");
    self.view.backgroundColor = WKApp.shared.config.backgroundColor;
    self.destroyStatus = WKDestroyStatusNormal;
    [self setupUI];
    [self fetchDestroyStatus];
}

#pragma mark - Setup UI

- (void)setupUI {
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];

    [self setupApplyUI];
    [self setupCoolingUI];

    self.coolingContainer.hidden = YES;
    self.applyContainer.hidden = YES;
}

- (void)setupApplyUI {
    self.applyContainer = [[UIView alloc] init];
    [self.contentView addSubview:self.applyContainer];

    // 红色警告图标
    UIView *iconCircle = [[UIView alloc] init];
    iconCircle.backgroundColor = [UIColor colorWithRed:0.95 green:0.25 blue:0.25 alpha:1.0];
    iconCircle.layer.cornerRadius = 35;
    [self.applyContainer addSubview:iconCircle];

    UILabel *iconLbl = [[UILabel alloc] init];
    iconLbl.text = @"!";
    iconLbl.font = [UIFont boldSystemFontOfSize:36];
    iconLbl.textColor = [UIColor whiteColor];
    iconLbl.textAlignment = NSTextAlignmentCenter;
    [iconCircle addSubview:iconLbl];

    // 标题
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text = LLang(@"申请注销账号");
    titleLbl.font = [UIFont boldSystemFontOfSize:22];
    titleLbl.textColor = WKApp.shared.config.defaultTextColor;
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [self.applyContainer addSubview:titleLbl];

    // 副标题
    UILabel *subtitleLbl = [[UILabel alloc] init];
    subtitleLbl.text = LLang(@"请仔细阅读以下注意事项");
    subtitleLbl.font = [UIFont systemFontOfSize:14];
    subtitleLbl.textColor = WKApp.shared.config.tipColor;
    subtitleLbl.textAlignment = NSTextAlignmentCenter;
    [self.applyContainer addSubview:subtitleLbl];

    // 注意事项卡片
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = WKApp.shared.config.cellBackgroundColor;
    card.layer.cornerRadius = 12;
    [self.applyContainer addSubview:card];
    self.cardView = card;

    NSArray *warnings = @[
        LLang(@"账号注销后，将无法登录此账号"),
        LLang(@"账号中的所有数据将被清除且无法恢复"),
        LLang(@"注销申请提交后有 7 天冷静期，期间可随时取消"),
        LLang(@"冷静期结束后账号将被永久注销"),
    ];

    UIView *lastWarningView = nil;
    for (NSInteger i = 0; i < warnings.count; i++) {
        UIView *row = [self createWarningRow:warnings[i] index:i];
        [card addSubview:row];
        lastWarningView = row;
    }

    // 密码输入框
    UIView *passwordContainer = [[UIView alloc] init];
    passwordContainer.backgroundColor = WKApp.shared.config.cellBackgroundColor;
    passwordContainer.layer.cornerRadius = 12;
    passwordContainer.layer.borderWidth = 1.0;
    passwordContainer.layer.borderColor = WKApp.shared.config.lineColor.CGColor;
    [self.applyContainer addSubview:passwordContainer];

    self.passwordField = [[UITextField alloc] init];
    self.passwordField.placeholder = LLang(@"请输入登录密码以验证身份");
    self.passwordField.secureTextEntry = YES;
    self.passwordField.font = [UIFont systemFontOfSize:16];
    self.passwordField.textColor = WKApp.shared.config.defaultTextColor;
    self.passwordField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.passwordField.returnKeyType = UIReturnKeyDone;
    [self.passwordField addTarget:self action:@selector(passwordFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [passwordContainer addSubview:self.passwordField];

    // 申请注销按钮
    self.applyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.applyButton setTitle:LLang(@"申请注销") forState:UIControlStateNormal];
    [self.applyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.applyButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.applyButton.backgroundColor = [UIColor colorWithRed:0.95 green:0.25 blue:0.25 alpha:1.0];
    self.applyButton.layer.cornerRadius = 24;
    self.applyButton.alpha = 0.5;
    self.applyButton.enabled = NO;
    [self.applyButton addTarget:self action:@selector(applyButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.applyContainer addSubview:self.applyButton];

    // 布局
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat padding = 20;
    CGFloat contentW = screenW - padding * 2;
    CGFloat y = 30;

    iconCircle.frame = CGRectMake((contentW - 70) / 2.0, y, 70, 70);
    iconLbl.frame = iconCircle.bounds;
    y = CGRectGetMaxY(iconCircle.frame) + 20;

    titleLbl.frame = CGRectMake(0, y, contentW, 30);
    y = CGRectGetMaxY(titleLbl.frame) + 8;

    subtitleLbl.frame = CGRectMake(0, y, contentW, 20);
    y = CGRectGetMaxY(subtitleLbl.frame) + 24;

    // 卡片布局
    CGFloat cardPadding = 16;
    CGFloat cardY = cardPadding;
    for (NSInteger i = 0; i < card.subviews.count; i++) {
        UIView *row = card.subviews[i];
        CGFloat rowH = [self heightForWarningText:warnings[i] width:contentW - cardPadding * 2 - 28];
        row.frame = CGRectMake(cardPadding, cardY, contentW - cardPadding * 2, rowH);

        // 布局内部子视图
        UIView *dot = row.subviews[0];
        UILabel *lbl = (UILabel *)row.subviews[1];
        dot.frame = CGRectMake(0, 6, 6, 6);
        lbl.frame = CGRectMake(16, 0, row.frame.size.width - 16, rowH);

        cardY = CGRectGetMaxY(row.frame) + 12;
    }
    cardY -= 12;
    cardY += cardPadding;
    card.frame = CGRectMake(0, y, contentW, cardY);
    y = CGRectGetMaxY(card.frame) + 24;

    passwordContainer.frame = CGRectMake(0, y, contentW, 52);
    self.passwordField.frame = CGRectMake(16, 0, contentW - 32, 52);
    y = CGRectGetMaxY(passwordContainer.frame) + 24;

    self.applyButton.frame = CGRectMake(0, y, contentW, 48);
    y = CGRectGetMaxY(self.applyButton.frame) + 40;

    self.applyContainer.frame = CGRectMake(padding, 0, contentW, y);
}

- (void)setupCoolingUI {
    self.coolingContainer = [[UIView alloc] init];
    [self.contentView addSubview:self.coolingContainer];

    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat padding = 20;
    CGFloat contentW = screenW - padding * 2;
    CGFloat y = 40;

    // 橙色时钟图标
    UIView *iconCircle = [[UIView alloc] init];
    iconCircle.backgroundColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.15 alpha:1.0];
    iconCircle.layer.cornerRadius = 35;
    iconCircle.frame = CGRectMake((contentW - 70) / 2.0, y, 70, 70);
    [self.coolingContainer addSubview:iconCircle];

    UILabel *clockLbl = [[UILabel alloc] init];
    clockLbl.text = @"⏳";
    clockLbl.font = [UIFont systemFontOfSize:32];
    clockLbl.textAlignment = NSTextAlignmentCenter;
    clockLbl.frame = iconCircle.bounds;
    [iconCircle addSubview:clockLbl];
    y = CGRectGetMaxY(iconCircle.frame) + 20;

    // 标题
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text = LLang(@"账号注销中");
    titleLbl.font = [UIFont boldSystemFontOfSize:22];
    titleLbl.textColor = WKApp.shared.config.defaultTextColor;
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.frame = CGRectMake(0, y, contentW, 30);
    [self.coolingContainer addSubview:titleLbl];
    y = CGRectGetMaxY(titleLbl.frame) + 24;

    // 状态卡片
    UIView *statusCard = [[UIView alloc] init];
    statusCard.backgroundColor = WKApp.shared.config.cellBackgroundColor;
    statusCard.layer.cornerRadius = 12;
    [self.coolingContainer addSubview:statusCard];

    CGFloat cardPadding = 20;

    // 剩余天数
    self.remainingLabel = [[UILabel alloc] init];
    self.remainingLabel.font = [UIFont boldSystemFontOfSize:18];
    self.remainingLabel.textColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.15 alpha:1.0];
    self.remainingLabel.textAlignment = NSTextAlignmentCenter;
    self.remainingLabel.frame = CGRectMake(cardPadding, cardPadding, contentW - cardPadding * 2, 24);
    [statusCard addSubview:self.remainingLabel];

    // 分割线
    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = WKApp.shared.config.lineColor;
    divider.frame = CGRectMake(cardPadding, cardPadding + 24 + 16, contentW - cardPadding * 2, 0.5);
    [statusCard addSubview:divider];

    // 到期日期
    self.expireDateLabel = [[UILabel alloc] init];
    self.expireDateLabel.font = [UIFont systemFontOfSize:14];
    self.expireDateLabel.textColor = WKApp.shared.config.tipColor;
    self.expireDateLabel.textAlignment = NSTextAlignmentCenter;
    self.expireDateLabel.frame = CGRectMake(cardPadding, CGRectGetMaxY(divider.frame) + 16, contentW - cardPadding * 2, 20);
    [statusCard addSubview:self.expireDateLabel];

    // 冷静期提示
    self.coolingTipLabel = [[UILabel alloc] init];
    self.coolingTipLabel.text = LLang(@"冷静期内登录或点击下方按钮可取消注销");
    self.coolingTipLabel.font = [UIFont systemFontOfSize:13];
    self.coolingTipLabel.textColor = WKApp.shared.config.tipColor;
    self.coolingTipLabel.textAlignment = NSTextAlignmentCenter;
    self.coolingTipLabel.numberOfLines = 0;
    self.coolingTipLabel.frame = CGRectMake(cardPadding, CGRectGetMaxY(self.expireDateLabel.frame) + 8, contentW - cardPadding * 2, 36);
    [statusCard addSubview:self.coolingTipLabel];

    CGFloat cardH = CGRectGetMaxY(self.coolingTipLabel.frame) + cardPadding;
    statusCard.frame = CGRectMake(0, y, contentW, cardH);
    y = CGRectGetMaxY(statusCard.frame) + 30;

    // 取消注销按钮
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cancelButton setTitle:LLang(@"取消注销") forState:UIControlStateNormal];
    [self.cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.cancelButton.backgroundColor = WKApp.shared.config.themeColor;
    self.cancelButton.layer.cornerRadius = 24;
    self.cancelButton.frame = CGRectMake(0, y, contentW, 48);
    [self.cancelButton addTarget:self action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.coolingContainer addSubview:self.cancelButton];
    y = CGRectGetMaxY(self.cancelButton.frame) + 20;

    // 底部提示
    self.bottomTipLabel = [[UILabel alloc] init];
    self.bottomTipLabel.text = LLang(@"冷静期结束后，账号将被永久注销且无法恢复");
    self.bottomTipLabel.font = [UIFont systemFontOfSize:12];
    self.bottomTipLabel.textColor = WKApp.shared.config.tipColor;
    self.bottomTipLabel.textAlignment = NSTextAlignmentCenter;
    self.bottomTipLabel.numberOfLines = 0;
    self.bottomTipLabel.frame = CGRectMake(0, y, contentW, 30);
    [self.coolingContainer addSubview:self.bottomTipLabel];
    y = CGRectGetMaxY(self.bottomTipLabel.frame) + 40;

    self.coolingContainer.frame = CGRectMake(padding, 0, contentW, y);
}

- (UIView *)createWarningRow:(NSString *)text index:(NSInteger)index {
    UIView *row = [[UIView alloc] init];

    UIView *dot = [[UIView alloc] init];
    dot.backgroundColor = [UIColor colorWithRed:0.95 green:0.25 blue:0.25 alpha:1.0];
    dot.layer.cornerRadius = 3;
    [row addSubview:dot];

    UILabel *lbl = [[UILabel alloc] init];
    lbl.text = text;
    lbl.font = [UIFont systemFontOfSize:15];
    lbl.textColor = WKApp.shared.config.defaultTextColor;
    lbl.numberOfLines = 0;
    [row addSubview:lbl];

    return row;
}

- (CGFloat)heightForWarningText:(NSString *)text width:(CGFloat)width {
    CGRect rect = [text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                    options:NSStringDrawingUsesLineFragmentOrigin
                                 attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15]}
                                    context:nil];
    return MAX(ceil(rect.size.height), 20);
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat navBottom = [self getNavBottom];
    CGFloat screenW = self.view.frame.size.width;
    CGFloat screenH = self.view.frame.size.height;

    self.scrollView.frame = CGRectMake(0, navBottom, screenW, screenH - navBottom);

    if (self.destroyStatus == WKDestroyStatusApplying) {
        self.contentView.frame = CGRectMake(0, 0, screenW, CGRectGetMaxY(self.coolingContainer.frame));
        self.scrollView.contentSize = self.contentView.frame.size;
    } else {
        self.contentView.frame = CGRectMake(0, 0, screenW, CGRectGetMaxY(self.applyContainer.frame));
        self.scrollView.contentSize = self.contentView.frame.size;
    }
}

#pragma mark - API

- (void)fetchDestroyStatus {
    [self.view showHUD];
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:@"user/destroy/status" parameters:nil].then(^(NSDictionary *result) {
        [weakSelf.view hideHud];
        NSInteger status = [result[@"destroy_status"] integerValue];
        weakSelf.remainingDays = [result[@"remaining_days"] integerValue];
        weakSelf.expireAt = result[@"expire_at"] ?: @"";
        weakSelf.destroyStatus = (WKDestroyStatus)status;
        [weakSelf updateUIForStatus];
    }).catch(^(NSError *error) {
        [weakSelf.view hideHud];
        [weakSelf updateUIForStatus];
    });
}

- (void)updateUIForStatus {
    if (self.destroyStatus == WKDestroyStatusApplying) {
        self.applyContainer.hidden = YES;
        self.coolingContainer.hidden = NO;

        self.remainingLabel.text = [NSString stringWithFormat:LLang(@"距离账号永久注销还剩 %ld 天"), (long)self.remainingDays];

        if (self.expireAt.length > 0) {
            self.expireDateLabel.text = [NSString stringWithFormat:LLang(@"预计注销日期：%@"), [self formatExpireDate:self.expireAt]];
        }
    } else {
        self.applyContainer.hidden = NO;
        self.coolingContainer.hidden = YES;
        self.passwordField.text = @"";
        self.applyButton.alpha = 0.5;
        self.applyButton.enabled = NO;
    }

    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (NSString *)formatExpireDate:(NSString *)dateStr {
    NSDateFormatter *inputFmt = [[NSDateFormatter alloc] init];
    inputFmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    inputFmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    NSDate *date = [inputFmt dateFromString:dateStr];

    if (!date) {
        inputFmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        date = [inputFmt dateFromString:dateStr];
    }
    if (!date) return dateStr;

    NSDateFormatter *outputFmt = [[NSDateFormatter alloc] init];
    outputFmt.dateFormat = @"yyyy-MM-dd HH:mm";
    return [outputFmt stringFromDate:date];
}

#pragma mark - Actions

- (void)passwordFieldChanged {
    BOOL hasText = self.passwordField.text.length > 0;
    self.applyButton.enabled = hasText;
    self.applyButton.alpha = hasText ? 1.0 : 0.5;
}

- (void)applyButtonTapped {
    if (self.isRequesting) return;

    NSString *password = self.passwordField.text;
    if (password.length == 0) return;

    [self.passwordField resignFirstResponder];

    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:LLang(@"确定要申请注销账号吗？提交后将进入 7 天冷静期，届满后账号将被永久注销。")];
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"确认注销") onClick:^{
        [weakSelf doApplyDestroy:password];
    }]];
    [sheet show];
}

- (void)doApplyDestroy:(NSString *)password {
    if (self.isRequesting) return;
    self.isRequesting = YES;

    [self.view showHUD];
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] POST:@"user/destroy/apply" parameters:@{@"password": password}].then(^(id responseObj) {
        weakSelf.isRequesting = NO;
        [weakSelf.view hideHud];
        weakSelf.destroyStatus = WKDestroyStatusApplying;
        weakSelf.remainingDays = 7;
        if ([responseObj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *result = (NSDictionary *)responseObj;
            weakSelf.expireAt = result[@"expire_at"] ?: @"";
            if ([result[@"destroy_status"] integerValue] > 0) {
                weakSelf.destroyStatus = [result[@"destroy_status"] integerValue];
            }
            if ([result[@"remaining_days"] integerValue] > 0) {
                weakSelf.remainingDays = [result[@"remaining_days"] integerValue];
            }
        }
        [weakSelf updateUIForStatus];
        [weakSelf.view showHUDWithHide:LLang(@"注销申请已提交")];
    }).catch(^(NSError *error) {
        weakSelf.isRequesting = NO;
        [weakSelf.view hideHud];
        [weakSelf.view showHUDWithHide:error.localizedDescription];
    });
}

- (void)cancelButtonTapped {
    if (self.isRequesting) return;

    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:LLang(@"确定要取消注销吗？取消后账号将恢复正常使用。")];
    [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"确认取消注销") onClick:^{
        [weakSelf doCancelDestroy];
    }]];
    [sheet show];
}

- (void)doCancelDestroy {
    if (self.isRequesting) return;
    self.isRequesting = YES;

    [self.view showHUD];
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] POST:@"user/destroy/cancel" parameters:nil].then(^{
        weakSelf.isRequesting = NO;
        [weakSelf.view hideHud];
        weakSelf.destroyStatus = WKDestroyStatusNormal;
        [weakSelf updateUIForStatus];
        [weakSelf.view showHUDWithHide:LLang(@"已取消注销")];
    }).catch(^(NSError *error) {
        weakSelf.isRequesting = NO;
        [weakSelf.view hideHud];
        [weakSelf.view showHUDWithHide:error.localizedDescription];
    });
}

#pragma mark - Touch

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

#pragma mark - Lazy

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.alwaysBounceVertical = YES;
        _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    }
    return _scrollView;
}

- (UIView *)contentView {
    if (!_contentView) {
        _contentView = [[UIView alloc] init];
    }
    return _contentView;
}

@end
