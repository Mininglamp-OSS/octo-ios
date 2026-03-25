//
//  WKConversationModel.m
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import "WKConversationWrapModel.h"
#import "WKApp.h"

@interface WKConversationWrapModel ()
@property(nonatomic,strong) WKConversation *c;
//@property(nonatomic,assign) NSInteger unreadCt;

@property(nonatomic,strong) WKChannelInfo *channelInfoInner;

@property(nonatomic,assign) BOOL notAllowLoadLocalChannelInfo; // 不允许再次加载本地频道数据

@property(nonatomic,strong) NSMutableArray<WKConversationWrapModel*> *children;

@property(nonatomic,strong) WKConversation *lastChildConversation; // 最新的子最近会话

@property(nonatomic,strong) WKMessage *cachedSpaceLastMessage; // 缓存的当前空间最后一条消息
@property(nonatomic,copy) NSString *cachedSpaceId; // 缓存对应的spaceId

@end

@implementation WKConversationWrapModel

-(instancetype) initWithConversation:(WKConversation*)conversation {
    self = [super init];
    if(self) {
        self.c = conversation;
//        self.unreadCt = conversation.unreadCount;
    }
    return self;
}

-(WKChannel*) channel {
    return self.c.channel;
}

- (WKChannel *)parentChannel {
    return self.c.parentChannel;
}

- (NSMutableArray<WKConversationWrapModel *> *)children {
    if(!_children) {
        _children = [NSMutableArray array];
    }
    return _children;
}

-(void) addOrUpdateChildren:(WKConversationWrapModel *)conversationWrapModel {
    NSInteger existIndex = -1;
    NSInteger i = 0;
    WKConversation *lastConversation = [conversationWrapModel getConversation];
    for (WKConversationWrapModel *c in self.children) {
        if([c.channel isEqual:conversationWrapModel.channel]) {
            existIndex = i;
        }
        if(c.lastMsgTimestamp>lastConversation.lastMsgTimestamp) {
            lastConversation = [c getConversation];
        }
        i++;
    }
    if(existIndex==-1) {
        [self.children addObject:conversationWrapModel];
    }else {
        [self.children replaceObjectAtIndex:existIndex withObject:conversationWrapModel];
    }
    self.lastChildConversation = lastConversation;
//    self.c = lastConversation;
    
    
}

-(WKConversationWrapModel*) getChildren:(WKChannel*)channel {
    for (WKConversationWrapModel *c in self.children) {
        if([c.channel isEqual:channel]) {
            return c;
        }
    }
    return nil;
}

- (WKChannelInfo*) channelInfo {
    if(!self.channelInfoInner && !self.notAllowLoadLocalChannelInfo) {// 防治cell大量刷新重复请求DB
        self.channelInfoInner = self.c.channelInfo;
        self.notAllowLoadLocalChannelInfo = true;
    }
    return self.channelInfoInner;
}

- (void)setChannelInfo:(WKChannelInfo *)channelInfo {
    _channelInfoInner = channelInfo;
    if(channelInfo) {
        self.c.mute = channelInfo.mute;
        self.c.stick = channelInfo.stick;
    }
}

-(void) startChannelRequest {
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].channelManager addChannelRequest:self.channel complete:^(NSError * _Nonnull error, bool notifyBefore) {
        if(notifyBefore) {
            self.notAllowLoadLocalChannelInfo = false;
            return;
        }
        if(error) {
            weakSelf.notAllowLoadLocalChannelInfo = true; // 请求报错不允许本地加载频道，因为本地根本没有
        }else {
            weakSelf.notAllowLoadLocalChannelInfo = false; // 这时本地有频道数据了。所以可以去本地加载
        }
    }];
}

-(void) cancelChannelRequest {
    [[WKSDK shared].channelManager cancelRequest:self.channel];
}

- (NSInteger)lastContentType {
    if(self.lastChildConversation) {
        return self.lastChildConversation.lastMessage.contentType;
    }
    if(self.c.lastMessage) {
        return self.c.lastMessage.contentType;
    }
    return 0;
}

- (NSInteger)lastMsgTimestamp {
    if(self.lastChildConversation) {
        return self.lastChildConversation.lastMsgTimestamp;
    }
    return self.c.lastMsgTimestamp;
}

- (NSString *)content {
    // 对BotFather等系统Bot，显示当前空间的最后一条消息内容
    WKMessage *displayMsg = [self spaceFilteredLastMessage];
    if(displayMsg) {
        if(displayMsg.remoteExtra.contentEdit) {
            return [displayMsg.remoteExtra.contentEdit conversationDigest];
        }
        return [displayMsg.content conversationDigest];
    }
    return @"";
}

- (NSArray<WKReminder *> *)simpleReminders {
    if(self.lastChildConversation) {
        return self.lastChildConversation.simpleReminders;
    }
    return self.c.simpleReminders;
}

- (BOOL)mute {
    return self.c.mute;
}
- (BOOL)stick {
    return self.c.stick;
}



- (NSInteger)unreadCount {
    
    return self.c.unreadCount;
}

