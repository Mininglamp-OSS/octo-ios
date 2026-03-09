//
//  WKConversationListSelectVM.m
//  WuKongBase
//
//  Created by tt on 2020/9/28.
//

#import "WKConversationListSelectVM.h"
#import "WKConversationListSelectCell.h"
#import "WKConversationWrapModel.h"
@interface WKConversationListSelectVM ()
@property(nonatomic,strong)  NSArray<WKConversationWrapModel*> *conversationWrapModels;

@property(nonatomic,strong) NSMutableArray<WKChannel*> *selectedChannels;
@end

@implementation WKConversationListSelectVM

- (NSArray<NSDictionary *> *)tableSectionMaps {
    
    NSMutableArray *items = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    if(self.conversationWrapModels) {
        for (WKConversationWrapModel *conversation in self.conversationWrapModels) {
            NSString *title;
            NSString *iconURL;
            if(conversation.channelInfo) {
                iconURL =[WKAvatarUtil getFullAvatarWIthPath:conversation.channelInfo.logo];
                title = conversation.channelInfo.displayName;
            }else {
                [conversation startChannelRequest];
            }
           bool selected = [weakSelf.selectedChannels containsObject:conversation.channel];
            [items addObject:@{
                @"class": WKConversationListSelectModel.class,
                @"title":title?:@"",
                @"iconURL": iconURL?:@"",
                @"circular":@(true),
                @"selected":@(selected),
                @"multiple": @(self.multiple),
                @"extra": conversation.channel,
                @"value":[self allowSelected:conversation.channelInfo]?@"":LLang(@"全员禁言中"),
                @"onClick":^{
                    if(![self allowSelected:conversation.channelInfo]) {
                        return;
                    }
                    if(weakSelf.multiple) {
                        if([weakSelf.selectedChannels containsObject:conversation.channel]) {
                            [weakSelf.selectedChannels removeObject:conversation.channel];
                        }else {
                            [weakSelf.selectedChannels addObject:conversation.channel];
                            
                        }
                        [weakSelf reloadData];
                    }else {
                        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(conversationListSelectVM:didSelected:)]) {
                            [weakSelf.delegate conversationListSelectVM:weakSelf didSelected:@[conversation.channel]];
                        }
                    }
                }
            }];
        }
    }
    
    return @[@{
                 @"height":@(0.01f),
                 @"items":@[
                         @{
                             @"class": WKLabelItemModel.class,
                             @"label":LLang(@"创建新的聊天"),
                             @"onClick":^{
                                 [[WKApp shared] invoke:WKPOINT_CONVERSATION_STARTCHAT param:@{@"on_complete":^(WKChannel *channel,NSError *error){
                                     if(error) {
                                         [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                                         return;
                                     }
                                     if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(conversationListSelectVM:didSelected:)]) {
                                         [weakSelf.delegate conversationListSelectVM:weakSelf didSelected:@[channel]];
                                     }
                                     
                                 }}];
                             }
                         }
                 ],
             },
             @{
                 @"height":@(0.01f),
                 @"title": LLang(@"最近聊天"),
                 @"items":items,
             }
    ];
}

- (NSMutableArray<WKChannel *> *)selectedChannels {
    if(!_selectedChannels) {
        _selectedChannels = [NSMutableArray array];
    }
    return _selectedChannels;
}

// 是否允许被选中
-(BOOL) allowSelected:(WKChannelInfo*) channelInfo {
    if(!channelInfo) {
        return false;
    }
    if(channelInfo.forbidden) {
        // 管理员允许发言
        return [[WKSDK shared].channelManager isManager:channelInfo.channel memberUID:[WKApp shared].loginInfo.uid];
    }
    return true;
}

- (void)requestData:(void (^)(NSError * _Nullable))complete {
    NSArray<WKConversation*> *conversations = [[[WKSDK shared] conversationManager] getConversationList];
    NSMutableArray *conversationWrapModels = [[NSMutableArray alloc] init];
    if(conversations) {
        for (WKConversation *conversation in conversations) {
            WKConversationWrapModel *wrapModel = [[WKConversationWrapModel alloc] initWithConversation:conversation];
            [conversationWrapModels addObject:wrapModel];
            
        }
        [self sortConversationList:conversationWrapModels];
    }
    self.conversationWrapModels = conversationWrapModels;
    
    complete(nil);
}

-(void) sortConversationList:(NSMutableArray<WKConversationWrapModel*>*) conversationWrapModels{
    [conversationWrapModels sortUsingComparator:^NSComparisonResult(WKConversationWrapModel   *obj1, WKConversationWrapModel   *obj2) {
        
        if(obj1.stick && !obj2.stick) {
            return NSOrderedAscending;
        }
        if(obj2.stick && !obj1.stick) {
            return NSOrderedDescending;
        }
        if(obj1.lastMsgTimestamp < obj2.lastMsgTimestamp) {
            return NSOrderedDescending;
        }else if(obj1.lastMsgTimestamp == obj2.lastMsgTimestamp) {
            return NSOrderedSame;
        }
        return NSOrderedAscending;
    }];
}

@end
