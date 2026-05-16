// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSpaceGateVC.m
//  WuKongLogin
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpaceGateVC.h"
#import "WKSpaceModel.h"

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

    // 检查是否有 DeepLink 暂存的邀请码
    [self checkPendingInviteCode];
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

- (void)checkPendingInviteCode {
    NSString *pendingCode = [[NSUserDefaults standardUserDefaults] stringForKey:@"WKPendingInviteCode"];
    if (!pendingCode || pendingCode.length == 0) {
        return;
    }

    // 清除暂存的邀请码
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"WKPendingInviteCode"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // 自动加入空间
    [self.view showHUD:LLang(@"正在通过邀请码加入空间...")];

    __weak typeof(self) weakSelf = self;
    [self.viewModel joinSpace:pendingCode].then(^(id result) {
        [weakSelf.view switchHUDSuccess:LLang(@"已加入空间")];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf checkSpaces];
        });
    }).catch(^(NSError *error) {
        NSString *msg = error.domain ?: @"";
        if ([msg containsString:@"已加入"] || [msg containsString:@"ALREADY_JOINED"] || [msg containsString:@"already"]) {
            // 已在空间中，直接检查空间并进入
            [weakSelf.view switchHUDSuccess:LLang(@"已在该空间中")];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf checkSpaces];
            });
        } else {
            [weakSelf.view switchHUDError:LLang(@"邀请码无效或已过期")];
            // 显示正常引导界面，让用户手动操作
        }
    });
}

- (void)checkSpaces {
    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"检查中...")];

    [self.viewModel getMySpaces].then(^(NSArray *spaces){
        [weakSelf.view hideHud];
        NSLog(@"✅ getMySpaces response: %@", spaces);
        if(spaces && spaces.count > 0) {
            NSDictionary *lastSpace = spaces.lastObject;
            NSString *spaceId = [weakSelf extractSpaceId:lastSpace];
            if(spaceId && spaceId.length > 0) {
                [[NSUserDefaults standardUserDefaults] setObject:spaceId forKey:@"currentSpaceId"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [weakSelf enterApp];
            }
        }
    }).catch(^(NSError *error){
        [weakSelf.view hideHud];
    });
}

/// 从空间字典中提取 space_id（兼容多种字段名）
- (NSString *)extractSpaceId:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    id value = dict[@"space_id"] ?: dict[@"sid"] ?: dict[@"id"] ?: dict[@"space_no"];
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    return nil;
}

- (void)enterApp {
    // 标记空间引导已完成
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WKSpaceGateCompleted"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];

    // Phase 2: 如果是从扫码/邀请命中 need_space 拉起的 Space Gate（
    // WKGroupScanJoinVC 会把群邀请上下文落盘到 `pendingGroupInvite`），加 Space
    // 成功后自动重放 WKPOINT_SCAN_HANDLER_JOIN_GROUP 重试入群。dispatch_after
    // 给 WKPOINT_LOGIN_SUCCESS 的 resetRootViewController + 同步数据一点缓冲，
    // 确保新首页栈就绪后再 push 群信息卡。
    [self replayPendingGroupInviteIfAny];
}

/// Phase 2：消费一次性的 pendingGroupInvite，用扫码 handler 重放群入场。
/// 本方法做"读后即清"，无论后续 replay 是否成功都不再重放。
- (void)replayPendingGroupInviteIfAny {
    NSDictionary *pending = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"pendingGroupInvite"];
    if (![pending isKindOfClass:[NSDictionary class]]) { return; }
    NSString *groupNo = pending[@"group_no"];
    if (!groupNo || groupNo.length == 0) { return; }

    // 一次性消费：失败也不重放，避免死循环。
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pendingGroupInvite"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WKScanResult *result = [WKScanResult new];
        result.type = @"group";
        result.data = pending;

        // 拿到 JOIN_GROUP 的扫码 handler，让它走与真实扫码一样的路径：
        // 构造 WKGroupScanJoinVC 并 push。用户在 Space Gate 已切到目标 Space，
        // 再次 scanjoin 后端不会再返回 need_space，会正常返回群信息。
        id handlerObj = [[WKApp shared] invoke:WKPOINT_SCAN_HANDLER_JOIN_GROUP param:nil];
        if ([handlerObj isKindOfClass:[WKScanHandler class]]) {
            [(WKScanHandler *)handlerObj handle:result reScan:^{}];
        }
    });
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
        _subtitleLbl.text = LLang(@"输入邀请码加入团队");
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

#pragma mark - Actions

- (void)showInviteInputPressed {
    self.showInviteInput = YES;
    self.inviteInputView.hidden = NO;
    self.showInviteInputBtn.hidden = YES;
}

- (void)backPressed {
    self.showInviteInput = NO;
    self.inviteInputView.hidden = YES;
    self.showInviteInputBtn.hidden = NO;
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

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(textField == self.inviteCodeTextField) {
        [self joinSpacePressed];
    }
    return YES;
}

@end
