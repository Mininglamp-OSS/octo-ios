//
//  WKScreenPasswordVC.m
//  WuKongBase
//
//  Created by tt on 2021/8/16.
//

#import "WKScreenPasswordVC.h"
#import "WKScreenPasswordSetVM.h"
#import "CALayer+WK.h"
#define WK_MAX_TRY_COUNT 5

@interface WKScreenPasswordVC ()

@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *tipLbl;
@property(nonatomic,strong) WKCorePasswordView *passwordView;
@property(nonatomic,strong) UIButton *forgetPwdBtn;
@property(nonatomic,strong) UILabel *warnLbl;
@property(nonatomic,assign) NSInteger tryCount; // 参数次数


@end

@implementation WKScreenPasswordVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKScreenPasswordVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.avatarImgView];
    [self.view addSubview:self.tipLbl];
    [self.view addSubview:self.passwordView];
    [self.view addSubview:self.forgetPwdBtn];
    [self.view addSubview:self.warnLbl];
    
    if(!self.allowBack) {
        self.navigationBar.hidden = YES;
        id target = self.navigationController.interactivePopGestureRecognizer.delegate;
        UIPanGestureRecognizer * pan = [[UIPanGestureRecognizer alloc]initWithTarget:target action:nil];
        [self.view addGestureRecognizer:pan];
    }
   
    
    
    
    NSNumber *tryCount = [WKApp shared].loginInfo.extra[@"lock_screen_try"];
    if(tryCount) {
        self.tryCount = tryCount.integerValue;
    }
    
    [self layout];
    
   
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.passwordView beginInput];
}

-(void) layout {
    self.avatarImgView.lim_centerX_parent = self.view;
    self.tipLbl.lim_top = self.avatarImgView.lim_bottom + 40.0f;
    self.tipLbl.lim_centerX_parent = self.view;
    
    self.passwordView.lim_top = self.tipLbl.lim_bottom + 80.0f;
    self.passwordView.lim_centerX_parent = self.view;
    
    self.forgetPwdBtn.lim_top = self.passwordView.lim_bottom + 40.0f;
    self.forgetPwdBtn.lim_centerX_parent = self.view;
    
    self.warnLbl.lim_top = self.tipLbl.lim_top;
    self.warnLbl.lim_centerX_parent = self.view;
}


- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, self.navigationBar.lim_bottom+10.0f, 100.0f, 100.0f)];
        [_avatarImgView setUrl:[WKAvatarUtil getAvatar:[WKApp shared].loginInfo.uid]];
    }
    return _avatarImgView;
}

- (UILabel *)tipLbl {
    if(!_tipLbl) {
        _tipLbl = [[UILabel alloc] init];
        _tipLbl.text = LLang(@"请输入锁屏密码");
        _tipLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        _tipLbl.textColor = [UIColor grayColor];
        [_tipLbl sizeToFit];
    }
    return _tipLbl;
}
- (WKCorePasswordView *)passwordView {
    if(!_passwordView) {
        __weak typeof(self) weakSelf = self;
        NSString *lockScreenPwd = [WKApp shared].loginInfo.extra[@"lock_screen_pwd"];
        _passwordView = [[WKCorePasswordView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.lim_width - 60.0f, 40.0f)];
        __weak typeof(_passwordView) weakPasswordView = _passwordView;
        [_passwordView setPasswordCompeleteBlock:^(NSString *password) {
            if([[WKScreenPasswordSetVM digestLockScreenPwd:password] isEqualToString:lockScreenPwd]) {
                if(weakSelf.onFinished) {
                    weakSelf.onFinished(password);
                }
            }else {
                weakSelf.tryCount++;
                if(weakSelf.tryCount >= WK_MAX_TRY_COUNT ) {
                    [weakSelf closeScreenPassword];
                    return;
                }
                
                [WKApp shared].loginInfo.extra[@"lock_screen_try"] = @(weakSelf.tryCount);
                [ [WKApp shared].loginInfo save];
                [weakPasswordView clearPassword];
                [weakPasswordView beginInput];
                [weakSelf showWarn];
            }
        }];
    }
    return _passwordView;
}

- (UIButton *)forgetPwdBtn {
    if(!_forgetPwdBtn) {
        _forgetPwdBtn = [[UIButton alloc] init];
        [_forgetPwdBtn setTitle:LLang(@"忘记密码") forState:UIControlStateNormal];
        [[_forgetPwdBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:14.0f]];
        [_forgetPwdBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [_forgetPwdBtn sizeToFit];
        
        [_forgetPwdBtn addTarget:self action:@selector(forgetPwdPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _forgetPwdBtn;
}

-(void) forgetPwdPressed {
    
    __weak typeof(self) weakSelf = self;
    
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"" message:LLang(@"确定后将会清除现有解锁密码，如需继续使用，请重新设置") preferredStyle:UIAlertControllerStyleAlert];
    
    // Create the actions.
    UIAlertAction *action = [UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
       
    }];
    [alertController addAction:action];
     action = [UIAlertAction actionWithTitle:LLang(@"确认") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
         [weakSelf closeScreenPassword];
        
    }];
    [alertController addAction:action];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

-(void) closeScreenPassword {
    [self.viewModel requestCloseLock].then(^{
        [WKApp shared].loginInfo.extra[@"lock_screen_try"] = @(0);
        [[WKApp shared].loginInfo.extra removeObjectForKey:@"lock_screen_pwd"];
        [ [WKApp shared].loginInfo save];
        [[WKApp shared] logout];
    });
}


-(void) showWarn {
    self.tipLbl.hidden = YES;
    self.warnLbl.hidden = NO;
    self.warnLbl.text = [self getWarnText];
    [self.warnLbl sizeToFit];
    [self layout];
    
    [self.warnLbl.layer shake];
}

- (UILabel *)warnLbl {
    if(!_warnLbl) {
        _warnLbl = [[UILabel alloc] init];
        _warnLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _warnLbl.textColor = [UIColor redColor];
        _warnLbl.hidden = YES;
    }
    return _warnLbl;
}

-(NSString*) getWarnText {
    return [NSString stringWithFormat:LLang(@"密码错误，还可以再输入%ld次"),WK_MAX_TRY_COUNT - self.tryCount];
}

@end
