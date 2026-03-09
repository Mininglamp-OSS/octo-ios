//
//  WKChatManager.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import "WKChatManager.h"
#import "WKMessageDB.h"
#import "WKConst.h"
#import "WKSendPacket.h"
#import "WKSDK.h"
#import "WKUnknownContent.h"
#import "WKRecvackPacket.h"
#import "WKMessageStatusModel.h"
#import "WKRetryManager.h"
#import "WKSystemContent.h"
#import "WKMediaProto.h"
#import "WKMultiMediaMessageContent.h"
#import "WKMediaManager.h"
#import "WKConversationDB.h"
#import "WKConversationUtil.h"
#import "WKUUIDUtil.h"
#import "WKMOSContentConvertManager.h"
#import "WKMediaUtil.h"
#import "WKConversationManager.h"
#import "WKSignalErrorContent.h"
#import "WKReactionDB.h"
#import "WKMessageExtraDB.h"
#import "WKConversationManagerInner.h"
#import "WKConversationLastMessageAndUnreadCount.h"
#import "WKMessageQueueManager.h"

@interface WKChatManager ()

/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;
// 重试消息字典
@property(nonatomic,strong) NSMutableDictionary *retryMessageDict;

@property(nonatomic,strong) dispatch_queue_t ackQueue; // ack任务队列

@property(nonatomic,strong) dispatch_queue_t handleMessageQueue; // 处理消息的队列

@property(nonatomic,strong) dispatch_queue_t sendMessageQueue; // ack任务队列

@property(nonatomic,strong) NSMutableDictionary *interceptDict; // 拦截器字典
@end

@implementation WKChatManager

-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel {
    
    return [self sendMessage:content channel:channel setting:nil];
}

-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel topic:(NSString*)topic{
    
    return [self sendMessage:content channel:channel setting:nil clientMsgNo:nil topic:topic];
}

-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel setting:(WKSetting*)setting {
    return [self sendMessage:content channel:channel setting:setting clientMsgNo:nil topic:nil];
}

-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel setting:(WKSetting*)setting  topic:(NSString*)topic {
    return [self sendMessage:content channel:channel setting:setting clientMsgNo:nil topic:topic];
}

-(WKMessage*) sendMessage:(WKMessageContent*)content channel:(WKChannel*)channel setting:(WKSetting*)setting clientMsgNo:(NSString*)clientMsgNo topic:(NSString*)topic{
    WKMessageStatus messageStatus = WK_MESSAGE_WAITSEND;
    if([self isMediaMessage:content]) { // 如果是多媒体消息，消息不触发重试功能，等多媒体上传完毕后，再将消息改为待发送然后发送出去
        messageStatus = WK_MESSAGE_UPLOADING;
    }
    // 保存消息
    WKMessage *message = [self saveMessage:content channel:channel fromUid:nil status:messageStatus setting:setting clientMsgNo:clientMsgNo topic:topic];
    
    if(![self isMediaMessage:content]) { // 不是多媒体消息直接发送
        // 发送消息
        return [self sendMessage:message];
    }
    // 多媒体消息先上传多媒体
    [[WKMediaManager shared] upload:message];
    return message;
}

-(WKMessage*) resendMessage:(WKMessage*)message {
    [[WKMessageDB shared] destoryMessage:message];
    return  [self sendMessage:message.content channel:message.channel setting:message.setting clientMsgNo:message.clientMsgNo topic:message.topic];
}


-(WKMessage*) saveMessage:(WKMessageContent*)content channel:(WKChannel*)channel {
    
    return [self saveMessage:content channel:channel fromUid:nil];
}

-(WKMessage*) contentToMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:(NSString*)fromUid clientMsgNo:(NSString*)clientMsgNo{
    WKMessage *message = [[WKMessage alloc] init];
    WKMessageHeader *header = [[WKMessageHeader alloc] init];
    header.showUnread = true;
    message.header = header;
    if(clientMsgNo && ![clientMsgNo isEqualToString:@""]) {
        message.clientMsgNo = clientMsgNo;
    }else{
        message.clientMsgNo = [WKUUIDUtil getClientMsgNo:WKSDK.shared.options.clientMsgDeviceId];
    }
    
    
    message.timestamp = [[NSDate date] timeIntervalSince1970];
    if(fromUid && ![fromUid isEqualToString:@""]) {
        message.fromUid =fromUid;
    }else {
        message.fromUid = [WKSDK shared].options.connectInfo.uid;
    }
    
    if(channel.channelType == WK_PERSON) {
        message.toUid = channel.channelId;
    }
    
    // 设置用户
    if([WKSDK shared].options.enableMessageAttachUserInfo && (message.fromUid&&[message.fromUid isEqualToString:[WKSDK shared].options.connectInfo.uid])) { // 是否携带发送者的用户信息
        WKConnectInfo *connectInfo =  [WKSDK shared].options.connectInfo;
        if(connectInfo) {
            content.senderUserInfo = [[WKUserInfo alloc] initWithUid:connectInfo.uid name:connectInfo.name avatar:connectInfo.avatar];
        }
    }
    message.channel = channel;
    message.contentType = content.realContentType;
    message.content = content;
    message.contentData = [content encode];
    
    if(message.isSend && [message.content viewedOfVisible]) {
        message.viewed = 1;
        message.viewedAt = message.timestamp;
    }
    
    return message;
}

-(WKMessage*) contentToMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:(NSString*)fromUid {
    
    return [self contentToMessage:content channel:channel fromUid:fromUid clientMsgNo:nil];
    
}

-(WKMessage*) saveMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:(NSString*)fromUid  status:(WKMessageStatus)status {
    
    return [self saveMessage:content channel:channel fromUid:fromUid status:status setting:nil clientMsgNo:nil topic:nil];
}

-(WKMessage*) saveMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:(NSString*)fromUid  status:(WKMessageStatus)status setting:(WKSetting*)setting {
    return [self saveMessage:content channel:channel fromUid:fromUid status:status setting:setting clientMsgNo:nil topic:nil];
}

-(WKMessage*) saveMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:(NSString*)fromUid  status:(WKMessageStatus)status setting:(WKSetting*)setting clientMsgNo:(NSString*)clientMsgNo topic:(NSString*)topic{
    
    WKMessage *message = [self contentToMessage:content channel:channel fromUid:fromUid clientMsgNo:clientMsgNo];
    message.status = status;
    if(setting) {
        message.setting = setting;
        message.expire = setting.expire;
        if(setting.expire>0) {
           message.expireAt = [[NSDate date] dateByAddingTimeInterval:setting.expire];
        }
    }
    if(topic && ![topic isEqualToString:@""]) {
        message.topic = topic;
    }
    [self saveMessages:@[message]];
    return message;
}

-(WKMessage*) saveMessage:(WKMessageContent*)content channel:(WKChannel*)channel fromUid:(NSString*)fromUid {
    return [self saveMessage:content channel:channel fromUid:fromUid status:WK_MESSAGE_WAITSEND];
    
}

// 调用拦截器获得消息是否需要存储
-(BOOL) needStoreOfIntercept:(WKMessage*)message {
    BOOL store = true;
    NSArray<MessageStoreBeforeIntercept> *intercepts = [self getMessageStoreBeforeIntercepts];
    if(intercepts && intercepts.count>0) {
        for (MessageStoreBeforeIntercept intercept in intercepts) {
            store = intercept(message);
            if(!store) {
                break;
            }
            
        }
    }
    return store;
}

-(NSArray<WKMessage*>*) saveMessages:(NSArray<WKMessage*>*)messages {
    if(!messages || messages.count<=0) {
        return nil;
    }
    for (WKMessage *message in messages) {
        message.isDeleted = ![self needStoreOfIntercept:message];
    }
    // 保存消息
    NSArray<WKMessage*> *newMessages = [[WKMessageDB shared] saveMessages:messages];
    // 更新最近会话
    [self addOrUpdateConversationWithMessages:newMessages];
    
    return newMessages;
}

-(void) addOrUpdateMessages:(NSArray<WKMessage*>*)messages  {
    if(!messages || messages.count<=0) {
        return;
    }
    for (WKMessage *message in messages) {
        message.isDeleted = ![self needStoreOfIntercept:message];
    }
    [WKMessageDB.shared replaceMessages:messages];
    // 更新最近会话
    [self addOrUpdateConversationWithMessages:messages];
}

-(void) addOrUpdateMessages:(NSArray<WKMessage*>*)messages notify:(BOOL)notify {
    if(!messages || messages.count<=0) {
        return;
    }
    for (WKMessage *message in messages) {
        message.isDeleted = ![self needStoreOfIntercept:message];
    }
    [WKMessageDB.shared replaceMessages:messages];
    
    if(notify) {
        for(WKMessage *message in messages) {
            [self callMessageUpdateDelegate:message];
        }
    }
   
}

