//
//  WKMePushSettingVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKMePushSettingVC.h"

@interface WKMePushSettingVC ()<WKMePushSettingDelegate>

@end

@implementation WKMePushSettingVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKMePushSettingVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (NSString *)langTitle {
    return LLang(@"新消息通知");
}

#pragma mark - WKMePushSettingDelegate

- (void)mePushSettingVMRefreshTable:(WKMePushSettingVM *)vm {
    [self reloadData];
}

@end
