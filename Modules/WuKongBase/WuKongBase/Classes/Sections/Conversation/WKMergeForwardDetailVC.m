// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMergeForwardDetailVC.m
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import "WKMergeForwardDetailVC.h"

@interface WKMergeForwardDetailVC ()<WKChannelManagerDelegate>

@end

@implementation WKMergeForwardDetailVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKMergeForwardDetailVM new];
    }
    return self;
}

- (void)viewDidLoad {
    self.viewModel.mergeForwardContent = self.mergeForwardContent;
    [super viewDidLoad];

    NSString *baseTitle = self.mergeForwardContent.title ?: @"";
    NSInteger count = self.mergeForwardContent.msgs.count;
    self.title = count > 0
        ? [NSString stringWithFormat:LLang(@"%@ (%ld 条)"), baseTitle, (long)count]
        : baseTitle;

    [[WKSDK shared].channelManager addDelegate:self];

}

- (void)dealloc {
    [[WKSDK shared].channelManager removeDelegate:self];
}

#pragma mark - WKChannelManagerDelegate

- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo {
    [self.tableView reloadData];
}

@end
