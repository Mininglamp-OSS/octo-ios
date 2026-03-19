//
//  WKSpaceGateVC.m
//  WuKongLogin
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpaceGateVC.h"

@interface WKSpaceGateVC ()<UITextFieldDelegate>

@property(nonatomic,strong) UIView *containerView; // 白色容器
@property(nonatomic,strong) UILabel *emojiLbl; // 欢迎emoji
@property(nonatomic,strong) UILabel *titleLbl; // 标题
@property(nonatomic,strong) UILabel *subtitleLbl; // 副标题

// 邀请码相关
@property(nonatomic,strong) UIView *inviteInputView; // 邀请码输入容器
@property(nonatomic,strong) UITextField *inviteCodeTextField; // 邀请码输入框
@property(nonatomic,strong) UIButton *joinBtn; // 加入按钮
@property(nonatomic,strong) UIButton *backBtn; // 返回按钮

// 主按钮
@property(nonatomic,strong) UIButton *showInviteInputBtn; // 显示邀请码输入按钮
@property(nonatomic,strong) UIButton *createSpaceBtn; // 创建新团队按钮

@property(nonatomic,assign) BOOL showInviteInput; // 是否显示邀请码输入
@property(nonatomic,assign) BOOL isJoining; // 是否正在加入

@end

@implementation WKSpaceGateVC

- (instancetype)init {
    self = [super init];
    if (self) {
        self.viewModel = [WKSpaceGateVM new];
        self.showInviteInput = NO;
        self.isJoining = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationBar.hidden = YES;

    // 设置渐变背景
    [self setupGradientBackground];

    [self.view addSubview:self.containerView];
    [self.containerView addSubview:self.emojiLbl];
    [self.containerView addSubview:self.titleLbl];
    [self.containerView addSubview:self.subtitleLbl];

    // 添加邀请码输入视图
    [self.containerView addSubview:self.inviteInputView];
    [self.inviteInputView addSubview:self.inviteCodeTextField];
    [self.inviteInputView addSubview:self.joinBtn];
    [self.inviteInputView addSubview:self.backBtn];

    // 添加主按钮
    [self.containerView addSubview:self.showInviteInputBtn];
    [self.containerView addSubview:self.createSpaceBtn];
}

- (void)setupGradientBackground {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:102/255.0 green:126/255.0 blue:234/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:118/255.0 green:75/255.0 blue:162/255.0 alpha:1.0].CGColor
    ];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:gradient atIndex:0];
}

- (void)checkSpaces {
    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"检查中...")];

    [self.viewModel getMySpaces].then(^(NSArray *spaces){
        [weakSelf.view hideHud];
        if(spaces && spaces.count > 0) {
            // 有空间，进入主应用
            NSDictionary *firstSpace = spaces[0];
            NSString *spaceId = firstSpace[@"space_id"];
            if(spaceId && ![spaceId isEqualToString:@""]) {
                [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"currentSpaceId"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [weakSelf enterApp];
            }
        }
    }).catch(^(NSError *error){
        [weakSelf.view hideHud];
        // 没有空间或出错，显示引导页面
    });
}

- (void)enterApp {
    // 标记空间引导已完成
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WKSpaceGateCompleted"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

#pragma mark - UI Elements

- (UIView *)containerView {
    if(!_containerView) {
        CGFloat width = MIN(420, WKScreenWidth - 40);
        CGFloat height = 400;
        _containerView = [[UIView alloc] initWithFrame:CGRectMake((WKScreenWidth - width)/2.0f, (WKScreenHeight - height)/2.0f, width, height)];
        _containerView.backgroundColor = [UIColor whiteColor];
        _containerView.layer.cornerRadius = 16;
        _containerView.layer.shadowColor = [UIColor blackColor].CGColor;
        _containerView.layer.shadowOpacity = 0.2;
        _containerView.layer.shadowOffset = CGSizeMake(0, 20);
        _containerView.layer.shadowRadius = 60;
    }
    return _containerView;
}

- (UILabel *)emojiLbl {
    if(!_emojiLbl) {
        _emojiLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 48, self.containerView.lim_width, 40)];
        _emojiLbl.text = @"👋";
        _emojiLbl.font = [UIFont systemFontOfSize:32];
        _emojiLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _emojiLbl;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, self.emojiLbl.lim_bottom + 8, self.containerView.lim_width - 40, 30)];
        _titleLbl.text = [NSString stringWithFormat:LLang(@"欢迎使用 %@！"), [WKApp shared].config.appName];
        _titleLbl.font = [UIFont boldSystemFontOfSize:24];
        _titleLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _titleLbl;
}

- (UILabel *)subtitleLbl {
    if(!_subtitleLbl) {
        _subtitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, self.titleLbl.lim_bottom + 8, self.containerView.lim_width - 40, 20)];
        _subtitleLbl.text = LLang(@"加入团队或创建新的工作空间");
        _subtitleLbl.font = [UIFont systemFontOfSize:14];
        _subtitleLbl.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        _subtitleLbl.textAlignment = NSTextAlignmentCenter;
    }
    return _subtitleLbl;
}

- (UIView *)inviteInputView {
    if(!_inviteInputView) {
        _inviteInputView = [[UIView alloc] initWithFrame:CGRectMake(40, self.subtitleLbl.lim_bottom + 32, self.containerView.lim_width - 80, 150)];
        _inviteInputView.hidden = YES;
    }
    return _inviteInputView;
}

- (UITextField *)inviteCodeTextField {
    if(!_inviteCodeTextField) {
        _inviteCodeTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, self.inviteInputView.lim_width, 44)];
        _inviteCodeTextField.placeholder = LLang(@"输入邀请码");
        _inviteCodeTextField.borderStyle = UITextBorderStyleRoundedRect;
        _inviteCodeTextField.font = [UIFont systemFontOfSize:16];
        _inviteCodeTextField.returnKeyType = UIReturnKeyDone;
        _inviteCodeTextField.delegate = self;
    }
    return _inviteCodeTextField;
}

