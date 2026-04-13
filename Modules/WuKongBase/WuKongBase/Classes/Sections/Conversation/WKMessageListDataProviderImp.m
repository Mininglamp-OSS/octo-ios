//
//  WKMessageListDataProviderImp.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKMessageListDataProviderImp.h"
#import "WuKongbase.h"
#import "WKMessageList.h"
#import "WKEndToEndEncryptHitContent.h"
#import "WKConversationListVM.h"
@interface WKMessageListDataProviderImp ()

@property(nonatomic,strong) WKChannel *channel;

@property(nonatomic,strong) WKMessageList *messageList;


@property(nonatomic,assign) NSInteger newMsgCount; // 新消息数量

@property(nonatomic,strong) id<WKConversationContext> conversationContextInner;



@end

@implementation WKMessageListDataProviderImp

-(instancetype) initWithChannel:(WKChannel*)channel conversationContext:(id<WKConversationContext>)conversationContext{
    self = [super init];
    if (self) {
        self.channel = channel;
        self.conversationContextInner = conversationContext;
    }
    return self;
}

- (id<WKConversationContext>)conversationContext {
    return self.conversationContextInner;
}


// 请求第一屏消息
-(void) pullFirst:(WKConversationPosition*)position complete:(void(^)(bool more))complete  {
    
    WKConversationWrapModel *model = [[WKConversationListVM shared] modelAtChannel:self.channel];
    uint32_t maxMessageSeq = 0;
    if(model && model.lastMessage && model.lastMessage.messageSeq>0) {
        maxMessageSeq = model.lastMessage.messageSeq;
    }
    
    
    if(position && ![self needsSpaceFiltering]) {
        // 无需空间过滤时，使用 position 直接加载
        __weak typeof(self) weakSelf = self;
        [[WKSDK shared].chatManager pullAround:self.channel orderSeq:position.orderSeq maxMessageSeq:maxMessageSeq limit:[WKApp shared].config.eachPageMsgLimit complete:^(NSArray<WKMessage *> * _Nonnull messages, NSError * _Nonnull error) {
            if(error || !messages || messages.count == 0) {
                if(complete) {
                    complete(false);
                }
                return;
            }
            [weakSelf.messageList clearMessages];
            [weakSelf handleMessages:[weakSelf messagesToMessageModels:messages] insertFirst:false complete:complete];
        }];
    } else {
        // 需要空间过滤时，忽略全局 position（因为它可能指向其他空间的消息区域），
        // 从最新消息开始递归向前搜索当前空间的消息
        __weak typeof(self) weakSelf = self;
        [self pullLastWithSpaceFilter:0 maxMessageSeq:maxMessageSeq accumulated:[NSMutableArray array] existingIds:[NSMutableSet set] complete:complete];
    }
}
-(NSArray<WKMessageModel*>*) messagesToMessageModels:(NSArray<WKMessage*>*) messages {
    // 按当前空间过滤消息
    NSArray<WKMessage*> *filteredMessages = [self filterMessagesBySpace:messages];
    NSMutableArray<WKMessageModel*> *messageModels = [NSMutableArray array];
    for (WKMessage *message in filteredMessages) {
        WKMessageModel *messageModel = [[WKMessageModel alloc] initWithMessage:message];
        [messageModels addObject:messageModel];
    }
    return messageModels;
}