-(WKConversation*) toConversationWtihMessage:(WKMessage*)message {
    WKConversation *conversation = [WKConversation new];
    conversation.channel = message.channel;
    conversation.lastMessageSeq = message.messageSeq;
    conversation.lastClientMsgNo = message.clientMsgNo;
    conversation.lastMessage = message;
    conversation.lastMsgTimestamp = [message timestamp];
    
    if(message.channel.channelType == WK_COMMUNITY_TOPIC) {
        NSArray<NSString*> *parentChannels =  [message.channel.channelId componentsSeparatedByString:@"@"];
        if(parentChannels && parentChannels.count>0) {
            NSString *parentChannelID = parentChannels[0];
            if(parentChannelID && ![parentChannelID isEqualToString:@""]) {
                conversation.parentChannel = [WKChannel channelID:parentChannelID channelType:WK_COMMUNITY];
            }
        }
    }
    //    conversation.content = [message.content conversationDigest];
    
    return conversation;
}



// 是否是多媒体消息
-(BOOL) isMediaMessage:(WKMessageContent*) messageContent {
    if([messageContent conformsToProtocol:@protocol(WKMediaProto)] || [messageContent isKindOfClass:[WKMultiMediaMessageContent class]]) {
        return true;
    }
    return false;
}

-(WKMessage*) sendMessage:(WKMessage*)message {
    return [self sendMessage:message addRetryQueue:true];
}



-(WKMessage*) sendMessage:(WKMessage*)message addRetryQueue:(BOOL)addRetryQueue{
    
        if(addRetryQueue) {
            // 添加到重试队列
            [[WKRetryManager shared] add:message];
        }
        [WKMessageQueueManager.shared sendMessage:message];
    
//    dispatch_async(self.sendMessageQueue,^{
//        // 发送消息
//        WKSendPacket *sendPacket = [WKSendPacket new];
//        sendPacket.header.showUnread = message.header?message.header.showUnread:0;
//        sendPacket.header.noPersist = message.header?message.header.noPersist:0;
//        WKSetting *setting = message.setting;
//        if(message.topic && ![message.topic isEqualToString:@""]) {
//            setting.topic = true;
//        }
//        sendPacket.setting = setting;
//        sendPacket.clientSeq = message.clientSeq;
//        sendPacket.clientMsgNo = message.clientMsgNo;
//        sendPacket.channelId = message.channel.channelId;
//        sendPacket.channelType = message.channel.channelType;
//        sendPacket.expire = message.expire;
//        sendPacket.topic = message.topic;
//        sendPacket.payload = message.content.encode;
//
//        if(addRetryQueue) {
//            // 添加到重试队列
//            [[WKRetryManager shared] add:message];
//        }
//        [[[WKSDK shared] connectionManager] sendPacket:sendPacket];
//
//    });
    
    
    
    return message;
}


-(WKMessage*) forwardMessage:(WKMessageContent*)content channel:(WKChannel*)channel {
    WKMessageStatus messageStatus = WK_MESSAGE_WAITSEND;
    //    // 保存消息
    WKMessage *message = [self saveMessage:content channel:channel fromUid:nil status:messageStatus];
    //    // 发送消息
    return [self sendMessage:message];
}

-(WKMessage*) editMessage:(WKMessage*)message newContent:(WKMessageContent*)newContent{
    if(!self.messageEditProvider) {
        @throw [NSException exceptionWithName:@"提供者" reason:@"没有设置messageEditProvider提供者" userInfo:nil];
    }
    WKMessageExtra *messageExtra = [[WKMessageExtra alloc] init];
    messageExtra.messageID = message.messageId;
    messageExtra.messageSeq = message.messageSeq;
    messageExtra.channelID = message.channel.channelId;
    messageExtra.channelType = message.channel.channelType;
    messageExtra.contentEdit = newContent;
    messageExtra.contentEditData = [newContent encode];
    messageExtra.editedAt = [[NSDate date] timeIntervalSince1970];
    messageExtra.uploadStatus = WKContentEditUploadStatusWait;
    [[WKMessageExtraDB shared] addOrUpdateContentEdit:messageExtra];
    
    WKMessage *newMessage =  [[WKMessageDB shared] getMessageWithMessageId:message.messageId];
    if(newMessage) {
        [self callMessageUpdateDelegate:newMessage];
    }
    
    
    [[WKRetryManager shared] addMessageExtra:messageExtra];
    
    __weak typeof(self) weakSelf = self;
    self.messageEditProvider(messageExtra, ^(NSError * _Nullable error) {
        NSString *key = [NSString stringWithFormat:@"%llu",messageExtra.messageID];
        [[WKRetryManager shared] removeMessageExtraRetryItem:key];
        if(!error) {
            [[WKMessageExtraDB shared] updateUploadStatus:WKContentEditUploadStatusSuccess withMessageID:messageExtra.messageID];
        }else {
            [[WKMessageExtraDB shared] updateUploadStatus:WKContentEditUploadStatusError withMessageID:messageExtra.messageID];
        }
        WKMessage *newMessage =  [[WKMessageDB shared] getMessageWithMessageId:messageExtra.messageID];
        if(newMessage) {
            [weakSelf callMessageUpdateDelegate:newMessage];
        }
    });
    
    return newMessage;
}

-(void) deleteMessage:(WKMessage*)message {
    [[WKMessageDB shared] deleteMessage:message];
    //  调用委托通知上层
    [self callMessageDeletedDelegate:message];
    WKConversation *conversation =  [[WKConversationDB shared] getConversationWithLastClientMsgNo:message.clientMsgNo];
    if(conversation) {
        conversation.reminders =  [[WKReminderDB shared] getWaitDoneReminder:conversation.channel];
        WKMessage *lastMessage = [[WKMessageDB shared] getLastMessage:conversation.channel];
        // 重置最近会话最后一条消息
        [self resetConversationLastMessage:conversation message:lastMessage];
    }else {
        conversation = [[WKSDK shared].conversationManager getConversation:message.channel];
        if(conversation) {
            NSInteger old = conversation.unreadCount;
            [self calConversationUnread:conversation message:message];
            if(old!=conversation.unreadCount) {
                [[WKConversationDB shared] updateConversation:conversation];
                [[WKSDK shared].conversationManager callOnConversationUpdateDelegate:conversation];
            }
            
        }
    }
}

-(void) deleteMessage:(NSString*)fromUID channel:(WKChannel*)channel {
    NSArray *messages = [[WKMessageDB shared] getMessages:fromUID channel:channel];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            [self deleteMessage:message];
        }
    }
}

- (void)clearMessages:(WKChannel *)channel {
    [[WKMessageDB shared] clearMessages:channel];
    // 移除频道的目录
    [[NSFileManager defaultManager] removeItemAtPath:[WKMediaUtil getChannelDir:channel] error:nil];
    //  调用委托通知上层
    [self callMessagClearedDelegate:channel];
    
    // 更新最近会话数据
    WKConversation *conversation = [[WKConversationDB shared] getConversation:channel];
    if(conversation) {
        [self resetConversationLastMessage:conversation message:nil];
    }
}

-(void) clearAllMessages {
    // 清除所有消息
    [[WKMessageDB shared] clearAllMessages];
    // 清除所有最近会话
    [[WKConversationDB shared] deleteAllConversation];
    NSString *userMessageHomeDir = [NSString stringWithFormat:@"%@/%@",[WKSDK shared].options.messageFileRootDir,[WKSDK shared].options.connectInfo.uid];
    [[NSFileManager defaultManager] removeItemAtPath:userMessageHomeDir error:nil];
    // 调用清空所有最近会话通知
    [[WKSDK shared].conversationManager callOnConversationAllDeleteDelegate];
}

- (void) clearFromMsgSeq:(WKChannel*)channel maxMsgSeq:(uint32_t)maxMsgSeq isContain:(BOOL)isContain {
    [WKMessageDB.shared clearFromMsgSeq:channel maxMsgSeq:maxMsgSeq isContain:isContain];
    
    NSArray<WKMessage*> *updateMessages = [WKMessageDB.shared getDeletedMessagesWithChannel:channel minMessageSeq:0 maxMessageSeq:maxMsgSeq+1];
    
    for (NSInteger i=0; i<updateMessages.count; i++) {
        WKMessage *message = updateMessages[i];
        [self callMessageDeletedDelegate:message];
    }
    
    // 更新最近会话数据
    WKConversation *conversation = [[WKConversationDB shared] getConversation:channel];
    if(conversation) {
        WKMessage *lastMsg = [WKMessageDB.shared getLastMessage:channel];
        [self resetConversationLastMessage:conversation message:lastMsg];
        
    }
}

