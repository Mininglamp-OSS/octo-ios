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
    WKMessage *msg = self.lastMessage;
    if(msg) {
        return msg.contentType;
    }
    return 0;
}

- (NSInteger)lastMsgTimestamp {
    if([self isSystemBotChannel]) {
        WKMessage *msg = [self spaceFilteredLastMessage];
        if(msg) {
            return msg.timestamp;
        }
    }
    if(self.lastChildConversation) {
        return self.lastChildConversation.lastMsgTimestamp;
    }
    return self.c.lastMsgTimestamp;
}

- (NSString *)content {
    WKMessage *msg = self.lastMessage;
    if(msg) {
        if(msg.remoteExtra.contentEdit) {
            return [msg.remoteExtra.contentEdit conversationDigest];
        }
        return [msg.content conversationDigest];
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

/// 获取当前空间对应的最后一条消息（仅系统Bot使用）
-(WKMessage*) spaceFilteredLastMessage {
    WKMessage *rawLastMessage = self.lastChildConversation ? self.lastChildConversation.lastMessage : self.c.lastMessage;
    if(![self isSystemBotChannel]) {
        return rawLastMessage;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!currentSpaceId || currentSpaceId.length == 0) {
        return rawLastMessage;
    }

    // 检查原始lastMessage是否属于当前空间
    if(rawLastMessage) {
        NSString *msgSpaceId = rawLastMessage.content.contentDict[@"space_id"];
        if(!msgSpaceId || [msgSpaceId isKindOfClass:[NSNull class]] || [msgSpaceId isEqualToString:currentSpaceId]) {
            return rawLastMessage;
        }
    }

    // lastMessage不属于当前空间，从本地DB查找当前空间的最后一条消息
    if(self.cachedSpaceLastMessage && [self.cachedSpaceId isEqualToString:currentSpaceId]) {
        return self.cachedSpaceLastMessage; // 使用缓存
    }

    // 查询最近的消息，从中筛选属于当前空间的
    NSArray<WKMessage*> *messages = [[WKMessageDB shared] getMessages:self.c.channel startOrderSeq:0 endOrderSeq:0 limit:50 pullMode:WKPullModeDown];
    WKMessage *spaceLastMessage = nil;
    for (NSInteger i = messages.count - 1; i >= 0; i--) {
        WKMessage *msg = messages[i];
        NSString *msgSpaceId = msg.content.contentDict[@"space_id"];
        if(!msgSpaceId || [msgSpaceId isKindOfClass:[NSNull class]] || [msgSpaceId isEqualToString:currentSpaceId]) {
            spaceLastMessage = msg;
            break;
        }
    }
    // 缓存结果
    self.cachedSpaceLastMessage = spaceLastMessage;
    self.cachedSpaceId = currentSpaceId;
    return spaceLastMessage;
}

- (WKMessage *)lastMessage {
    return [self spaceFilteredLastMessage];
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