/// 判断当前频道是否需要按空间过滤消息（所有个人聊天在多空间模式下都需要过滤）
-(BOOL) needsSpaceFiltering {
    if(self.channel.channelType != WK_PERSON) {
        return NO;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    return currentSpaceId && currentSpaceId.length > 0;
}

/// 过滤消息：仅显示当前空间的消息
/// 空间过滤模式下加载首屏：从最新消息递归向前搜索，直到凑够一页当前空间的消息
-(void) pullLastWithSpaceFilter:(uint32_t)endOrderSeq maxMessageSeq:(uint32_t)maxMessageSeq accumulated:(NSMutableArray<WKMessageModel*>*)accumulated existingIds:(NSMutableSet*)existingIds complete:(void(^)(bool more))complete {
    NSInteger pageLimit = [WKApp shared].config.eachPageMsgLimit;
    __weak typeof(self) weakSelf = self;

    [[WKSDK shared].chatManager pullLastMessages:self.channel endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:(int)pageLimit complete:^(NSArray<WKMessage *> * _Nonnull messages, NSError * _Nonnull error) {
        if (error || !messages || messages.count == 0) {
            if (accumulated.count > 0) {
                // 按 orderSeq 升序排列（旧消息在前，新消息在后）
                [accumulated sortUsingComparator:^NSComparisonResult(WKMessageModel *a, WKMessageModel *b) {
                    if (a.orderSeq < b.orderSeq) return NSOrderedAscending;
                    if (a.orderSeq > b.orderSeq) return NSOrderedDescending;
                    return NSOrderedSame;
                }];
                [weakSelf.messageList clearMessages];
                [weakSelf handleMessages:accumulated insertFirst:NO complete:complete];
            } else if (complete) {
                complete(NO);
            }
            return;
        }

        NSArray<WKMessageModel*> *models = [weakSelf messagesToMessageModels:messages];
        for (WKMessageModel *model in models) {
            if (![existingIds containsObject:model.clientMsgNo]) {
                [existingIds addObject:model.clientMsgNo];
                [accumulated addObject:model];
            }
        }

        BOOL rawHasMore = messages.count >= pageLimit;

        if (accumulated.count < pageLimit && rawHasMore) {
            WKMessage *oldestMsg = messages.lastObject;
            if (oldestMsg.orderSeq > 0) {
                [weakSelf pullLastWithSpaceFilter:oldestMsg.orderSeq maxMessageSeq:maxMessageSeq accumulated:accumulated existingIds:existingIds complete:complete];
                return;
            }
        }

        // 按 orderSeq 升序排列（旧消息在前，新消息在后）
        [accumulated sortUsingComparator:^NSComparisonResult(WKMessageModel *a, WKMessageModel *b) {
            if (a.orderSeq < b.orderSeq) return NSOrderedAscending;
            if (a.orderSeq > b.orderSeq) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        [weakSelf.messageList clearMessages];
        [weakSelf handleMessages:accumulated insertFirst:NO complete:complete];
    }];
}

-(NSArray<WKMessage*>*) filterMessagesBySpace:(NSArray<WKMessage*>*)messages {
    if(![self needsSpaceFiltering]) {
        return messages;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    BOOL isSystemBot = [self isSystemBotChannel];
    NSMutableArray<WKMessage*> *filtered = [NSMutableArray array];
    for (WKMessage *message in messages) {
        NSString *msgSpaceId = message.content.contentDict[@"space_id"];
        BOOL hasSpaceId = msgSpaceId && ![msgSpaceId isKindOfClass:[NSNull class]] && ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length > 0);
        if(!hasSpaceId) {
            // 无space_id的消息：系统bot(botfather)在空间模式下隐藏，普通聊天向前兼容显示
            if(!isSystemBot) {
                [filtered addObject:message];
            }
        } else if([msgSpaceId isEqualToString:currentSpaceId]) {
            [filtered addObject:message]; // space_id匹配当前空间
        }
    }
    return filtered;
}

/// 判断是否为系统bot频道（botfather等）
-(BOOL) isSystemBotChannel {
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    return botfatherUID && [self.channel.channelId isEqualToString:botfatherUID];
}

/// 判断单条消息是否应在当前空间显示（用于实时消息过滤）
-(BOOL) shouldShowMessageInCurrentSpace:(WKMessage*)message {
    if(![self needsSpaceFiltering]) {
        return YES;
    }
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    NSString *msgSpaceId = message.content.contentDict[@"space_id"];
    BOOL hasSpaceId = msgSpaceId && ![msgSpaceId isKindOfClass:[NSNull class]] && ([msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length > 0);
    if(!hasSpaceId) {
        // 系统bot无space_id的消息在空间模式下不显示
        return ![self isSystemBotChannel];
    }
    return [msgSpaceId isEqualToString:currentSpaceId];
}

// insertFirst 是否插入到数组最前
-(void) handleMessages:(NSArray<WKMessageModel*>*)messages insertFirst:(BOOL)insertFirst complete:(void(^)(bool more))complete{
//    bool hasMore = messages.count>=[WKApp shared].config.eachPageMsgLimit;
    bool hasMore = messages.count>=[WKApp shared].config.eachPageMsgLimit;
    if(messages && messages.count>0) {
        if(insertFirst) {
            [self.messageList insertMessages: [[messages reverseObjectEnumerator] allObjects]];
        }else{
            [self.messageList addMessages:messages];
        }
        
    }
    if(complete) {
        complete(hasMore);
    }
}

-(BOOL) hasEndToEndEncryptHitMessage {
    if(self.messageList.dates.count<=0) {
        return false;
    }
   NSString *date =  self.messageList.dates.firstObject;
    
   NSArray<WKMessageModel*> *messages =  [self.messageList messagesAtDate:date];
    if(messages && messages.count>0) {
        if([ messages[0].content isKindOfClass:[WKEndToEndEncryptHitContent class]]) {
            return true;
        }
    }
    return false;
}

-(void) insertEndToEndEncryptHitMessageIfNeed {
    if(self.channel.channelType != WK_PERSON) {
        return;
    }
    if([self hasEndToEndEncryptHitMessage]) {
        return;
    }
//    if(self.state && !self.state.signalOn) {
//        return;
//    }
    if(self.messageList.dates && self.messageList.dates.count>0) {
        NSString *date = self.messageList.dates.firstObject;
        NSMutableArray *messages = [NSMutableArray arrayWithArray:[self.messageList messagesAtDate:date]];
        [messages insertObject:[self newEndToEndEncryptHitMessage] atIndex:0];
        [self.messageList setMessages:messages forDate:date];
    }else {
        NSMutableArray *messages = [NSMutableArray arrayWithArray:@[[self newEndToEndEncryptHitMessage]]];
        [self.messageList setMessages:messages forDate:[self formatDate:[NSDate date]]];
    }
}

-(NSString*) formatDate:(NSDate*)date {
    return [WKTimeTool getTimeString:date format:@"yyyy-MM-dd" ];
}
-(WKMessageModel*) newEndToEndEncryptHitMessage {
    WKMessage *message = [WKMessage new];
    message.messageSeq = 1;
    message.content = [WKEndToEndEncryptHitContent new];
    NSNumber *contentType = [[message.content class] contentType];
    message.contentType = contentType.integerValue;
    return [[WKMessageModel alloc] initWithMessage:message];
}
- (WKMessageList *)messageList {
    if(!_messageList) {
        _messageList = [[WKMessageList alloc] init];
    }
    return _messageList;
}



#pragma mark -- WKMessageListDataProvider

- (void)clearMessages {
    [self.messageList clearMessages];
}

-(NSIndexPath*) replaceMessage:(WKMessageModel*)newMessage atClientMsgNo:(NSString*)clientMsgNo {
    
    return [self.messageList replaceMessage:newMessage atClientMsgNo:clientMsgNo];
}
- (NSArray<NSString *> *)dates {
    return self.messageList.dates;
}

- (NSArray<WKMessageModel *> *)messagesAtDate:(NSString *)date {
    return [self.messageList messagesAtDate:date];
}

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType {
    return [self.messageList getMessagesWithContentType:contentType];
}

- (NSArray<WKMessageModel *> *)getSelectedMessages {
    return [self.messageList getSelectedMessages];
}

- (void)cancelSelectedMessages {
    [self.messageList cancelSelectedMessages];
}

-(void) addMessage:(WKMessageModel*)message {
    [self.messageList addMessage:message];
}
// 上拉加载
-(void) pullup:(void(^)(bool more))complete  {
    WKMessageModel *lastMessageModel = [self lastMessage];
//    WKMessageModel *firstMessageModel = [self firstMessageModel];
    uint32_t baseOrderSeq = 0;
    if(lastMessageModel) {
        if(lastMessageModel.contentType == WK_TYPING) {
            if(lastMessageModel.preMessageModel) {
                baseOrderSeq = lastMessageModel.preMessageModel.orderSeq;
            }
        }else{
            baseOrderSeq = lastMessageModel.orderSeq;
        }
        
    }
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].chatManager pullUp:self.channel startOrderSeq:baseOrderSeq limit:[WKApp shared].config.eachPageMsgLimit complete:^(NSArray<WKMessage *> * _Nonnull messages, NSError * _Nonnull error) {
        [weakSelf handleMessages:[self messagesToMessageModels:messages] insertFirst:false complete:complete];
    }];
}

// 下拉加载
-(void) pulldown:(void(^)(bool more))complete {
    WKMessageModel *firstMessageModel = [self firstMessage];
    uint32_t baseOrderSeq = 0;
    if(firstMessageModel) {
        baseOrderSeq = firstMessageModel.orderSeq;
    }
    __weak typeof(self) weakSelf = self;
    [self pullDownRecursive:baseOrderSeq accumulated:[NSMutableArray array] existingIds:[NSMutableSet set] complete:complete];
}

/// 递归加载历史消息：空间过滤后不足一页时自动继续往前拉取，确保历史完整
-(void) pullDownRecursive:(uint32_t)startOrderSeq accumulated:(NSMutableArray<WKMessageModel*>*)accumulated existingIds:(NSMutableSet*)existingIds complete:(void(^)(bool more))complete {
    NSInteger pageLimit = [WKApp shared].config.eachPageMsgLimit;
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].chatManager pullDown:self.channel startOrderSeq:startOrderSeq limit:(int)pageLimit complete:^(NSArray<WKMessage *> * _Nonnull messages, NSError * _Nonnull error) {
        if (error || !messages || messages.count == 0) {
            if (accumulated.count > 0) {
                [weakSelf handleMessages:accumulated insertFirst:YES complete:complete];
            } else if (complete) {
                complete(NO);
            }
            return;
        }

        NSArray<WKMessageModel*> *models = [weakSelf messagesToMessageModels:messages];
        for (WKMessageModel *model in models) {
            if (![existingIds containsObject:model.clientMsgNo]) {
                [existingIds addObject:model.clientMsgNo];
                [accumulated addObject:model];
            }
        }

        BOOL rawHasMore = messages.count >= pageLimit;

        if ([weakSelf needsSpaceFiltering] && accumulated.count < pageLimit && rawHasMore) {
            WKMessage *oldestMsg = messages.lastObject;
            uint32_t nextSeq = oldestMsg.orderSeq;
            if (nextSeq > 0) {
                [weakSelf pullDownRecursive:nextSeq accumulated:accumulated existingIds:existingIds complete:complete];
                return;
            }
        }

        [weakSelf handleMessages:accumulated insertFirst:YES complete:complete];
    }];
}