-(void) calConversationUnread:(WKConversation*)conversation message:(WKMessage*)message {
    if(conversation.unreadCount>0 && message) { // 如果未读数大于0 则需要判断被删除的消息是否在红点内
        NSInteger moreThanCount = [[WKMessageDB shared] getOrderCountMoreThanMessage:message]; // 查询比此消息更新的消息数量
        if(conversation.unreadCount>=moreThanCount) {
            conversation.unreadCount--;
        }
    }
}
// 清除会话最后一条消息信息
-(void) resetConversationLastMessage:(WKConversation*)conversation message:(WKMessage*)message{
    conversation.lastClientMsgNo = @"";
    [self calConversationUnread:conversation message:message];
    if(message) {
        conversation.lastClientMsgNo = message.clientMsgNo;
        conversation.lastMessageSeq = message.messageSeq;
        conversation.lastMsgTimestamp = message.timestamp;
    }
    
    [[WKConversationDB shared] updateConversation:conversation];
    [[WKSDK shared].conversationManager callOnConversationUpdateDelegate:conversation];
}

-(void) handleSendack:(NSArray<WKSendackPacket*> *)sendackArray {
    if(!sendackArray) {
        return;
    }
    [[WKMessageDB shared] updateMessageWithSendackPackets:sendackArray];
    
    NSMutableArray *clientIDs = [NSMutableArray array];
    for (WKSendackPacket *sendackPacket in sendackArray) {
        NSString *key = [NSString stringWithFormat:@"%u",sendackPacket.clientSeq];
        
        if(!sendackPacket.header.noPersist) {
            [clientIDs addObject:@(sendackPacket.clientSeq)];
        }
        
        [[WKRetryManager shared] removeRetryItem:key]; // 移除重试任务
    }
    
    // 调用委托
    if(clientIDs.count>0) {
        NSArray<WKMessage*> *messages = [[WKMessageDB shared] getMessagesWithClientSeqs:clientIDs];
        if(messages && messages.count>0) {
            for (NSInteger i=0; i<messages.count; i++) {
                WKMessage *message = messages[i];
                [self callMessageUpdateDelegate:message left:messages.count-1-i total:messages.count];
            }
            [self addOrUpdateConversationWithMessages:messages];
        }
    }
    for (NSInteger i=0; i<sendackArray.count; i++) {
        [self callSendackDelegate:sendackArray[i] left:sendackArray.count-(i+1)];
    }
}

- (dispatch_queue_t)ackQueue {
    if(!_ackQueue) {
        _ackQueue =dispatch_queue_create("ack", DISPATCH_QUEUE_SERIAL);
    }
    return _ackQueue;
}

- (dispatch_queue_t)handleMessageQueue {
    if(!_handleMessageQueue) {
        _handleMessageQueue =dispatch_queue_create("im.wukongim.handleMessageQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _handleMessageQueue;
}

- (dispatch_queue_t)sendMessageQueue {
    if(!_sendMessageQueue) {
        _sendMessageQueue = dispatch_queue_create("im.wukongim.sendMessage", DISPATCH_QUEUE_CONCURRENT);
    }
    return _sendMessageQueue;
}

-(void) handleRecv:(NSArray<WKRecvPacket*>*) packets {
    NSArray<WKMessage*> *messages = [self recvPacketsToMessages:packets];
    
    [self handleMessages:messages];
    
    
    dispatch_async(self.ackQueue, ^{
        // 回ack
        for (WKMessage *message in messages) {
            WKRecvackPacket *recvackPacket = [WKRecvackPacket new];
            recvackPacket.header.noPersist = message.header.noPersist;
            recvackPacket.header.syncOnce = message.header.syncOnce;
            recvackPacket.header.showUnread = message.header.showUnread;
            recvackPacket.messageId = message.messageId;
            recvackPacket.messageSeq = message.messageSeq;
            [[WKSDK shared].connectionManager sendPacket:recvackPacket];
        }
    });
    
}



-(void) handleMessages:(NSArray<WKMessage*>*) messages {
    
    // 存储消息
    [self saveMessages:[self filterNeedStoreMessages:messages]];
    
    // 流消息
    NSArray<WKMessage*> *streamMessages =  [self filterStreamMessagesWithStreamFlagIng:messages];
    NSArray<WKStream*> *streams;
    if(streamMessages && streamMessages.count>0) {
        streams = [self getStreams:streamMessages];
        // 保存流式消息
        NSMutableArray<WKStream*> *needStoreStreams = [NSMutableArray array]; // 需要存储的流
        for (WKMessage *m in streamMessages) {
            if(!m.header.noPersist && !m.header.syncOnce) {
                [needStoreStreams addObject:[self toStream:m]];
            }
        }
        [WKMessageDB.shared saveOrUpdateStreams:needStoreStreams];
    }
    
    // cmd消息
    NSArray<WKCMDModel*> *cmds = [self getCMDModels:messages]; // 获取命令消息
    if(cmds && cmds.count>0) {
       NSArray<WKCMDMessage*> *cmdMessages = [self getCMDMessages:messages];
        if(cmdMessages.count>0) {
            [WKCMDDB.shared replaceCMDMessages:cmdMessages];
        }
    }
    
    NSArray<WKMessage*> *commonMessages  = [self filterNoCMDAndNoStreamMessages:messages]; // 非cmd消息和流消息
    
    // 调用委托通知上层 不管存不存的消息都需要通知到delegate
    [self callRecvMessagesDelegate:commonMessages];
    
    if(cmds&&cmds.count>0) { // cmd通知
        for (WKCMDModel *cmd in cmds) {
            [[WKSDK shared].cmdManager callOnCMDDelegate:cmd];
        }
    }
    if(streams && streams.count>0) {
        [self callStreamDelegate:streams];
    }
    
}

-(NSArray<WKStream*>*) getStreams:(NSArray<WKMessage*>*) messages {
    NSMutableArray<WKStream*> *streams = [NSMutableArray array];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            WKStream *stream = [self toStream:message];
            [streams addObject:stream];
        }
    }
    return streams;
}

-(WKStream*) toStream:(WKMessage*)msg {
    WKStream *stream = [WKStream new];
    stream.channel = msg.channel;
    stream.clientMsgNo = msg.clientMsgNo;
    stream.streamNo = msg.streamNo;
    stream.streamSeq = msg.streamSeq;
    stream.content = msg.content;
    stream.contentData = msg.contentData;
    return stream;
}

-(NSArray<WKCMDModel*>*) getCMDModels:(NSArray<WKMessage*>*)messages {
    
    NSMutableArray *cmds = [NSMutableArray array];
    if(messages && messages.count) {
        for (WKMessage *message in messages) {
            if(message.contentType == WK_CMD) {
                WKCMDModel *cmdModel = [WKCMDModel message:message];
                [cmds addObject:cmdModel];
            }
        }
    }
    return cmds;
}

-(NSArray<WKCMDMessage*>*) getCMDMessages:(NSArray<WKMessage*>*)messages {
    NSMutableArray *cmds = [NSMutableArray array];
    if(messages && messages.count) {
        for (WKMessage *message in messages) {
            if(message.contentType == WK_CMD) {
                [cmds addObject:[WKCMDMessage fromMessage:message]];
            }
        }
    }
    return cmds;
}

// 排除掉非命令消息和流消息
-(NSArray<WKMessage*>*) filterNoCMDAndNoStreamMessages:(NSArray<WKMessage*>*)messages {
    NSMutableArray *newMessages = [NSMutableArray array];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            if(message.contentType != WK_CMD) {
                if(!message.setting.streamOn ||  (message.setting.streamOn && message.streamFlag == WKStreamFlagStart)) {
                    [newMessages addObject:message];
                }
               
            }
        }
    }
    return newMessages;
}

// 获取需要存储的消息
-(NSArray*) filterNeedStoreMessages:(NSArray*)messages {
    NSMutableArray *items = [NSMutableArray array];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            if(message.header && !message.header.noPersist && message.contentType != WK_CMD) {
                if(!message.setting.streamOn || (message.setting.streamOn && message.streamFlag == WKStreamFlagStart)) {
                    [items addObject:message];
                }
            }
        }
    }
    return items;
}

// 获取进行中的流消息
-(NSArray*) filterStreamMessagesWithStreamFlagIng:(NSArray*)messages {
    NSMutableArray *items = [NSMutableArray array];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            if(message.setting.streamOn && message.streamFlag == WKStreamFlagIng) {
                [items addObject:message];
            }
        }
    }
    return items;
}


-(void)addOrUpdateConversationWithMessages:(NSArray<WKMessage*>*)messages {
    // 过滤掉系统消息，只有会话消息才更新最近会话
    NSArray<WKConversationLastMessageAndUnreadCount*> *chatMessageUnreadModels =[self allChannelLastMessage: [self removeNoChannelMessages:messages]];
    if(chatMessageUnreadModels && chatMessageUnreadModels.count>0) {
        NSMutableArray *conversations = [NSMutableArray array];
        for (WKConversationLastMessageAndUnreadCount *lastMessageUnreadModel in chatMessageUnreadModels) {
            WKConversation *conversation =  [self addOrUpdateConversationWithMessage:lastMessageUnreadModel.lastMessage unreadCount:lastMessageUnreadModel.incUnreadCount];
            [conversations addObject:conversation];
            
        }
        if(conversations.count>0) {
            [[WKSDK shared].conversationManager callOnConversationUpdateDelegates:conversations];
        }
    }
}

