//
//  WKConversationSelectVC.m
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import "WKConversationListSelectVC.h"
#import "WKConversationWrapModel.h"
#import <SDWebImage/SDWebImage.h>
#import "WKResource.h"
#import "UIView+WK.h"
#import "WKLabelItemCell.h"
#import "WKIconTitleItemCell.h"
@interface WKConversationListSelectVC ()<WKChannelManagerDelegate,WKConversationListSelectVMDelegate>
@end

@implementation WKConversationListSelectVC


- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKConversationListSelectVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addDelegates];
}
-(void) addDelegates {
    // 频道信息监听
    [[[WKSDK shared] channelManager] addDelegate:self];
}

-(void) removeDelegates {
    // 移除频道监听
    [[[WKSDK shared] channelManager] removeDelegate:self];
}
-(void) dealloc {
    [self removeDelegates];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

#pragma mark WKConversationListSelectVMDelegate

- (void)conversationListSelectVM:(WKConversationListSelectVM *)vm didSelected:(NSArray<WKChannel *> *)channels {
    if(self.onSelect) {
        self.onSelect(channels[0]);
    }
}

#pragma mark -- WKChannelManagerDelegate
-(void) channelInfoUpdate:(WKChannelInfo*)channelInfo {
    [self reloadData];
}
@end

