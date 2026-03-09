//
//  WKLoginPhoneCheckVC.m
//  WuKongLogin
//
//  Created by tt on 2020/10/26.
//

#import "WKLoginPhoneCheckVC.h"
#import "WKLoginVM.h"
#import "WKRegisterNextVC.h"
@interface WKLoginPhoneCheckVC ()<WKLoginPhoneCheckVMDelegate>

@property(nonatomic,strong) NSTimer *codeTimer;
@property(nonatomic,assign) NSInteger countdownSec; //倒计时

@end

static NSInteger countdown; // 倒计时

@implementation WKLoginPhoneCheckVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKLoginPhoneCheckVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    self.viewModel.phone = self.phone;
    [super viewDidLoad];
    
    self.countdownSec = 60.0f;
    
    __weak typeof(self) weakSelf = self;
    self.viewModel.sendBtnDisable = YES;
    [self reloadCodeItem];
    
    NSTimeInterval interval = [[NSDate date] timeIntervalSince1970];
    if(interval==0 || interval-countdown>weakSelf.countdownSec) {
        countdown = interval;
        [self sendLoginCheckCode];
    }else{
        self.countdownSec = 60.0f - (interval-countdown);
        [self startCountDown];
    }
}

- (NSString *)langTitle {
    return LLang(@"填写验证码");
}

-(void) sendLoginCheckCode {
    __weak typeof(self) weakSelf = self;
    [self.viewModel sendLoginCheckCode:self.uid].then(^{
        weakSelf.countdownSec = 60;
        [weakSelf startCountDown];
    }).catch(^{
        weakSelf.viewModel.sendBtnDisable = NO;
        [weakSelf reloadCodeItem];
    });
}

-(void) startCountDown {
    self.viewModel.sendBtnDisable = YES;
    self.viewModel.sendBtnTitle = [NSString stringWithFormat:LLang(@"重新发送(%ld)"),(long)self.countdownSec];
    [self reloadCodeItem];
    
    _codeTimer =
    [NSTimer scheduledTimerWithTimeInterval:1
                                     target:self
                                   selector:@selector(refreshSendCode)
                                   userInfo:nil
                                    repeats:YES];
}

-(void) refreshSendCode {
    if(self.countdownSec<=0) {
        if(self.codeTimer) {
            [self.codeTimer invalidate];
            self.codeTimer = nil;
        }
        self.viewModel.sendBtnDisable = NO;
        self.viewModel.sendBtnTitle = LLang(@"重新发送");
        [self reloadCodeItem];
        return;
    }
    self.countdownSec--;
    self.viewModel.sendBtnDisable = YES;
    self.viewModel.sendBtnTitle = [NSString stringWithFormat:LLang(@"重新发送(%ld)"),(long)self.countdownSec];
    [self reloadCodeItem];
}

- (void)dealloc {
    if(self.codeTimer) {
        [self.codeTimer invalidate];
        self.codeTimer = nil;
    }
}

#pragma mark - WKLoginPhoneCheckVMDelegate

- (void)loginPhoneCheckVMDidSend:(WKLoginPhoneCheckVM *)vm {
    [self sendLoginCheckCode];
}

- (void)loginPhoneCheckVMDidOk:(WKLoginPhoneCheckVM *)vm {
    
    __weak typeof(self) weakSelf = self;
    [self.view showHUD];
    [self.viewModel loginCheckPhone:self.uid code:[self.viewModel getCode]].then(^(WKLoginResp *resp){
        [weakSelf.view hideHud];
        
        if(!resp.name || [resp.name isEqualToString:@""]) { // 如果没名字就跳到完善注册资料页面
            [WKLoginVM handleLoginData:resp isSave:NO];
            WKRegisterNextVC *vc = [WKRegisterNextVC new];
            [[WKNavigationManager shared] pushViewController:vc animated:YES];
        }else {
            [WKLoginVM handleLoginData:resp isSave:YES];
            [[WKApp shared] invoke:WKPOINT_LOGIN_SUCCESS param:nil];
        }
        
    }).catch(^(NSError *error){
        [weakSelf.view switchHUDError:error.domain];
    });
}


// 重新加载验证吗的item
-(void) reloadCodeItem {
    self.items = [NSMutableArray arrayWithArray:[self.viewModel tableSections]];
    WKSMSCodeItemCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
    if(cell) {
        [cell refresh:self.items[1].items[0]];
    }
}

@end
