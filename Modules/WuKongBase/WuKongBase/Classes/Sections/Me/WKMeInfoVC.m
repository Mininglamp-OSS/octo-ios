// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMeInfoVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/23.
//

#import "WKMeInfoVC.h"
#import "WKInputVC.h"
#import "WKActionSheetView2.h"
@interface WKMeInfoVC ()<WKMeInfoDelegate,WKChannelManagerDelegate>

@end

@implementation WKMeInfoVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKMeInfoVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avatarUpdate:) name:WKNOTIFY_USER_AVATAR_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(realnameUpdated:) name:WKNOTIFY_REALNAME_VERIFIED object:nil];

    [WKSDK.shared.channelManager addDelegate:self];
}


- (NSString *)langTitle {
    return LLang(@"个人信息");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self reloadData];
    // 强制从服务器拉取最新个人信息并刷新头像缓存（解决 web 端修改头像后 iOS 不更新的问题）
    WKChannel *myChannel = [WKChannel personWithChannelID:[WKApp shared].loginInfo.uid];
    [WKSDK.shared.channelManager fetchChannelInfo:myChannel completion:^(WKChannelInfo *channelInfo) {
        if (channelInfo) {
            // 强制刷新头像缓存 key，确保 SDWebImage 重新下载
            [[WKSDK shared].channelManager refreshAvatarCacheKey:myChannel];
        }
    }];
}

- (void)dealloc {
    [WKSDK.shared.channelManager removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_USER_AVATAR_UPDATE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_REALNAME_VERIFIED object:nil];
}

-(void) avatarUpdate:(NSNotification*)noti {
    NSDictionary *data = noti.object;
    if(data && data[@"uid"] && [[WKApp shared].loginInfo.uid isEqualToString:data[@"uid"]]) {
        NSLog(@"[Avatar] WKMeInfoVC received avatarUpdate notification");
        [self.tableView reloadData];
    }
}

-(void) realnameUpdated:(NSNotification*)noti {
    [self reloadData];
}

#pragma mark - 委托
// 修改名字
- (void)meInfoVMUpdateName:(WKMeInfoVM *)vm {
    __weak typeof(self) weakSelf = self;
    WKInputVC *inputVC = [WKInputVC new];
    inputVC.title = LLang(@"修改名字");
    inputVC.maxLength = 10;
    inputVC.defaultValue = [WKApp shared].loginInfo.extra[@"name"];
    [inputVC setOnFinish:^(NSString * _Nonnull value) {
        [weakSelf updateName:value];
    }];
    [[WKNavigationManager shared] pushViewController:inputVC animated:YES];
}

// 更新名称
-(void) updateName:(NSString*)name {
    [self.viewModel updateInfo:@"name" value:name].then(^{
        [WKApp shared].loginInfo.extra[@"name"] = name;
        [[WKApp shared].loginInfo save];
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
        // 更新下自己的频道
        [[WKChannelManager shared] fetchChannelInfo:[WKChannel personWithChannelID:[WKApp shared].loginInfo.uid]];
    }).catch(^(NSError *error){
         [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
    });
}

// 更新性别
-(void) updateSex:(NSInteger) sex {
    __weak typeof(self) weakSelf = self;
    [self.viewModel updateInfo:@"sex" value:[NSString stringWithFormat:@"%ld",(long)sex]].then(^{
        [WKApp shared].loginInfo.extra[@"sex"] = @(sex);
        [[WKApp shared].loginInfo save];
        [weakSelf reloadData];
    }).catch(^(NSError *error){
         [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
    });
}

// 更新短编码
-(void) updateShortNo:(NSString*)shortNo {
    [self.viewModel updateInfo:@"short_no" value:shortNo].then(^{
        [WKApp shared].loginInfo.extra[@"short_no"] = shortNo;
        [WKApp shared].loginInfo.extra[@"short_status"] = @(1);
        [[WKApp shared].loginInfo save];
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }).catch(^(NSError *error){
         [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
    });
}

// 修改性别
- (void)meInfoVMUpdateSex:(WKMeInfoVM *)vm {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
    [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"男") onClick:^{
        [weakSelf updateSex:1];
    }]];
    [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"女") onClick:^{
        [weakSelf updateSex:0];
    }]];
    [sheet show];
}
// 修改短编码
-(void) meInfoVMUpdateShortNo:(WKMeInfoVM*)vm {
    __weak typeof(self) weakSelf = self;
    WKInputVC *inputVC = [WKInputVC new];
    inputVC.maxLength = 10;
    inputVC.title = [NSString stringWithFormat:LLang(@"修改%@号"),[WKApp shared].config.appName];
    inputVC.defaultValue = [WKApp shared].loginInfo.extra[@"short_no"];
    inputVC.placeholder = [NSString stringWithFormat:LLang(@"%@号只允许修改一次"),[WKApp shared].config.appName];
    [inputVC setOnFinish:^(NSString * _Nonnull value) {
        [weakSelf updateShortNo:value];
       
    }];
    [[WKNavigationManager shared] pushViewController:inputVC animated:YES];
}

#pragma mark -- WKChannelManagerDelegate

- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo {
    if(channelInfo.channel.channelType != WK_PERSON) {
        return;
    }
    if(![channelInfo.channel.channelId isEqualToString:WKApp.shared.loginInfo.uid]) {
        return;
    }
    WKApp.shared.loginInfo.extra[@"name"] = channelInfo.name;
    [WKApp shared].loginInfo.extra[@"short_no"] = channelInfo.extra[@"short_no"];
    [WKApp shared].loginInfo.extra[@"sex"] = channelInfo.extra[@"sex"];
    // 同步实名认证状态
    id vVal = channelInfo.extra[@"realname_verified"];
    if(vVal) {
        [WKApp shared].loginInfo.realnameVerified = [vVal boolValue];
    }
    id rnVal = channelInfo.extra[@"real_name"];
    if([rnVal isKindOfClass:[NSString class]]) {
        [WKApp shared].loginInfo.realName = (NSString *)rnVal;
    }
    id tsVal = channelInfo.extra[@"realname_verified_at"];
    if(tsVal) {
        [WKApp shared].loginInfo.realnameVerifiedAt = [tsVal doubleValue];
    }
    // 与 WKMeVC.m:149 行为一致：同步完实名状态后持久化，避免
    // 用户在个人信息页收到 channel update 后杀 App 导致下次启动丢失实名状态。
    [[WKApp shared].loginInfo save];

    [self reloadData];
}

@end
