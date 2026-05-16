//
//  WKChannelMessageSearchResultVC.m
//  WuKongBase
//
//  Created by tt on 2020/8/10.
//

#import "WKChannelMessageSearchResultVC.h"
#import "WKChannelMessageSearchVM.h"

@interface WKChannelMessageSearchResultVC ()<WKChannelManagerDelegate>

@property(nonatomic,strong) WKChannelInfo *channelInfo;

@end

@implementation WKChannelMessageSearchResultVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKChannelMessageSearchVM new];
    }
    return self;
}

- (void)viewDidLoad {
    self.viewModel.channel = self.channel;
    self.viewModel.keyword = self.keyword;
    [super viewDidLoad];
    
     [[WKChannelManager shared] addDelegate:self];
    
    self.channelInfo = [[WKChannelInfoDB shared] queryChannelInfo:self.channel];
    if(self.channelInfo) {
        self.title = self.channelInfo.displayName;
    }
    
}

- (void)dealloc
{
     [[WKChannelManager shared] removeDelegate:self];
}

- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo {
    [self reloadData];
}


@end