-(NSInteger) messageCount {
    
    return [self.messageList messageCount];
}

- (BOOL)hasTyping {
    return [self.messageList hasTyping];
}

- (NSIndexPath *)replaceTyping:(WKMessageModel *)message {
    return [self.messageList replaceTyping:message];
}


-(void) addTypingMessageIfNeed:(WKMessageModel*)messageModel {
    [self.messageList addTypingMessageIfNeed:messageModel];
}
-(NSIndexPath*) removeMessage:(WKMessageModel*) message {
    
    return [self.messageList removeMessage:message];
}

- (NSIndexPath *)removeMessage:(WKMessageModel *)message sectionRemove:(BOOL *)sectionRemove {
    return [self.messageList removeMessage:message sectionRemove:sectionRemove];
}

-(NSIndexPath*) indexPathAtMessageID:(uint64_t)messageID {
    return [self.messageList indexPathAtMessageID:messageID];
}

-(NSIndexPath*) indexPathAtStreamNo:(NSString*)streamNo {
    return [self.messageList indexPathAtStreamNo:streamNo];
}

-(NSArray<NSIndexPath*>*) indexPathAtMessageReply:(uint64_t)messageID {
    return [self.messageList indexPathAtMessageReply:messageID];
}

-(NSArray<WKMessageModel*>*) messagesAtMessageReply:(uint64_t)messageID {
    return [self.messageList messagesAtMessageReply:messageID];
}