-(WKConversation*) addOrUpdateConversationWithMessage:(WKMessage*)message  unreadCount:(NSInteger)unreadCount{
    // 更新或添加最近会话
    WKConversation *conversation = [self toConversationWtihMessage:message];
    
    //    [conversation.reminderManager mergeReminders:reminders];
    WKConversationAddOrUpdateResult *result = [[[WKSDK shared] conversationManager] addOrUpdateConversation:conversation incUnreadCount:unreadCount];
    NSArray<WKReminder*> *reminders = [[WKReminderDB shared] getWaitDoneReminder:conversation.channel];
    result.conversation.reminders = reminders;
    return result.conversation;
}

// 获取所有频道最新的一条消息
-(NSArray<WKConversationLastMessageAndUnreadCount*>*) allChannelLastMessage:(NSArray<WKMessage*>*) messages{
    if(!messages) {
        return nil;
    }
    if(messages.count==1) { // 一条消息的情况还算比较多的 这里拿出来单独处理
        return @[ [self makeConversationLastMessageAndUnreadCount:messages[0] channelLastMessageDict:nil]];
    }
    NSMutableDictionary *channelLastMessageDict = [[NSMutableDictionary alloc] init];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            if(message.isDeleted == 0) {
                [self makeConversationLastMessageAndUnreadCount:message channelLastMessageDict:channelLastMessageDict];
            }
        }
    }
    return channelLastMessageDict.allValues;
}

-(WKConversationLastMessageAndUnreadCount*) makeConversationLastMessageAndUnreadCount:(WKMessage*)message channelLastMessageDict:(NSMutableDictionary*)channelLastMessageDict{
    WKConversationLastMessageAndUnreadCount *lastMessageUnreadModel;
    if(channelLastMessageDict) {
        lastMessageUnreadModel = channelLastMessageDict[message.channel];
    }
    if(!lastMessageUnreadModel) {
        lastMessageUnreadModel = [WKConversationLastMessageAndUnreadCount new];
        lastMessageUnreadModel.lastMessage = message;
        if(message.header.showUnread && ![message isSend]) {
            lastMessageUnreadModel.incUnreadCount = 1;
        }
        channelLastMessageDict[message.channel] = lastMessageUnreadModel;
    }else if(lastMessageUnreadModel.lastMessage.messageSeq <= message.messageSeq) {
        lastMessageUnreadModel.lastMessage = message;
        if(message.header.showUnread && ![message isSend]) {
            lastMessageUnreadModel.incUnreadCount += 1;
        }
    }else {
        if(message.header.showUnread && ![message isSend]) {
            lastMessageUnreadModel.incUnreadCount += 1;
        }
    }
    //    if(!message.isSend && message.header.showUnread && message.content.mentionedInfo && message.content.mentionedInfo.isMentionedMe) { // 是否是@我
    //        [lastMessageUnreadModel.reminderManager appendReminder:[WKReminder initWithType:WKReminderTypeMentionMe text:@"[有人@我]" data:@{}]];
    //    }
    return lastMessageUnreadModel;
}

// 移除非频道消息的消息
-(NSArray<WKMessage*>*) removeNoChannelMessages:(NSArray<WKMessage*>*)messages {
    NSMutableArray<WKMessage*> *newMessages = [[NSMutableArray alloc] init];
    if(messages) {
        for (WKMessage *message in messages) {
            if(!message.isDeleted && message.channel && message.channel.channelId && ![message.channel.channelId isEqualToString:@""] && message.channel.channelType!=0 && [self isConversationMessage:message]) {
                [newMessages addObject:message];
            }
        }
    }
    return newMessages;
}

// 是否是会话消息
-(BOOL) isConversationMessage:(WKMessage*)message {
    if( message.contentType == WK_CMD) {
        return false;
    }
    if([message.channel.channelId isEqualToString:@""]) {
        return false;
    }
    return true;
}

-(NSArray*) sortMessages:(NSArray<WKMessage*>*)messages {
    return [messages sortedArrayUsingComparator:^NSComparisonResult(WKMessage * _Nonnull  obj1,  WKMessage * _Nonnull obj2) {
        if(obj1.orderSeq<obj2.orderSeq) {
            return NSOrderedAscending;
        }
        if(obj1.orderSeq == obj2.orderSeq) { // 如果orderSeq相同一般就是messageSeq相同了(特殊情况)，则比较时间
            if(obj1.timestamp < obj2.timestamp) {
                return NSOrderedAscending;
            }else {
                return NSOrderedDescending;
            }
            
        }
        return NSOrderedDescending;
    }];
}


