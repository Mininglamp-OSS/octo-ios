//
//  WKConversationModel.m
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import "WKConversationWrapModel.h"
#import "WKApp.h"
#import "WKSpaceConversationCache.h"

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
    // 使用空间过滤后的消息的类型（与预览内容保持一致）
    WKMessage *displayMsg = [self spaceFilteredLastMessage];
    if(displayMsg) {
        return displayMsg.contentType;
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
    // Person 频道：优先使用后端的 space_unread
    if (self.c.channel.channelType == WK_PERSON) {
        NSNumber *spaceUnread = [[WKSpaceConversationCache shared] spaceUnreadForChannel:self.c.channel];
        if (spaceUnread != nil) {
            return [spaceUnread integerValue];
        }
    }
    return self.c.unreadCount;
}

- (void)setUnreadCount:(NSInteger)unreadCount {
    self.c.unreadCount = unreadCount;
}

/// 判断是否需要按空间过滤最后一条消息（所有个人聊天在多空间模式下都需要）
-(BOOL) isSystemBotChannel {
    if(self.c.channel.channelType != WK_PERSON) {
        return NO;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    return currentSpaceId && currentSpaceId.length > 0;
}

/// 获取当前空间对应的最后一条消息（仅用于会话列表的显示内容，不影响SDK逻辑）
-(WKMessage*) spaceFilteredLastMessage {
    WKMessage *rawLastMessage = self.lastChildConversation ? self.lastChildConversation.lastMessage : self.c.lastMessage;
    // Person 频道：先检查 rawLastMessage 是否属于当前空间（实时性优先）
    if (self.c.channel.channelType == WK_PERSON && rawLastMessage) {
        NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
        NSString *msgSpaceId = rawLastMessage.content.contentDict[@"space_id"];
        if (currentSpaceId.length > 0 && [msgSpaceId isKindOfClass:[NSString class]] && [msgSpaceId isEqualToString:currentSpaceId]) {
            return rawLastMessage; // rawLastMessage 属于当前空间，直接用（比缓存更新）
        }
        // rawLastMessage 不属于当前空间 → 用缓存替代 DB 扫描
        WKMessage *cached = [[WKSpaceConversationCache shared] spaceLastMessageForChannel:self.c.channel];
        if (cached) {
            return cached;
        }
    }
    if(![self isSystemBotChannel]) {
        return rawLastMessage;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!currentSpaceId || currentSpaceId.length == 0) {
        return rawLastMessage;
    }

    // 判断是否为BotFather（BotFather无space_id的消息不展示预览）
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    BOOL isBotFather = botfatherUID && [self.c.channel.channelId isEqualToString:botfatherUID];

    // 检查原始lastMessage是否属于当前空间
    if(rawLastMessage) {
        NSString *msgSpaceId = rawLastMessage.content.contentDict[@"space_id"];
        if([msgSpaceId isKindOfClass:[NSString class]] && [msgSpaceId isEqualToString:currentSpaceId]) {
            return rawLastMessage; // 明确匹配当前空间
        }
        // 消息没有 space_id 标记（nil或空）
        if(!msgSpaceId || [msgSpaceId isEqual:[NSNull null]] || ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length == 0)) {
            if(isBotFather) {
                // BotFather无space_id的消息：不展示，继续查找有space_id的消息
            } else {
                return rawLastMessage; // 非BotFather：视为属于当前空间
            }
        }
    }

    // lastMessage不属于当前空间（或BotFather无space_id），从本地DB查找当前空间的消息
    if(self.cachedSpaceLastMessage && [self.cachedSpaceId isEqualToString:currentSpaceId]) {
        return self.cachedSpaceLastMessage;
    }

    // 分页迭代查询，从最新消息往旧查找匹配当前space_id的消息
    WKMessage *spaceLastMessage = nil;
    WKMessage *noSpaceIdMessage = nil; // 记录第一条没有space_id的消息作为兜底（仅用于非BotFather）
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
            // 记录第一条没有space_id的消息（BotFather不兜底，只有非BotFather才用）
            if(!isBotFather && !noSpaceIdMessage && (!msgSpaceId || [msgSpaceId isEqual:[NSNull null]] || ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length == 0))) {
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
    // 没有匹配当前空间的消息时，非BotFather用没有space_id的消息兜底
    if(!spaceLastMessage && noSpaceIdMessage) {
        spaceLastMessage = noSpaceIdMessage;
    }
    // spaceLastMessage可能为nil（BotFather无匹配消息时返回nil，展示为空）
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
    // 清除空间过滤缓存，确保预览消息根据新会话数据重新计算
    self.cachedSpaceLastMessage = nil;
    self.cachedSpaceId = nil;
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
