//
//  WKScreenPasswordSettingVC.m
//  WuKongBase
//
//  Created by tt on 2021/8/16.
//

#import "WKScreenPasswordSettingVC.h"

#import "WKScreenPasswordSettingVM.h"
#import "WKScreenPasswordSetVC.h"

@interface WKScreenPasswordSettingVC ()<WKScreenPasswordSettingVMDelegate>

@end

@implementation WKScreenPasswordSettingVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKScreenPasswordSettingVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LLang(@"解锁密码");
}


#pragma mark -- WKScreenPasswordSettingVMDelegate

- (void)screenPasswordSettingVMAutoLockDidClick:(WKScreenPasswordSettingVM *)vm {
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil cancel:LLang(@"取消")];
    [sheet addItem:[self getTimeSheetItem:0]];
    [sheet addItem:[self getTimeSheetItem:1]];
    [sheet addItem:[self getTimeSheetItem:5]];
    [sheet addItem:[self getTimeSheetItem:30]];
    [sheet addItem:[self getTimeSheetItem:60]];
    
    [sheet show];
}

- (void)screenPasswordSettingVMChangeLockDidClick:(WKScreenPasswordSettingVM *)vm {
    WKScreenPasswordSetVC *vc = [WKScreenPasswordSetVC new];
    [[WKNavigationManager shared] replacePushViewController:vc animated:YES];
}

- (void)screenPasswordSettingVMCloseLockDidClick:(WKScreenPasswordSettingVM *)vm {
    [self.view showHUD];
    __weak typeof(self) weakSelf = self;
    [self.viewModel requestCloseLock].then(^{
        [weakSelf.view hideHud];
        [[WKApp shared].loginInfo.extra removeObjectForKey:@"lock_screen_pwd"];
        [[WKApp shared].loginInfo save];
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }).catch(^(NSError *error){
        [weakSelf.view hideHud];
        [weakSelf.view showHUDWithHide:error.domain];
    });
}

-(WKActionSheetItem2*) getTimeSheetItem:(NSInteger)minute{
    
    __weak typeof(self) weakSelf = self;
    return [WKActionSheetButtonItem2 initWithTitle:[self.viewModel getLockTimeDesc:minute] onClick:^{
        [WKApp shared].loginInfo.extra[@"lock_after_minute"] = @(minute);
        [[WKApp shared].loginInfo save];
        
        [weakSelf reloadData];
        
        
        [weakSelf.viewModel requestSetLockAfterMinute].catch(^(NSError *error){
            [[WKNavigationManager shared].topViewController.view showHUDWithHide:error.domain];
        });
    }];
}


@end