-(void) pullMessages:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq endOrderSeq:(uint32_t)endOrderSeq maxMessageSeq:(uint32_t)maxMessageSeq limit:(int)limit pullMode:(WKPullMode)pullMode   maxExecCount:(NSInteger)maxExecCount complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete {
    if([WKSDK shared].isDebug) {
        NSLog(@"##########拉取频道[%@]消息##########",channel);
    }
    
    if(pullMode == WKPullModeDown && startOrderSeq == 1*WKOrderSeqFactor) { // 1表示消息已经到顶了，肯定没数据了
        [self completePullMessages:nil error:nil complete:complete];
        return;
    }
    
    NSArray<WKMessage*> *messages = [self getLocalMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq  limit:limit pullMode:pullMode];
    
    NSArray<WKMessage*> *newMessages = [NSArray arrayWithArray:messages];
    newMessages = [newMessages sortedArrayUsingComparator:^NSComparisonResult(WKMessage * _Nonnull obj1, WKMessage * _Nonnull obj2) {
        if(obj1.messageSeq<obj2.messageSeq) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    if([WKSDK shared].isDebug) {
        for (WKMessage *newMessage in newMessages) {
            NSLog(@"messageSeq->%u",newMessage.messageSeq);
        }
    }
    if(maxExecCount<=0) {
        if([WKSDK shared].isDebug) {
            NSLog(@"getOrSyncHistoryMessages最大重试次数结束！");
        }
        [self completePullMessages:messages error:nil complete:complete];
        
        return;
    }
    maxExecCount--;
    
    uint32_t realStartMessageSeq = 0;
    uint32_t realEndMessageSeq = 0;


    // ########## 计算当前页与上一页存在的序号差(当前页是查出来的mssages，上一页是startOrderSeq) ##########
    __weak typeof(self) weakSelf = self;
    if(startOrderSeq!=0) {
       
        uint32_t startMessageSeq = 0;
        if(startOrderSeq%WKOrderSeqFactor == 0) { // 一定有messageSeq
            startMessageSeq = startOrderSeq/WKOrderSeqFactor;
        }else{ // 一定没有messageSeq
            WKMessage *startMessage;
            if(pullMode == WKPullModeUp) { // 查询小于startOrderSeq 最近的一条有messageSeq的消息
                startMessage = [[WKMessageDB shared] getMessage:channel lessThanAndFirstMessageSeq:startOrderSeq];
            }else{  // 查询大于baseOrderSeq 最近的一条有messageSeq的消息
                startMessage = [[WKMessageDB shared] getMessage:channel moreThanAndFirstMessageSeq:startOrderSeq];
            }
            if(startMessage) {
                startMessageSeq = startMessage.messageSeq;
            }
        }
        if(startMessageSeq>0) {
            bool needSync = true;
            realStartMessageSeq =startMessageSeq;
            if(pullMode == WKPullModeUp) {
                if(newMessages.count>0) {
                    realEndMessageSeq = newMessages[0].messageSeq;
                    if(realEndMessageSeq!=0 && realEndMessageSeq - realStartMessageSeq == 1) {
                        needSync = false;
                    }
                }
            }else{
                if(newMessages.count>0) {
                   realEndMessageSeq = newMessages[newMessages.count-1].messageSeq;
                    if(realEndMessageSeq !=0 && realStartMessageSeq - realEndMessageSeq == 1) {
                        needSync = false;
                    }
                }
            }
            if(needSync) {
                // 计算和远程同步消息
                bool hasSync = [self calSync:channel startMessageSeq:realStartMessageSeq endMessageSeq:realEndMessageSeq pullMode:pullMode  complete:^(WKSyncChannelMessageModel *model, NSError *error) {
                    if(error) {
                        [self completePullMessages:messages error:error complete:complete];
                        return;
                    }
                    // 存储消息
                    [[WKMessageDB shared] replaceMessages:model.messages];
                    // 重新调用
                    [weakSelf pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:limit pullMode:pullMode  maxExecCount:maxExecCount complete:complete];
                    
                }];
                if(hasSync) {
                    return;
                }
            }
        }
    }
    
    // ########## 计算当前页消息之间是否存在序号差 ##########
    if(newMessages.count>=2) { // 只有大于等于2，才存在消息之间比较的逻辑
        for (NSInteger i=0; i<newMessages.count; i++) {
            WKMessage *currMessage = newMessages[i];
            if(currMessage.messageSeq == 0) {
                continue;
            }
            WKMessage *nextMessage;
            for (NSInteger j=i+1; j<newMessages.count; j++) {
                 nextMessage = newMessages[j];
                if(nextMessage.messageSeq != 0 ){
                    break;
                }
            }
            if(!nextMessage) {
                break;
            }
            if(nextMessage.messageSeq - currMessage.messageSeq == 1) {
                continue;
            }
            
            // 计算和远程同步消息
            bool hasSync = [self calSync:channel startMessageSeq:currMessage.messageSeq endMessageSeq:nextMessage.messageSeq pullMode:WKPullModeUp  complete:^(WKSyncChannelMessageModel *model, NSError *error) {
                if(error) {
                    [weakSelf completePullMessages:messages error:error complete:complete];
                    return;
                }
                if(!model.messages || model.messages.count<=0) {
                    if(WKSDK.shared.isDebug) {
                        NSLog(@"没有消息了！");
                    }
                    [weakSelf completePullMessages:messages error:nil complete:complete];
                    return;
                }
                if([weakSelf containMessages:newMessages compareMessages:model.messages]) {
                    [weakSelf completePullMessages:messages error:nil complete:complete];
                    return;
                }
                // 存储消息
                [[WKMessageDB shared] replaceMessages:model.messages];
                // 重新调用
                [weakSelf pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:limit pullMode:pullMode  maxExecCount:maxExecCount complete:complete];
            }];
            if(hasSync) {
                return;
            }
        }
    }
    
    
    // ########## 计算最后一页后是否还存在消息 ##########
    if(newMessages.count<limit) {
        
        if(newMessages.count == 0 || maxMessageSeq == 0 || newMessages[newMessages.count-1].messageSeq != maxMessageSeq) { // 当查询出来的最大的messageSeq 等于 maxMessageSeq的时候 不需要同步
            realStartMessageSeq = 0;
            if(newMessages.count>0) {
                if(pullMode == WKPullModeUp) {
                    for (NSInteger i=newMessages.count-1; i>=0; i--) {
                        realStartMessageSeq = newMessages[i].messageSeq;
                        if(realStartMessageSeq!=0) {
                            break;
                        }
                    }
                   
                }else {
                    for (NSInteger i=0; i<newMessages.count; i++) {
                        realStartMessageSeq = newMessages[0].messageSeq;
                        if(realStartMessageSeq!=0) {
                            break;
                        }
                    }
                    
                }
            }
            bool hasSync = [self calSync:channel startMessageSeq:realStartMessageSeq endMessageSeq:0 pullMode:pullMode complete:^(WKSyncChannelMessageModel *syncChannelMessageModel, NSError *error) {
                if(error) {
                    [weakSelf completePullMessages:messages error:error complete:complete];
                    return;
                }
                if(!syncChannelMessageModel.messages || syncChannelMessageModel.messages.count<=0) {
                    if(WKSDK.shared.isDebug) {
                        NSLog(@"没有消息了！");
                    }
                    [weakSelf completePullMessages:messages error:nil complete:complete];
                    return;
                }
                if([weakSelf containMessages:newMessages compareMessages:syncChannelMessageModel.messages]) {
                    [weakSelf completePullMessages:messages error:nil complete:complete];
                    return;
                }
                // 存储消息
                [[WKMessageDB shared] replaceMessages:syncChannelMessageModel.messages];
                // 重新调用
                [weakSelf pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:limit pullMode:pullMode  maxExecCount:maxExecCount complete:complete];
            }];
            if(hasSync) {
                return;
            }
        }
        
    }
    
    // ########## 是否为第一次请求 ##########
    if(startOrderSeq == 0 && endOrderSeq == 0) {
        if(newMessages.count == 0 ) {
            // 强制同步
//            int limit =  (int)[WKSDK shared].options.syncChannelMessageLimit;
            [self calSyncForForce:channel startMessageSeq:0 endMessageSeq:0 pullMode:pullMode limit:limit complete:^(WKSyncChannelMessageModel *model, NSError *error) {
                if(error) {
                    [weakSelf completePullMessages:messages error:error complete:complete];
                    return;
                }
                // 存储消息
                [[WKMessageDB shared] replaceMessages:model.messages];
                // 重新调用
                [weakSelf pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:limit pullMode:pullMode  maxExecCount:maxExecCount complete:complete];
            }];
            return;
        }else if(newMessages.count>0 && pullMode == WKPullModeUp) {
//            int limit =  (int)[WKSDK shared].options.syncChannelMessageLimit;
            WKMessage *lastMsg = newMessages.lastObject;
            if(maxMessageSeq == 0 || maxMessageSeq != lastMsg.messageSeq ) {
                [self calSyncForForce:channel startMessageSeq:lastMsg.messageSeq endMessageSeq:0 pullMode:pullMode limit:limit complete:^(WKSyncChannelMessageModel *model, NSError *error) {
                    if(error) {
                        [weakSelf completePullMessages:messages error:error complete:complete];
                        return;
                    }
                    NSMutableArray<WKMessage*> *lastMessages = [NSMutableArray array];
                    if(model.messages && model.messages.count>0) {
                        for (WKMessage *m in model.messages) {
                            if(m.messageSeq > lastMsg.messageSeq) {
                                [lastMessages addObject:m];
                            }
                        }
                        if(lastMessages.count>0) {
                            // 存储消息
                            [[WKMessageDB shared] replaceMessages:lastMessages];
                        }
                    }
                   
                    // 重新调用
                    [weakSelf pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:limit pullMode:pullMode  maxExecCount:maxExecCount complete:complete];
                }];
                return;
            }else if(newMessages.count<limit && newMessages.firstObject.messageSeq !=1) { // 如果查询出来的消息数量不满足limit，并且第一条消息不是1，则去服务器拉取
                WKMessage *firstMsg = newMessages.firstObject;
                [self calSyncForForce:channel startMessageSeq:newMessages.firstObject.messageSeq endMessageSeq:0 pullMode:WKPullModeDown limit:limit complete:^(WKSyncChannelMessageModel *model, NSError *error) {
                    if(error) {
                        [weakSelf completePullMessages:messages error:error complete:complete];
                        return;
                    }
                    NSMutableArray<WKMessage*> *lastMessages = [NSMutableArray array];
                    if(model.messages && model.messages.count>0) {
                        for (WKMessage *m in model.messages) {
                            if(m.messageSeq < firstMsg.messageSeq) {
                                [lastMessages addObject:m];
                            }
                        }
                        if(lastMessages.count>0) {
                            // 存储消息
                            [[WKMessageDB shared] replaceMessages:lastMessages];
                        }
                    }
                   
                    // 重新调用
                    [weakSelf pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:limit pullMode:pullMode  maxExecCount:maxExecCount complete:complete];
                }];
                return;
            }
            
        }
    }
    
    // 如果没有序号差则执行回调
    [self completePullMessages:messages error:nil complete:complete];
}

-(void) getMessages:(WKChannel*)channel aroundOrderSeq:(uint32_t)aroundOrderSeq  limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete {
    uint32_t baseOrderSeq = aroundOrderSeq; // 基准orderSeq（起始ordeqrSeq）
    if (aroundOrderSeq!=0) {
        uint32_t maxMessageSeq = [[WKMessageDB shared] getMaxMessageSeq:channel]; // 获取当前频道最大的messageSeq
        uint32_t aroundMessageSeq = [[WKSDK shared].chatManager getOrNearbyMessageSeq:aroundOrderSeq]; // 获取aroundOrderSeq最接近的messageSeq
        uint32_t baseMessageSeq = aroundMessageSeq;
        if(maxMessageSeq > aroundMessageSeq && maxMessageSeq - aroundMessageSeq<limit) { // 如果消息数量不满足limit，则直接查询第一屏，baseMessageSeq为0
            baseMessageSeq = 0;
        }else { // 如果满足limit数量，则以aroundOrderSeq为基准查询5条的第一条消息messageSeq，比如 aroundOrderSeq=10，getChannelAroundFirstMessageSeq查询到的就是 “9 8 7 6 5 ” 5条中的 5，然后以此messageSeq为baseMessageSeq进行查询
            if(baseMessageSeq>0) {
                baseMessageSeq = [[WKMessageDB shared] getChannelAroundFirstMessageSeq:channel messageSeq:aroundMessageSeq];
            }
        }
        if(baseMessageSeq != 0 ) {
            // 如果最后一条messageSeq与开始messageSeq的差值小于查询数量，则向上偏移指定数量满足limit
            if(maxMessageSeq - baseMessageSeq<limit) {
                if(baseMessageSeq>(limit - (maxMessageSeq - baseMessageSeq))) {
                    baseMessageSeq = baseMessageSeq - (limit - (maxMessageSeq - baseMessageSeq));
                }
               
            }
        }
        baseOrderSeq = [[WKSDK shared].chatManager getOrderSeq:baseMessageSeq];
    }
    [self pullMessages:channel startOrderSeq:baseOrderSeq endOrderSeq:0 limit:limit pullMode:WKPullModeUp complete:complete];
}

-(BOOL) containMessages:(NSArray<WKMessage*>*)messages compareMessages:(NSArray<WKMessage*>*)compareMessages {
    if(!messages || !compareMessages) {
        return  false;
    }
    if(compareMessages.count>messages.count) {
        return false;
    }
    if(messages.count == 0) {
        return false;
    }
    for (WKMessage *compareMessage in compareMessages) {
        BOOL contain = false;
        for (WKMessage *message in messages) {
            if([message.clientMsgNo isEqualToString:compareMessage.clientMsgNo] && compareMessage.messageSeq == message.messageSeq) {
                contain = true;
                break;
            }
        }
        if(!contain) {
            return  false;
        }
    }
    return  true;
}

-(void) completePullMessages:(NSArray<WKMessage*>*)messages error:(NSError*)error complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete{
    
    [self fillReaction:messages];
    [self fillReplyRevoke:messages];
    complete([self sortMessages:messages],nil);
    
    
}

// 填充回应
-(void) fillReaction:(NSArray<WKMessage*> *)messages {
    NSMutableArray *messageIDs = [NSMutableArray array];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            [messageIDs addObject:@(message.messageId)];
        }
    }
    NSDictionary *reactionDict=  [[WKReactionDB shared] getReactionDictionary:messageIDs];
    
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            NSString *key = [NSString stringWithFormat:@"%llu", message.messageId];
            message.reactions = reactionDict[key];
        }
    }
    
}