-(NSIndexPath*) indexPathAtClientMsgNo:(NSString*) clientMsgNo {
    return [self.messageList indexPathAtClientMsgNo:clientMsgNo];
}

-(void) insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath {
    [self.messageList insertMessage:message atIndex:indexPath];
}
- (WKMessageModel *)lastMessage {
    return [self.messageList lastMessage];
}

- (WKMessageModel *)firstMessage {
    return [self.messageList firstMessage];
}

-(NSIndexPath*) indexPathAtOrderSeq:(uint32_t)orderSeq {
    return [self.messageList indexPathAtOrderSeq:orderSeq];
}

- (NSInteger)dateCount {
    return self.messageList.dates.count;
}

- (NSString *)dateWithSection:(NSInteger)section {
    return self.messageList.dates[section];
}

- (void)didReaded:(NSArray<WKMessageModel *> *)messageModels {
    if(![WKSDK shared].receiptManager.messageReadedProvider) {
        return;
    }
    NSMutableArray<WKMessage*> *messages = [NSMutableArray array];
    for (WKMessageModel *messageModel in messageModels) {
        [messages addObject:messageModel.message];
    }
    [[WKSDK shared].receiptManager addReceiptMessages:self.channel messages:messages];
}

- (WKMessageModel *)messageAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section >= (NSInteger)self.messageList.dates.count) return nil;
    NSString *date = self.messageList.dates[indexPath.section];
    NSArray *messages = [self.messageList messagesAtDate:date];
    if (indexPath.row >= (NSInteger)messages.count) return nil;
    return messages[indexPath.row];
}

-(WKMessageModel* __nullable) messageAtClientMsgNo:(NSString*)clientMsgNo {
   NSIndexPath *indexPath = [self indexPathAtClientMsgNo:clientMsgNo];
    if(!indexPath) {
        return nil;
    }
    return [self messageAtIndexPath:indexPath];
}

-(WKMessageModel*__nullable) messageAtStreamNo:(NSString*)streamNo {
    NSIndexPath *indexPath = [self indexPathAtStreamNo:streamNo];
     if(!indexPath) {
         return nil;
     }
    return [self messageAtIndexPath:indexPath];
}

- (NSArray<WKMessageModel *> *)messagesAtSection:(NSInteger)section {
    NSString *date = self.messageList.dates[section];
    return [self.messageList messagesAtDate:date];
}


@end