- (void)setUnreadCount:(NSInteger)unreadCount {
    self.c.unreadCount = unreadCount;
}

/// 判断是否为系统Bot频道（如BotFather），需要按space_id过滤最后一条消息
-(BOOL) isSystemBotChannel {
    if(self.c.channel.channelType != WK_PERSON) {
        return NO;
    }
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    return botfatherUID && [self.c.channel.channelId isEqualToString:botfatherUID];
}

/// 获取当前空间对应的最后一条消息（仅用于会话列表的显示内容，不影响SDK逻辑）
-(WKMessage*) spaceFilteredLastMessage {
    WKMessage *rawLastMessage = self.lastChildConversation ? self.lastChildConversation.lastMessage : self.c.lastMessage;
    if(![self isSystemBotChannel]) {
        return rawLastMessage;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!currentSpaceId || currentSpaceId.length == 0) {
        return rawLastMessage;
    }

    // 检查原始lastMessage是否属于当前空间（或没有space_id标记）
    if(rawLastMessage) {
        NSString *msgSpaceId = rawLastMessage.content.contentDict[@"space_id"];
        if([msgSpaceId isKindOfClass:[NSString class]] && [msgSpaceId isEqualToString:currentSpaceId]) {
            return rawLastMessage; // 明确匹配当前空间
        }
        // 消息没有 space_id 标记（nil或空），视为属于当前空间
        if(!msgSpaceId || [msgSpaceId isEqual:[NSNull null]] || ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length == 0)) {
            return rawLastMessage;
        }
    }

    // lastMessage属于其他空间，从本地DB查找当前空间的消息
    if(self.cachedSpaceLastMessage && [self.cachedSpaceId isEqualToString:currentSpaceId]) {
        return self.cachedSpaceLastMessage;
    }

    // 分页迭代查询，从最新消息往旧查找匹配当前space_id的消息
    WKMessage *spaceLastMessage = nil;
    WKMessage *noSpaceIdMessage = nil; // 记录第一条没有space_id的消息作为兜底
    uint32_t cursor = 0; // 0表示从最新开始
    BOOL hasMore = YES;
    while (hasMore) {
        NSArray<WKMessage*> *messages = [[WKMessageDB shared] getMessages:self.c.channel startOrderSeq:cursor endOrderSeq:0 limit:200 pullMode:WKPullModeDown];
        if(!messages || messages.count == 0) {
            break;
        }
        for (WKMessage *msg in messages) {
            NSString *msgSpaceId = msg.content.contentDict[@"space_id"];
            if([msgSpaceId isKindOfClass:[NSString class]] && [msgSpaceId isEqualToString:currentSpaceId]) {
                spaceLastMessage = msg;
                break;
            }
            // 记录第一条没有space_id的消息
            if(!noSpaceIdMessage && (!msgSpaceId || [msgSpaceId isEqual:[NSNull null]] || ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length == 0))) {
                noSpaceIdMessage = msg;
            }
        }
        if(spaceLastMessage) {
            break;
        }
        WKMessage *oldestMsg = messages.lastObject;
        if(oldestMsg.orderSeq == 0) {
            break;
        }
        cursor = oldestMsg.orderSeq;
        hasMore = messages.count == 200;
    }
    // 没有匹配当前空间的消息时，用没有space_id的消息兜底
    if(!spaceLastMessage && noSpaceIdMessage) {
        spaceLastMessage = noSpaceIdMessage;
    }
    self.cachedSpaceLastMessage = spaceLastMessage;
    self.cachedSpaceId = currentSpaceId;
    return spaceLastMessage;
}

- (WKMessage *)lastMessage {
    if(self.lastChildConversation) {
        return self.lastChildConversation.lastMessage;
    }
    return self.c.lastMessage;
}

- (NSString *)lastClientMsgNo {
    if(self.lastChildConversation) {
        return self.lastChildConversation.lastClientMsgNo;
    }
    return self.c.lastClientMsgNo;
}

-(void) setLastMessage:(WKMessage*) message {
    [self.c setLastMessage:message];
    // 清除空间过滤缓存，下次访问时重新计算
    self.cachedSpaceLastMessage = nil;
    self.cachedSpaceId = nil;
    WKConversationWrapModel *childConversationWrapModel = [self getChildren:message.channel];
    if(childConversationWrapModel) {
        [childConversationWrapModel.c setLastMessage:message];
    }
}

-(void) reloadLastMessage {
    [self.c reloadLastMessage];
    // 清除空间过滤缓存
    self.cachedSpaceLastMessage = nil;
    self.cachedSpaceId = nil;
}

-(void) setConversation:(WKConversation*) conversation {
    self.c = conversation;
}

-(WKConversation*) getConversation {
    return self.c;
}

- (WKConversationExtra *)remoteExtra {
    return self.c.remoteExtra;
}

- (void)setRemoteExtra:(WKConversationExtra *)remoteExtra {
    self.c.remoteExtra = remoteExtra;
}



-(NSDictionary*) extra {
    return self.c.extra;
}

@end