// 填充回复撤回状态
-(void) fillReplyRevoke:(NSArray<WKMessage*>*)messages {
    NSMutableArray<NSNumber*> *messageIDs = [NSMutableArray array];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            if(message.content.reply) {
                [messageIDs addObject:@([message.content.reply.messageID longLongValue])];
            }
        }
    }
    if(messageIDs.count>0) {
        // 被回复的消息
       NSArray<WKMessage*> *beReplyMessages = [WKMessageDB.shared getMessagesWithMessageIDs:messageIDs];
        if(beReplyMessages.count>0) {
            for (WKMessage *message in messages) {
                for (WKMessage *beReplyMessage in beReplyMessages) {
                    if(message.content.reply && [message.content.reply.messageID longLongValue] == beReplyMessage.messageId) {
                        message.content.reply.revoke = beReplyMessage.remoteExtra.revoke;
                        break;
                    }
                   
                }
            }
        }
    }
}

-(void) pullMessages:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq endOrderSeq:(uint32_t)endOrderSeq  limit:(int)limit pullMode:(WKPullMode)pullMode   complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete {
    [self pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq maxMessageSeq:0 limit:limit pullMode:pullMode  maxExecCount:5 complete:complete];
}


// 查询最新的消息
-(void) pullLastMessages:(WKChannel*)channel limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete {
    
    [self pullMessages:channel startOrderSeq:0 endOrderSeq:0 limit:limit pullMode:WKPullModeUp  complete:complete];
}

-(void) pullLastMessages:(WKChannel*)channel endOrderSeq:(uint32_t)endOrderSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete {
    [self pullMessages:channel startOrderSeq:0 endOrderSeq:endOrderSeq limit:limit pullMode:WKPullModeUp  complete:complete];
}

-(void) pullLastMessages:(WKChannel*)channel endOrderSeq:(uint32_t)endOrderSeq maxMessageSeq:(uint32_t)maxMessageSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete {
    [self pullMessages:channel startOrderSeq:0 endOrderSeq:endOrderSeq maxMessageSeq:maxMessageSeq limit:limit pullMode:WKPullModeUp maxExecCount:5 complete:complete];
}

-(void) pullDown:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete{
    
    [self pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:0 limit:limit pullMode:WKPullModeDown complete:complete];
}

-(void) pullUp:(WKChannel*)channel startOrderSeq:(uint32_t)startOrderSeq limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete{
    [self pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:0 limit:limit pullMode:WKPullModeUp complete:complete];
}

- (void)pullUp:(WKChannel *)channel startOrderSeq:(uint32_t)startOrderSeq endOrderSeq:(uint32_t)endOrderSeq limit:(int)limit complete:(void (^)(NSArray<WKMessage *> * _Nonnull, NSError * _Nonnull))complete {
    [self pullMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq limit:limit pullMode:WKPullModeUp complete:complete];
}

-(void) pullAround:(WKChannel*)channel orderSeq:(uint32_t)aroundOrderSeq maxMessageSeq:(uint32_t)maxMessageSeq  limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete {
    uint32_t baseOrderSeq = aroundOrderSeq; // 基准orderSeq（起始ordeqrSeq）
    uint32_t offset = 5;
    if (aroundOrderSeq!=0) {
        uint32_t maxMessageSeqFromDB = [[WKMessageDB shared] getMaxMessageSeq:channel]; // 获取当前频道最大的messageSeq
        uint32_t aroundMessageSeq = [[WKSDK shared].chatManager getOrNearbyMessageSeq:aroundOrderSeq]; // 获取aroundOrderSeq最接近的messageSeq
        uint32_t baseMessageSeq = aroundMessageSeq;
        if(maxMessageSeqFromDB > aroundMessageSeq && maxMessageSeqFromDB - aroundMessageSeq<limit) { // 如果消息数量不满足limit，则直接查询第一屏，baseMessageSeq为0
            baseMessageSeq = 0;
        }else if(aroundMessageSeq>maxMessageSeq) {
            baseMessageSeq = aroundMessageSeq;
            if(baseMessageSeq>offset) {
                baseMessageSeq = baseMessageSeq - offset;
            }
        }else { // 如果满足limit数量，则以aroundOrderSeq为基准查询5条的第一条消息messageSeq，比如 aroundOrderSeq=10，getChannelAroundFirstMessageSeq查询到的就是 “9 8 7 6 5 ” 5条中的 5，然后以此messageSeq为baseMessageSeq进行查询
            if(baseMessageSeq>0) {
                baseMessageSeq = [[WKMessageDB shared] getChannelAroundFirstMessageSeq:channel messageSeq:aroundMessageSeq];
                if(aroundMessageSeq - baseMessageSeq > offset) {
                    baseMessageSeq = aroundMessageSeq - offset;
                }
                if(baseMessageSeq == 0) { // 如果baseMessageSeq=0 说明本地没有对应的消息
                    if(aroundMessageSeq - offset >0) {
                        baseMessageSeq = aroundMessageSeq - offset;
                    }else {
                        baseMessageSeq = aroundMessageSeq;
                    }
                }
            }
        }
//        if(baseMessageSeq != 0 ) {
//            // 如果最后一条messageSeq与开始messageSeq的差值小于查询数量，则向上偏移指定数量满足limit
//            if(maxMessageSeqFromDB - baseMessageSeq > 0 && maxMessageSeqFromDB - baseMessageSeq<limit) {
//                if(baseMessageSeq>(limit - (maxMessageSeqFromDB - baseMessageSeq))) {
//                    baseMessageSeq = baseMessageSeq - (limit - (maxMessageSeqFromDB - baseMessageSeq));
//                }
//               
//            }
//        }
        baseOrderSeq = [[WKSDK shared].chatManager getOrderSeq:baseMessageSeq];
    }
    
    [self pullMessages:channel startOrderSeq:baseOrderSeq endOrderSeq:0 maxMessageSeq:maxMessageSeq limit:limit pullMode:WKPullModeUp maxExecCount:5 complete:complete];
}

-(void) pullAround:(WKChannel*)channel orderSeq:(uint32_t)aroundOrderSeq  limit:(int)limit complete:(void(^)(NSArray<WKMessage*> *messages,NSError *error))complete {
   
    [self  pullAround:channel orderSeq:aroundOrderSeq maxMessageSeq:0 limit:limit complete:complete];
   
}


- (NSArray<WKMessage*> *)getLocalMessages:(WKChannel*) channel startOrderSeq:(uint32_t)startOrderSeq endOrderSeq:(uint32_t)endOrderSeq    limit:(int)limit pullMode:(WKPullMode)mode {
//    NSArray *messages =  [[WKMessageDB shared] getMessages:channel oldestOrderSeq:oldestOrderSeq contain:contain limit:limit reverse:reverse];
    NSArray *messages = [[WKMessageDB shared] getMessages:channel startOrderSeq:startOrderSeq endOrderSeq:endOrderSeq  limit:limit pullMode:mode];
    return messages;
}

