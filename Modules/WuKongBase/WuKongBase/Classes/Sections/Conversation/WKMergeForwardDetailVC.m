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
    
    self.title = self.mergeForwardContent.title;
    
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
