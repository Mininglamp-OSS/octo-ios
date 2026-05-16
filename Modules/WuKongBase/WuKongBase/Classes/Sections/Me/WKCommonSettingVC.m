// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKCommonSettingVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import "WKCommonSettingVC.h"
#import "WKCommonSettingVM.h"
#import "WKActionSheetView2.h"
@interface WKCommonSettingVC ()

@end

@implementation WKCommonSettingVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKCommonSettingVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LLang(@"通用");
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(realnameUpdated:)
                                                 name:WKNOTIFY_REALNAME_VERIFIED
                                               object:nil];
}

- (void)realnameUpdated:(NSNotification*)noti {
    [self reloadData];
}


- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if(type == WKViewConfigChangeTypeLang) {
        self.title = LLang(@"通用");
        [self reloadData];
    }
   
}

#pragma mark - WKCommonSettingVMDelegate
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    WKLogDebug(@"WKCommonSettingVC dealloc!");
}

@end