-(BOOL) calSync:(WKChannel*)channel startMessageSeq:(uint32_t)startMessageSeq endMessageSeq:(uint32_t)endMessageSeq pullMode:(WKPullMode)pullMode  complete:(void(^)(WKSyncChannelMessageModel*model,NSError *error))complete{
    
    if(startMessageSeq == 1 && pullMode == WKPullModeDown) {
        return false;
    }
    
    int limit =  (int)[WKSDK shared].options.syncChannelMessageLimit;
    if((startMessageSeq == 0 && endMessageSeq == 0) || (pullMode == WKPullModeUp && startMessageSeq == 0)) {
        [self calSyncForForce:channel startMessageSeq:startMessageSeq endMessageSeq:endMessageSeq pullMode:pullMode limit:limit complete:complete];
        return true;
    }
    
   uint32_t realStartMessageSeq = startMessageSeq;
    
    NSArray<NSNumber*> *deletedMessageSeqs;
    if(pullMode == WKPullModeUp) {
        if(endMessageSeq == 0) {
           deletedMessageSeqs = [WKMessageDB.shared getDeletedMoreThanMessageSeqWithChannel:channel messageSeq:startMessageSeq limit:limit];
            
        }else if(endMessageSeq>0 && endMessageSeq>startMessageSeq) {
            deletedMessageSeqs = [WKMessageDB.shared getDeletedMessageSeqWithChannel:channel minMessageSeq:realStartMessageSeq maxMessageSeq:endMessageSeq];
        }
        if(deletedMessageSeqs && deletedMessageSeqs.count>0) {
            for (NSNumber *deletedMessageSeq in deletedMessageSeqs) {
                uint32_t  deleltedMessageSeqInt64 = (uint32_t)deletedMessageSeq.unsignedLongLongValue;
                if(deleltedMessageSeqInt64 - (uint32_t)realStartMessageSeq>0 && (int64_t)deleltedMessageSeqInt64 - (int64_t)realStartMessageSeq>1) {
                    break;
                }else if(deleltedMessageSeqInt64 - realStartMessageSeq == 1) {
                    realStartMessageSeq = deleltedMessageSeqInt64;
                }
            }
        }
        if(endMessageSeq>0 && realStartMessageSeq + 1 >= endMessageSeq ) {
            return false;
        }
    }else {
        if(startMessageSeq==0) {
            return false;
        }
        deletedMessageSeqs = [WKMessageDB.shared getDeletedLessThanMessageSeqWithChannel:channel messageSeq:startMessageSeq limit:limit];
        if(deletedMessageSeqs && deletedMessageSeqs.count>0) {
            for (NSNumber *deletedMessageSeq in deletedMessageSeqs) {
                uint32_t  deleltedMessageSeqInt64 = (uint32_t)deletedMessageSeq.unsignedLongLongValue;
                if((uint32_t)realStartMessageSeq - deleltedMessageSeqInt64>0 && (int64_t)realStartMessageSeq - (int64_t)deleltedMessageSeqInt64>1) {
                    break;
                }else if(realStartMessageSeq - deleltedMessageSeqInt64 == 1) {
                    realStartMessageSeq = deleltedMessageSeqInt64;
                }
            }
        }
        if(endMessageSeq>0 && realStartMessageSeq - endMessageSeq == 1 ) {
            return false;
        }
        if(endMessageSeq>0 && realStartMessageSeq <= endMessageSeq) {
            return false;
        }
    }

    [self calSyncForForce:channel startMessageSeq:realStartMessageSeq endMessageSeq:endMessageSeq pullMode:pullMode limit:limit complete:complete];
    return true;
    
}

-(void) calSyncForForce:(WKChannel*)channel startMessageSeq:(uint32_t)startMessageSeq endMessageSeq:(uint32_t)endMessageSeq pullMode:(WKPullMode)pullMode limit:(NSInteger)limit  complete:(void(^)(WKSyncChannelMessageModel*model,NSError *error))complete {
    // 远程同步消息
    if(![WKSDK shared].chatManager.syncChannelMessageProvider) {
        if(complete) {
            complete([WKSyncChannelMessageModel new],nil);
        }
        return;
    }
    
    uint32_t startSeq = startMessageSeq;
    uint32_t endSeq = endMessageSeq;
    if(pullMode == WKPullModeUp) {
        if(startMessageSeq!=0) {
            startSeq += 1; // 数据应该不包含自己
        }
        if(endMessageSeq !=0) {
            endSeq += 1;
        }
        
    }else {
        if(startMessageSeq!=0) {
            startSeq -= 1; // 数据应该不包含自己
        }
        if(endMessageSeq !=0) {
            endSeq -= 1;
        }
    }

    [WKSDK shared].chatManager.syncChannelMessageProvider(channel, startSeq, endSeq,limit,pullMode , ^(WKSyncChannelMessageModel * _Nullable syncChannelMessageModel, NSError * _Nullable error) {
        if(error) {
            if(complete) {
                complete(nil,error);
            }
            return;
        }
        if(!syncChannelMessageModel.messages || syncChannelMessageModel.messages.count<=0) {
            NSLog(@"没有拉取到频道[%@-%d]消息序号 %u~%u之间的消息！",channel.channelId,channel.channelType,startMessageSeq,endMessageSeq);
            if(complete) {
                complete(nil,[NSError errorWithDomain:@"拉取消息失败！" code:0 userInfo:nil]);
            }
            return;
        }
        if(complete) {
            complete(syncChannelMessageModel,nil);
        }

    });
}


-(NSArray<WKMessage*>*) recvPacketsToMessages:(NSArray<WKRecvPacket*>*)packets {
    NSMutableArray *messages = [NSMutableArray array];
    for (WKRecvPacket *packet in packets) {
        WKMessage *message = [[WKMessage alloc] init];
        message.setting = packet.setting;
        message.header.showUnread = packet.header.showUnread;
        message.header.noPersist = packet.header.noPersist;
        message.header.syncOnce = packet.header.syncOnce;
        
        message.messageId = packet.messageId;
        message.messageSeq = packet.messageSeq;
        message.clientMsgNo = packet.clientMsgNo;
        message.streamNo = packet.streamNo;
        message.streamSeq = packet.streamSeq;
        message.streamFlag = packet.streamFlag;
        message.timestamp = packet.timestamp;
        message.fromUid = packet.fromUid;
        message.channel = [[WKChannel alloc] initWith:packet.channelId channelType:packet.channelType];
        message.topic = packet.topic;
       
        NSData *planPayloadData = packet.payload;
        
    
        message.status = WK_MESSAGE_SUCCESS;
        
        WKMessageContent *messageContent;
        NSNumber *contentType;
        messageContent = [self decodeContent:planPayloadData contentType:&contentType];
        message.contentData = planPayloadData;
        
       
        
        if(!message.fromUid || [message.fromUid isEqualToString:@""]) { // 如果协议层没有给fromUID 则如果content层有则填充上去
            message.fromUid = messageContent.senderUserInfo?messageContent.senderUserInfo.uid:@"";
        }
        
        if([packet.channelId isEqualToString:[WKSDK shared].options.connectInfo.uid]) {
            message.channel = [[WKChannel alloc] initWith:packet.fromUid channelType:packet.channelType];
        }
        
        message.content = messageContent;
        message.contentType = contentType.integerValue;
        if(messageContent.extra[@"session_id"]&&messageContent.extra[@"session_type"]) {
             message.channel = [[WKChannel alloc] initWith:messageContent.extra[@"session_id"] channelType:[messageContent.extra[@"session_type"] intValue]];
        }
        
        if(message.content.visibles && message.content.visibles.count>0) {
            message.isDeleted = ![message.content.visibles containsObject:[WKSDK shared].options.connectInfo.uid];
        }
       
        [messages addObject:message];
    }
    return  messages;
}

-(WKMessageContent*) decodeContent:(NSData*) contentData contentType:(NSNumber**)contentType{
    NSError *error;
    NSDictionary *contentDict = [NSJSONSerialization JSONObjectWithData:contentData options:kNilOptions error:&error];
    if(error) {
        NSLog(@"消息内容非JSON格式！-> %@",error);
        return  nil;
    }
    if(!contentDict) {
         NSLog(@"消息内容非JSON格式！");
        return nil;
    }
     NSNumber *actContentType = [contentDict objectForKey:@"type"];
    WKMessageContent *messageContent;
    if(!contentType) {
        messageContent = [[WKUnknownContent alloc] init];
    }else {
        Class contentClass = [[WKSDK shared] getMessageContent:actContentType.integerValue];
        messageContent = [[contentClass alloc] init];
    }

    [messageContent decode:contentData];
    
    *contentType = actContentType;
    return messageContent;
}

-(WKMessageContent*) getMessageContent:(NSInteger)contentType {
    WKMessageContent *messageContent;
    if(!contentType) {
        messageContent = [[WKUnknownContent alloc] init];
    }else {
        Class contentClass = [[WKSDK shared] getMessageContent:contentType];
        messageContent = [[contentClass alloc] init];
    }
    return messageContent;
}


- (void)updateMessageVoiceReaded:(WKMessage*)message {
    [[WKMessageDB shared] updateMessageVoiceReaded:message.voiceReaded clientSeq:message.clientSeq];
    [self callMessageUpdateDelegate:message];
}

-(void) updateMessageLocalExtra:(WKMessage*)message {
    [[WKMessageDB shared] updateMessageExtra:message.extra clientSeq:message.clientSeq];
    [self callMessageUpdateDelegate:message];
}

/**
  更新消息远程扩展
 */