- (UIButton *)joinBtn {
    if(!_joinBtn) {
        _joinBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, self.inviteCodeTextField.lim_bottom + 12, self.inviteInputView.lim_width, 44)];
        [_joinBtn setTitle:LLang(@"加入") forState:UIControlStateNormal];
        [_joinBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_joinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _joinBtn.layer.cornerRadius = 4;
        [_joinBtn addTarget:self action:@selector(joinSpacePressed) forControlEvents:UIControlEventTouchUpInside];
        [WKApp.shared.config setThemeStyleButton:_joinBtn];
    }
    return _joinBtn;
}

- (UIButton *)backBtn {
    if(!_backBtn) {
        _backBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, self.joinBtn.lim_bottom + 8, self.inviteInputView.lim_width, 32)];
        [_backBtn setTitle:LLang(@"← 返回") forState:UIControlStateNormal];
        [_backBtn setTitleColor:[UIColor colorWithWhite:0.4 alpha:1.0] forState:UIControlStateNormal];
        _backBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [_backBtn addTarget:self action:@selector(backPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _backBtn;
}

- (UIButton *)showInviteInputBtn {
    if(!_showInviteInputBtn) {
        _showInviteInputBtn = [[UIButton alloc] initWithFrame:CGRectMake(40, self.subtitleLbl.lim_bottom + 32, self.containerView.lim_width - 80, 44)];
        [_showInviteInputBtn setTitle:LLang(@"📩 输入邀请码加入团队") forState:UIControlStateNormal];
        [_showInviteInputBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_showInviteInputBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _showInviteInputBtn.layer.cornerRadius = 4;
        [_showInviteInputBtn addTarget:self action:@selector(showInviteInputPressed) forControlEvents:UIControlEventTouchUpInside];
        [WKApp.shared.config setThemeStyleButton:_showInviteInputBtn];
    }
    return _showInviteInputBtn;
}

- (UIButton *)createSpaceBtn {
    if(!_createSpaceBtn) {
        _createSpaceBtn = [[UIButton alloc] initWithFrame:CGRectMake(40, self.showInviteInputBtn.lim_bottom + 12, self.containerView.lim_width - 80, 44)];
        [_createSpaceBtn setTitle:LLang(@"✨ 创建新团队") forState:UIControlStateNormal];
        [_createSpaceBtn setBackgroundColor:[UIColor colorWithWhite:0.95 alpha:1.0]];
        [_createSpaceBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
        _createSpaceBtn.layer.cornerRadius = 4;
        [_createSpaceBtn addTarget:self action:@selector(createSpacePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _createSpaceBtn;
}

#pragma mark - Actions

- (void)showInviteInputPressed {
    self.showInviteInput = YES;
    self.inviteInputView.hidden = NO;
    self.showInviteInputBtn.hidden = YES;
    self.createSpaceBtn.hidden = YES;
}

- (void)backPressed {
    self.showInviteInput = NO;
    self.inviteInputView.hidden = YES;
    self.showInviteInputBtn.hidden = NO;
    self.createSpaceBtn.hidden = NO;
    self.inviteCodeTextField.text = @"";
}

- (void)joinSpacePressed {
    NSString *inviteCode = [self.inviteCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if([inviteCode isEqualToString:@""]) {
        [self.view showHUDWithHide:LLang(@"请输入邀请码")];
        return;
    }

    self.isJoining = YES;
    [self.view showHUD:LLang(@"加入中...")];

    __weak typeof(self) weakSelf = self;
    [self.viewModel joinSpace:inviteCode].then(^(id result){
        [weakSelf.view switchHUDSuccess:LLang(@"已加入 Space")];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf checkSpaces];
        });
    }).catch(^(NSError *error){
        weakSelf.isJoining = NO;
        NSString *msg = error.domain;
        if([msg containsString:@"已满"] || [msg containsString:@"SPACE_FULL"]) {
            [weakSelf.view switchHUDError:LLang(@"空间已满，无法加入")];
        } else {
            [weakSelf.view switchHUDError:LLang(@"邀请码无效或已过期")];
        }
    });
}

- (void)createSpacePressed {
    // 创建Alert输入对话框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"创建 Space") message:LLang(@"请输入 Space 名称和描述") preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = LLang(@"Space 名称");
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = LLang(@"Space 描述（可选）");
    }];

    __weak typeof(self) weakSelf = self;
    __weak typeof(alert) weakAlert = alert;
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:LLang(@"创建") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *nameText = weakAlert.textFields[0].text;
        NSString *descText = weakAlert.textFields[1].text;

        NSString *name = [nameText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *spaceDesc = [descText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if(!name || [name isEqualToString:@""]) {
            [weakSelf.view showHUDWithHide:LLang(@"请输入 Space 名称")];
            return;
        }

        if(!spaceDesc) {
            spaceDesc = @"";
        }

        [weakSelf.view showHUD:LLang(@"创建中...")];
        [weakSelf.viewModel createSpace:name description:spaceDesc].then(^(NSDictionary *result){
            [weakSelf.view switchHUDSuccess:LLang(@"Space 创建成功")];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf checkSpaces];
            });
        }).catch(^(NSError *error){
            [weakSelf.view switchHUDError:LLang(@"创建失败，请重试")];
        });
    }];

    [alert addAction:cancelAction];
    [alert addAction:createAction];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(textField == self.inviteCodeTextField) {
        [self joinSpacePressed];
    }
    return YES;
}

@end
