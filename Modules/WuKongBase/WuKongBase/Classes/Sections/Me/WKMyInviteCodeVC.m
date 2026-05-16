//
//  WKMyInviteCodeVC.m
//  WuKongBase
//
//  Created by tt on 2024/4/22.
//

#import "WKMyInviteCodeVC.h"


@interface WKMyInviteCodeVC ()

@property(nonatomic,strong) UIView *boxView;
@property(nonatomic,strong) WKUserAvatar *avatar;
@property(nonatomic,strong) UILabel *nicknameLbl;
@property(nonatomic,strong) UILabel *inviteCodeLbl;
@property(nonatomic,strong) UIButton *cpBtn;
@property(nonatomic,strong) UIButton *disableBtn;

@property(nonatomic,assign) BOOL disable;

@end

@implementation WKMyInviteCodeVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LLang(@"我的邀请码");
    
    [self.view addSubview:self.boxView];
    [self.boxView addSubview:self.avatar];
    [self.boxView addSubview:self.nicknameLbl];
    [self.boxView addSubview:self.inviteCodeLbl];
    [self.boxView addSubview:self.cpBtn];
    [self.boxView addSubview:self.disableBtn];
    
    [self layout];
    
    [self loadInviteCode];
}

-(void) loadInviteCode {
    __weak typeof(self) weakSelf = self;
    
    // 获取邀请码
    [WKAPIClient.sharedClient GET:@"invite" parameters:nil].then(^(NSDictionary *resultDict){
        NSString *inviteCode = [resultDict objectForKey:@"invite_code"]?:@"";
        weakSelf.inviteCodeLbl.text = inviteCode;
        weakSelf.disable = ![[resultDict objectForKey:@"status"] boolValue];
        [weakSelf layout];
    }).catch(^(NSError *err){
        [weakSelf.view showHUDWithHide:err.domain];
    });
}


-(void) layout {
    
    
    
    if(self.disable) {
        [self.disableBtn setTitle:LLang(@"启用") forState:UIControlStateNormal];
    } else {
        [self.disableBtn setTitle:LLang(@"禁用") forState:UIControlStateNormal];
    }
    [self.disableBtn sizeToFit];
    
    CGFloat copyToDisableSpace = 60.0f;
    
    CGFloat buttonContentWidth = self.cpBtn.lim_width + copyToDisableSpace + self.disableBtn.lim_width;
    
    self.cpBtn.lim_left = self.boxView.lim_width/2.0f - buttonContentWidth/2.0f;
    self.disableBtn.lim_left = self.cpBtn.lim_right + copyToDisableSpace;
   
}

- (UIView *)boxView {
    if(!_boxView) {
        UIEdgeInsets edge = UIEdgeInsetsMake(0.0f, 20.0f, 0.0f, 20.0f);
        CGSize size = CGSizeMake(self.view.lim_width - edge.left - edge.right,self.view.lim_width - edge.left - edge.right);
        _boxView = [[UIView alloc] initWithFrame:CGRectMake(edge.left, self.view.lim_height/2.0f - size.height/2.0f, size.width, size.height)];
        _boxView.backgroundColor = WKApp.shared.config.cellBackgroundColor;
    }
    return _boxView;
}

- (WKUserAvatar *)avatar {
    if(!_avatar) {
        _avatar = [[WKUserAvatar alloc] init];
        _avatar.lim_top = 20.0f;
        _avatar.lim_centerX_parent = self.boxView;
        _avatar.url =  [WKAvatarUtil getAvatar:WKApp.shared.loginInfo.uid];
    }
    return _avatar;
}

- (UILabel *)nicknameLbl {
    if(!_nicknameLbl) {
        _nicknameLbl = [[UILabel alloc] init];
        _nicknameLbl.text = WKApp.shared.loginInfo.extra[@"name"]?:@"";
        [_nicknameLbl sizeToFit];
        _nicknameLbl.lim_top = self.avatar.lim_bottom + 10.0f;
        _nicknameLbl.lim_centerX_parent = self.boxView;
    }
    return _nicknameLbl;
}

- (UILabel *)inviteCodeLbl {
    if(!_inviteCodeLbl) {
        _inviteCodeLbl = [[UILabel alloc] init];
        _inviteCodeLbl.text = @"-------";
        _inviteCodeLbl.font = [WKApp.shared.config appFontOfSizeSemibold:40.0f];
        [_inviteCodeLbl sizeToFit];
        _inviteCodeLbl.lim_centerY_parent = self.boxView;
        _inviteCodeLbl.lim_centerX_parent = self.boxView;
    }
    return _inviteCodeLbl;
}

- (UIButton *)cpBtn {
    if(!_cpBtn) {
        _cpBtn = [[UIButton alloc] init];
        [_cpBtn setTitle:LLang(@"复制") forState:UIControlStateNormal];
        [_cpBtn setTitleColor:WKApp.shared.config.themeColor forState:UIControlStateNormal];
        [_cpBtn sizeToFit];
        _cpBtn.lim_top = self.boxView.lim_height - _cpBtn.lim_height - 20.0f;
        [_cpBtn addTarget:self action:@selector(copyPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _cpBtn;
}

- (UIButton *)disableBtn {
    if(!_disableBtn) {
        _disableBtn = [[UIButton alloc] init];
        [_disableBtn setTitleColor:WKApp.shared.config.themeColor forState:UIControlStateNormal];
        [_disableBtn setTitle:LLang(@"禁用") forState:UIControlStateNormal];
        [_disableBtn sizeToFit];
        _disableBtn.lim_top = self.boxView.lim_height - _disableBtn.lim_height - 20.0f;
        [_disableBtn addTarget:self action:@selector(disablePressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _disableBtn;
}

-(void) disablePressed {
    __weak typeof(self) weakSelf = self;
    [self.view showHUD];
    [WKAPIClient.sharedClient PUT:@"invite/status" parameters:nil].then(^{
        [weakSelf.view hideHud];
        [weakSelf loadInviteCode];
    }).catch(^(NSError *err){
        [weakSelf.view switchHUDError:err.domain];
    });
}

-(void) copyPressed {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.inviteCodeLbl.text;
    [self.view showHUDWithHide:LLang(@"复制成功")];
}

@end
