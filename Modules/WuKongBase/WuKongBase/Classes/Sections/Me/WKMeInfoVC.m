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
    
    [WKSDK.shared.channelManager addDelegate:self];
}


- (NSString *)langTitle {
    return LLang(@"个人信息");
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self reloadData]; // TODO: 修改名字或short_no后刷新
}

- (void)dealloc {
    [WKSDK.shared.channelManager removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_USER_AVATAR_UPDATE object:nil];
}

-(void) avatarUpdate:(NSNotification*)noti {
    NSDictionary *data = noti.object;
    if(data && data[@"uid"] && [[WKApp shared].loginInfo.uid isEqualToString:data[@"uid"]]) {
        [self.tableView reloadData];
    }
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
//    [[WKApp shared].loginInfo save];
    
    [self reloadData];
}

@end