-(void) updateMessageRemoteExtra:(WKMessage*)message {
    if(!self.updateMessageExtraProvider) {
        NSLog(@"updateMessageExtraProvider没有设置！");
        return;
    }
    
    WKMessageExtra *oldMessageExtra = [[WKMessageExtraDB shared] getMessageExtraWithMessageID:message.messageId];
    
    __weak typeof(self) weakSelf = self;
    self.updateMessageExtraProvider(message.remoteExtra, oldMessageExtra, ^(NSError * _Nonnull error) {
        if(error) {
            NSLog(@"更新远程消息扩展失败！->%@",error);
            return;
        }
       
        [[WKMessageExtraDB shared] addOrUpdateMessageExtras:@[message.remoteExtra]];
        [weakSelf callMessageUpdateDelegate:message];
        
        if(message.remoteExtra.isMutualDeleted) { // 如果是双向删除 则删除此消息
            [weakSelf deleteMessage:message];
        }
       
    });
}

-(void) revokeMessage:(WKMessage*)message {
    [[WKMessageDB shared] updateMessageRevoke:YES clientMsgNo:message.clientMsgNo];
    message.remoteExtra.revoke = YES;
    [self callMessageUpdateDelegate:message];
    
    WKConversation *conversation =  [[WKConversationDB shared] getConversationWithLastClientMsgNo:message.clientMsgNo];
   if(conversation) {
       conversation.reminders = [[WKReminderDB shared] getWaitDoneReminder:conversation.channel];
       conversation.lastMessage = message;
       [[WKSDK shared].conversationManager callOnConversationUpdateDelegate:conversation];
   }
}

-(NSMutableDictionary*) retryMessageDict {
    if(!_retryMessageDict) {
        _retryMessageDict = [[NSMutableDictionary alloc] init];
    }
    return _retryMessageDict;
}

- (NSLock *)delegateLock {
    if (_delegateLock == nil) {
        _delegateLock = [[NSLock alloc] init];
    }
    return _delegateLock;
}

-(NSHashTable*) delegates {
    if (_delegates == nil) {
        _delegates = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return _delegates;
}



-(void) addDelegate:(id<WKChatManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKChatManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

- (void)callRecvMessagesDelegate:(NSArray<WKMessage*>*)messages {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onRecvMessages:left:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(messages && messages.count>0) {
                        for(int i=0;i<messages.count;i++) {
                            [delegate onRecvMessages:messages[i] left:messages.count - (i+1)];
                        }
                    }
                });
            }else {
                if(messages && messages.count>0) {
                    for(int i=0;i<messages.count;i++) {
                        [delegate onRecvMessages:messages[i] left:messages.count - (i+1)];
                    }
                }
            }
        }
    }
}

- (void)callStreamDelegate:(NSArray<WKStream*>*)streams {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onMessageStream:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(streams && streams.count>0) {
                        for(int i=0;i<streams.count;i++) {
                            [delegate onMessageStream:streams[i]];
                        }
                    }
                });
            }else {
                if(streams && streams.count>0) {
                    for(int i=0;i<streams.count;i++) {
                        [delegate onMessageStream:streams[i]];
                    }
                }
            }
        }
    }
}


-(uint32_t) getOrderSeq:(uint32_t)messageSeq {
    return messageSeq*WKOrderSeqFactor;
}

-(uint32_t) getMessageSeq:(uint32_t) orderSeq {
    if(orderSeq%WKOrderSeqFactor == 0) {
        return orderSeq/WKOrderSeqFactor;
    }
    return 0;
}

-(uint32_t) getOrNearbyMessageSeq:(uint32_t)orderSeq {
    if(orderSeq%WKOrderSeqFactor == 0) {
        return  orderSeq/WKOrderSeqFactor;
    }
    return (orderSeq - orderSeq%WKOrderSeqFactor)/WKOrderSeqFactor;
}

- (void)callMessageUpdateDelegate:(WKMessage*)message left:(NSInteger)left total:(NSInteger)total{
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onMessageUpdate:left:total:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onMessageUpdate:message left:left total:total];
                });
            }else {
                [delegate onMessageUpdate:message left:left total:total];
            }
        }
        if ([delegate respondsToSelector:@selector(onMessageUpdate:left:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onMessageUpdate:message left:left];
                });
            }else {
                [delegate onMessageUpdate:message left:left];
            }
        }
    }
}

- (void)callMessageUpdateDelegate:(WKMessage*)message {
    [self callMessageUpdateDelegate:message left:0 total:1];
}

- (void)callSendackDelegate:(WKSendackPacket*)sendackPacket left:(NSInteger)left{
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onSendack:left:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onSendack:sendackPacket left:left];
                });
            }else {
                [delegate onSendack:sendackPacket left:left];
            }
        }
    }
}

- (void)callMessageDeletedDelegate:(WKMessage*)message {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onMessageDeleted:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onMessageDeleted:message];
                });
            }else {
                [delegate onMessageDeleted:message];
            }
        }
    }
}

- (void)callMessagClearedDelegate:(WKChannel*)channel {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(onMessageCleared:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate onMessageCleared:channel];
                });
            }else {
                [delegate onMessageCleared:channel];
            }
        }
    }
}

- (NSMutableDictionary *)interceptDict {
    if(!_interceptDict) {
        _interceptDict = [NSMutableDictionary dictionary];
    }
    return _interceptDict;
}

-(void) addMessageStoreBeforeIntercept:(NSString*)sid intercept:(BOOL(^)(WKMessage*message))interceptBlock {
    self.interceptDict[sid] = interceptBlock;
}

- (void)removeMessageStoreBeforeIntercept:(NSString *)sid {
    [self.interceptDict removeObjectForKey:sid];
}

-(NSArray<MessageStoreBeforeIntercept>*) getMessageStoreBeforeIntercepts {
    return  self.interceptDict.allValues;
}

-(void) syncMessageExtra:(WKChannel*)channel complete:(void(^_Nullable)(NSError * _Nullable error))complete{
    [self syncMessageExtra:channel complete:complete maxReqCount:20];
}

-(void) syncMessageExtra:(WKChannel*)channel complete:(void(^)(NSError *error))complete maxReqCount:(NSInteger)maxCount{
    if(maxCount<=0) {
        if(complete) {
            complete([NSError errorWithDomain:[NSString stringWithFormat:@"同步消息扩展的请求超过了最大次数！"] code:0 userInfo:nil]);
        }
       
        return;
    }
    maxCount--;
    if(self.syncMessageExtraProvider) {
        __weak typeof(self) weakSelf = self;
        long long version = 0;
        long long maxExtraVersion = [[WKMessageDB shared] getMessageExtraMaxVersion:channel];
        long long maxExtraVersionInMessageExtra = [[WKMessageExtraDB shared] getMessageExtraMaxVersion:channel];
        version = MAX(maxExtraVersion, maxExtraVersionInMessageExtra);
        self.syncMessageExtraProvider(channel, version, [WKSDK shared].options.messageExtraSyncLimit, ^(NSArray<WKMessageExtra *> * _Nullable results, NSError * _Nullable error) {
            if(error!=nil) {
                if(complete) {
                    complete(error);
                    return;
                }
            }
            if(results && results.count>0) {
                NSMutableArray<NSNumber*> *messageIDs = [NSMutableArray array];
                for (WKMessageExtra *messageExtra in results) {
                    [messageIDs addObject:@(messageExtra.messageID)];
                }
                [[WKMessageExtraDB shared] addOrUpdateMessageExtras:results];
                NSArray<WKMessage*> *messages = [[WKMessageDB shared] getMessagesWithMessageIDs:messageIDs];
                if(messages && messages.count>0) {
                    NSDictionary *reactionDict=  [[WKReactionDB shared] getReactionDictionary:messageIDs];
                    NSInteger i = messages.count - 1;
                    
                    // 消息更新通知
                    for (WKMessage *message in messages) {
                        message.reactions = reactionDict[[NSString stringWithFormat:@"%llu", message.messageId]];
                        [weakSelf callMessageUpdateDelegate:message left:i total:messages.count];
                        i--;
                    }
                    
                    // 消息删除通知
                    NSMutableArray<WKMessage*> *deletedMessages = [NSMutableArray array];
                    for (WKMessage *message in messages) {
                        for (WKMessageExtra *messageExtra in results) {
                            if(messageExtra.isMutualDeleted) {
                                message.isDeleted = true;
                                [deletedMessages addObject:message];
                                break;
                            }
                        }
                    }
                    if(deletedMessages.count>0) {
                        for (WKMessage *message in deletedMessages) {
                            [weakSelf deleteMessage:message];
                        }
                    }
                    
                }
               // [weakSelf updateMessageExtraFromRemote:results];
            }
            if(results && results.count>=[WKSDK shared].options.messageExtraSyncLimit) {
                [weakSelf syncMessageExtra:channel complete:complete maxReqCount:maxCount];
            }
        });
    }
}

-(WKMessage*) getLastMessage:(WKChannel*)channel {
    
    return [[WKMessageDB shared] getLastMessage:channel];
}

@end
