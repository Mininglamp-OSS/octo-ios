//
//  WKMessageList.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKMessageList.h"
#import "WKTimeTool.h"
#import "WuKongBase.h"
#import "WKProhibitwordsService.h"
@interface WKMessageList ()

@property(nonatomic,strong) NSLock *messagesLock;

@property(nonatomic,strong) NSMutableDictionary<NSString*,NSMutableArray<WKMessageModel*>*> *dateMessageGroups; // 通过日期对消息分组

// O(1) 查找索引：存 model 引用而非 NSIndexPath，避免插入/删除后 indexPath 陈旧
// indexPath 在需要时通过 _indexPathForModel: 从 model 反向计算（O(D+K)，D=日期数，K=当天消息数）
@property(nonatomic,strong) NSMutableDictionary<NSString*, WKMessageModel*> *clientMsgNoIndex;
@property(nonatomic,strong) NSMutableDictionary<NSNumber*, WKMessageModel*> *orderSeqIndex;
@property(nonatomic,strong) NSMutableDictionary<NSNumber*, WKMessageModel*> *messageIdIndex;
@property(nonatomic,strong) NSMutableDictionary<NSString*, WKMessageModel*> *streamNoIndex;

@end

@implementation WKMessageList

#pragma mark - 索引维护（调用前必须持有 messagesLock）

- (void)_addToIndexNoLock:(WKMessageModel *)model {
    if (model.clientMsgNo.length > 0) self.clientMsgNoIndex[model.clientMsgNo] = model;
    if (model.orderSeq > 0) self.orderSeqIndex[@(model.orderSeq)] = model;
    if (model.messageId > 0) self.messageIdIndex[@(model.messageId)] = model;
    if (model.streamNo.length > 0) self.streamNoIndex[model.streamNo] = model;
}

- (void)_removeFromIndexNoLock:(WKMessageModel *)model {
    if (model.clientMsgNo.length > 0) [self.clientMsgNoIndex removeObjectForKey:model.clientMsgNo];
    if (model.orderSeq > 0) [self.orderSeqIndex removeObjectForKey:@(model.orderSeq)];
    if (model.messageId > 0) [self.messageIdIndex removeObjectForKey:@(model.messageId)];
    if (model.streamNo.length > 0) [self.streamNoIndex removeObjectForKey:model.streamNo];
}

// 由 model 反推 NSIndexPath：O(D+K)，D=日期分组数(<20)，K=当天消息数，远小于总消息数 N
- (NSIndexPath *)_indexPathForModel:(WKMessageModel *)model {
    NSString *date = [self formatMessageDate:model];
    NSInteger section = [self.dates indexOfObject:date];
    if (section == NSNotFound) return nil;
    NSMutableArray *messages = self.dateMessageGroups[date];
    NSInteger row = [messages indexOfObjectIdenticalTo:model]; // 指针比较，不用 isEqual
    if (row == NSNotFound) return nil;
    return [NSIndexPath indexPathForRow:row inSection:section];
}

#pragma mark -

- (void)insertMessages:(NSArray<WKMessageModel *> *)messages {
    [self.messagesLock lock];
    for(int i=0;i<messages.count;i++) {
        [self _insertMessageNoLock:messages[i]];
    }
    [self.messagesLock unlock];
}


-(void) insertMessage:(WKMessageModel*)model {
    [self.messagesLock lock];
    [self _insertMessageNoLock:model];
    [self.messagesLock unlock];
}

// 内部方法，调用前必须持有 messagesLock
-(void) _insertMessageNoLock:(WKMessageModel*)model {
    if(model.clientMsgNo.length > 0 && self.clientMsgNoIndex[model.clientMsgNo]) {
        return;
    }
    if(model.contentType == WK_TEXT) {
       WKTextContent *content = (WKTextContent*)model.content;
        content.content = [WKProhibitwordsService.shared filter:content.content]; // 违禁词过滤
    }

    NSString *date = [self formatMessageDate:model];
    NSMutableArray *messages = self.dateMessageGroups[date];
    if(!messages) {
        messages = [NSMutableArray array];
        self.dateMessageGroups[date] = messages;
        [self.dates insertObject:date atIndex:0];
    }
    if(messages.count>0) {
        WKMessageModel *oldMessageModel = messages.firstObject;
        model.nextMessageModel = oldMessageModel;
        oldMessageModel.preMessageModel = model;
    }
    [messages insertObject:model atIndex:0];
    [self _addToIndexNoLock:model];
}


-(void) addMessages:(NSArray<WKMessageModel*>*)messages {
    for (WKMessageModel *message in messages) {
        [self addMessage:message];
    }
}

-(void) setMessages:(NSArray<WKMessageModel*>*)messages forDate:(NSString*)date {
    NSMutableArray *oldMessages = self.dateMessageGroups[date];
    for (WKMessageModel *m in oldMessages) [self _removeFromIndexNoLock:m];
    NSMutableArray *newMessages = [NSMutableArray arrayWithArray:messages];
    self.dateMessageGroups[date] = newMessages;
    for (WKMessageModel *m in newMessages) [self _addToIndexNoLock:m];
}

-(NSArray<WKMessageModel*>*) messagesAtDate:(NSString*)date {
    [_messagesLock lock];
    NSArray<WKMessageModel*> *messages =  self.dateMessageGroups[date];
    [_messagesLock unlock];
    return messages;
}

-(void) clearMessages {
    [_messagesLock lock];
    [self.dates removeAllObjects];
    [self.dateMessageGroups removeAllObjects];
    [self.clientMsgNoIndex removeAllObjects];
    [self.orderSeqIndex removeAllObjects];
    [self.messageIdIndex removeAllObjects];
    [self.streamNoIndex removeAllObjects];
    [_messagesLock unlock];
}
-(void) addMessage:(WKMessageModel*)message {
    
    
    [self.messagesLock lock];
    WKMessageModel *typingMessageModel;
    WKMessageModel *lastMessage = [self lastMessage];
    if(lastMessage && lastMessage.contentType == WK_TYPING) {
        typingMessageModel = lastMessage;
    }
    if(typingMessageModel) {
        if(message.contentType == WK_TYPING) { // 如果已经有typing消息，则要添加的消息也是typing消息则直接丢弃
            [self.messagesLock unlock];
            return;
        }
        if([typingMessageModel.fromUid isEqual:message.fromUid]) {
            [self replaceMessageLast:message];
        }else {
           NSMutableArray *messages  =  self.dateMessageGroups[self.dates[self.dates.count-1]];
            [self _insertMessage:message atIndex:[NSIndexPath indexPathForRow:messages.count-1 inSection:self.dates.count-1]];
        }
    }else {
        if(self.dates.count>0) {
            message.preMessageModel = lastMessage;
            lastMessage.nextMessageModel = message;
        }
        [self addMessageOnly:message];
    }
    
    [self.messagesLock unlock];
}


-(NSIndexPath*) replaceMessage:(WKMessageModel*)newMessage atClientMsgNo:(NSString*)clientMsgNo {
    NSIndexPath *path = [self indexPathAtClientMsgNo:clientMsgNo];
    return [self replaceMessage:newMessage atIndexPath:path];
}

-(void) _insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath {
    if(!indexPath || indexPath.section >= self.dates.count) {
        return;
    }
    
   NSMutableArray<WKMessageModel*> *messages =  self.dateMessageGroups[self.dates[indexPath.section]];
    if(messages.count>0) {
        if (indexPath.row == 0) { // 插入到最前面
            WKMessageModel *oldFirstMessage = messages[0];
            oldFirstMessage.preMessageModel = message;
            message.nextMessageModel = oldFirstMessage;
        } else if(messages.count>indexPath.row) { // 插入到非首尾
            WKMessageModel *currentMessage = messages[indexPath.row];
        
            message.preMessageModel = currentMessage.preMessageModel;
            message.nextMessageModel = currentMessage;
           
            currentMessage.preMessageModel = message;
            if(message.preMessageModel) {
                message.preMessageModel.nextMessageModel = message;
            }
        
        }else if(messages.count==indexPath.row) { // 插入到最后
            WKMessageModel *oldLastMessage = messages[messages.count-1];
            oldLastMessage.nextMessageModel = message;
            message.preMessageModel = oldLastMessage;
        }
    }
   
    [messages insertObject:message atIndex:indexPath.row];
   [self _addToIndexNoLock:message];
}


// 替换最新的消息
-(void) replaceMessageLast:(WKMessageModel*)model {
    [self handleProhibitwords:model]; // 处理违禁词
    NSString *date = self.dates.lastObject;
    NSMutableArray *messages = self.dateMessageGroups[date];
    if(messages && messages.count>0) {
        WKMessageModel *oldMessageModel = messages.lastObject;
        [self _removeFromIndexNoLock:oldMessageModel];
        model.preMessageModel = oldMessageModel.preMessageModel;
        if(oldMessageModel.preMessageModel) {
            oldMessageModel.preMessageModel.nextMessageModel = model;
        }
        [messages replaceObjectAtIndex:messages.count-1 withObject:model];
        [self _addToIndexNoLock:model];
    }
}


-(NSIndexPath*) replaceMessage:(WKMessageModel*)newMessage atIndexPath:(NSIndexPath*)path {
    [self handleProhibitwords:newMessage]; // 处理违禁词
    [_messagesLock lock];
    if(path) {
       NSMutableArray *messages =  self.dateMessageGroups[self.dates[path.section]];
        if(!messages) {
            messages = [NSMutableArray array];
        }
        if(path.row < messages.count) {
            WKMessageModel *oldMessage =  messages[path.row];
            [self _removeFromIndexNoLock:oldMessage];
            newMessage.preMessageModel = oldMessage.preMessageModel;
            newMessage.nextMessageModel = oldMessage.nextMessageModel;
            messages[path.row] = newMessage;
            [self _addToIndexNoLock:newMessage];
            if(oldMessage.preMessageModel) {
                oldMessage.preMessageModel.nextMessageModel = newMessage;
            }
            if(oldMessage.nextMessageModel) {
                oldMessage.nextMessageModel.preMessageModel = newMessage;
            }
        }
    }
    [_messagesLock unlock];
    return path;
}


-(void) addMessageOnly:(WKMessageModel *)message {
    if(message.clientMsgNo.length > 0 && self.clientMsgNoIndex[message.clientMsgNo]) {
        return;
    }

    [self handleProhibitwords:message]; // 处理违禁词

    NSString *date = [self formatMessageDate:message];
    NSMutableArray *messages = self.dateMessageGroups[date];
    if(!messages) {
        messages = [NSMutableArray array];
        self.dateMessageGroups[date] = messages;
        [self.dates addObject:date];
    }
    [messages addObject:message];
    [self _addToIndexNoLock:message];
}

-(void) handleProhibitwords:(WKMessageModel*)messageModel {
    if(messageModel.contentType == WK_TEXT) {
        if(messageModel.remoteExtra.isEdit && [messageModel.remoteExtra.contentEdit isKindOfClass:[WKTextContent class]]) {
            WKTextContent *content = (WKTextContent*)messageModel.remoteExtra.contentEdit;
            if ([content.content isKindOfClass:[NSString class]]) {
                content.content = [WKProhibitwordsService.shared filter:content.content];
            }
            return;
        }
        if (![messageModel.content isKindOfClass:[WKTextContent class]]) return;
        WKTextContent *content = (WKTextContent*)messageModel.content;
        if ([content.content isKindOfClass:[NSString class]]) {
            content.content = [WKProhibitwordsService.shared filter:content.content];
        }
    }
}

-(WKMessageModel*) lastMessage {
    if(self.dates.count==0) {
        return nil;
    }
   NSString *lastDate = self.dates.lastObject;
    NSMutableArray *messageModels = self.dateMessageGroups[lastDate];
    if(messageModels && messageModels.count>0) {
        return messageModels.lastObject;
    }
    return nil;
}


-(WKMessageModel*) firstMessage {
    if(self.dates.count==0) {
        return nil;
    }
    NSString *firstDate = self.dates.firstObject;
     NSMutableArray *messageModels = self.dateMessageGroups[firstDate];
     if(messageModels && messageModels.count>0) {
         return messageModels.firstObject;
     }
     return nil;
}


-(NSIndexPath*) indexPathAtOrderSeq:(uint32_t)orderSeq {
    if(orderSeq == 0) return nil;
    [_messagesLock lock];
    WKMessageModel *model = self.orderSeqIndex[@(orderSeq)];
    NSIndexPath *path = model ? [self _indexPathForModel:model] : nil;
    [_messagesLock unlock];
    return path;
}

-(NSIndexPath*) indexPathAtMessageID:(uint64_t)messageID {
    if(messageID == 0) return nil;
    [_messagesLock lock];
    WKMessageModel *model = self.messageIdIndex[@(messageID)];
    NSIndexPath *path = model ? [self _indexPathForModel:model] : nil;
    [_messagesLock unlock];
    return path;
}

-(NSArray<NSIndexPath*>*) indexPathAtMessageReply:(uint64_t)messageID {
    if(messageID == 0 ){
        return nil;
    }
    [_messagesLock lock];
    NSMutableArray<NSIndexPath*> *indexPaths = [NSMutableArray array];
    for (NSInteger i=self.dates.count-1; i>=0; i--) {
        NSMutableArray *messages = self.dateMessageGroups[self.dates[i]];
        if(messages && messages.count>0) {
            for (NSInteger j=messages.count-1;j>=0; j--) {
                WKMessageModel *messageModel = messages[j];
                if(messageModel.content.reply && [messageModel.content.reply.messageID longLongValue] == messageID) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:j inSection:i]];
                }
            }
        }
    }
    [_messagesLock unlock];
    return indexPaths;
}

-(NSArray<WKMessageModel*>*) messagesAtMessageReply:(uint64_t)messageID {
    if(messageID == 0 ){
        return nil;
    }
    [_messagesLock lock];
    NSMutableArray<WKMessageModel*> *resultMessages = [NSMutableArray array];
    for (NSInteger i=self.dates.count-1; i>=0; i--) {
        NSMutableArray *messages = self.dateMessageGroups[self.dates[i]];
        if(messages && messages.count>0) {
            for (NSInteger j=messages.count-1;j>=0; j--) {
                WKMessageModel *messageModel = messages[j];
                if(messageModel.content.reply && [messageModel.content.reply.messageID longLongValue] == messageID) {
                    [resultMessages addObject:messageModel];
                }
            }
        }
    }
    [_messagesLock unlock];
    return resultMessages;
}

-(NSIndexPath*) indexPathAtClientMsgNo:(NSString*) clientMsgNo {
    if(!clientMsgNo) return nil;
    [_messagesLock lock];
    WKMessageModel *model = self.clientMsgNoIndex[clientMsgNo];
    NSIndexPath *path = model ? [self _indexPathForModel:model] : nil;
    [_messagesLock unlock];
    return path;
}

-(NSIndexPath*) indexPathAtStreamNo:(NSString*)streamNo {
    if(!streamNo) return nil;
    [_messagesLock lock];
    WKMessageModel *model = self.streamNoIndex[streamNo];
    NSIndexPath *path = model ? [self _indexPathForModel:model] : nil;
    [_messagesLock unlock];
    return path;
}



-(NSIndexPath*) removeMessage:(WKMessageModel*) message {
    NSIndexPath *path = [self indexPathAtClientMsgNo:message.clientMsgNo];
    [_messagesLock lock];
    if(path) {
        NSMutableArray *messages =  self.dateMessageGroups[self.dates[path.section]];
        
        WKMessageModel *deleteMessageModel = messages[path.row];
        [self _removeFromIndexNoLock:deleteMessageModel];
        if(deleteMessageModel.preMessageModel) {
            deleteMessageModel.preMessageModel.nextMessageModel = deleteMessageModel.nextMessageModel;
        }
        if(deleteMessageModel.nextMessageModel) {
            deleteMessageModel.nextMessageModel.preMessageModel = deleteMessageModel.preMessageModel;
        }

        [messages removeObjectAtIndex:path.row];
        if(messages.count == 0) {
            [self.dateMessageGroups removeObjectForKey:self.dates[path.section]];
            [self.dates removeObjectAtIndex:path.section];
        }
    }
    [_messagesLock unlock];
    return path;
}

-(NSIndexPath*) removeMessage:(WKMessageModel*) message sectionRemove:(BOOL*)sectionRemove{
    NSIndexPath *path = [self indexPathAtClientMsgNo:message.clientMsgNo];
    [_messagesLock lock];
    if(path) {
        NSMutableArray *messages =  self.dateMessageGroups[self.dates[path.section]];

        WKMessageModel *deleteMessageModel = messages[path.row];
        [self _removeFromIndexNoLock:deleteMessageModel];
        if(deleteMessageModel.preMessageModel) {
            deleteMessageModel.preMessageModel.nextMessageModel = deleteMessageModel.nextMessageModel;
        }
        if(deleteMessageModel.nextMessageModel) {
            deleteMessageModel.nextMessageModel.preMessageModel = deleteMessageModel.preMessageModel;
        }

        [messages removeObjectAtIndex:path.row];
        if(messages.count == 0) {
            *sectionRemove = true;
            [self.dateMessageGroups removeObjectForKey:self.dates[path.section]];
            [self.dates removeObjectAtIndex:path.section];
        }
    }
    [_messagesLock unlock];
    return path;
}

-(void) insertMessage:(WKMessageModel*)message atIndex:(NSIndexPath*)indexPath {
    [self.messagesLock lock];
    [self _insertMessage:message atIndex:indexPath];
    [self.messagesLock unlock];
}

- (BOOL)hasTyping {
    [self.messagesLock lock];
   NSIndexPath *indexPath = [self typingIndexPath];
    if(!indexPath) {
        [self.messagesLock unlock];
        return false;
    }
    [self.messagesLock unlock];
    return true;
}

-(NSInteger) messageCount {
    [self.messagesLock lock];
   __block NSInteger count = 0;
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull obj, BOOL * _Nonnull stop) {
        if(obj) {
            count+=obj.count;
        }
    }];
    [self.messagesLock unlock];
    return count;
}

-(NSIndexPath*) replaceTyping:(WKMessageModel*)messageModel {
    [self.messagesLock lock];
    NSIndexPath *indexPath = [self typingIndexPath];
    BOOL hasTyping = true;
    if(!indexPath) {
        hasTyping = false;
    }
    if(hasTyping) {
        WKMessageModel *typingMessageModel = self.dateMessageGroups[self.dates[indexPath.section]][indexPath.row];
        [self _removeFromIndexNoLock:typingMessageModel];
        if(typingMessageModel.preMessageModel) {
            typingMessageModel.preMessageModel.nextMessageModel = messageModel;
        }
        if(typingMessageModel.nextMessageModel) {
            typingMessageModel.nextMessageModel.preMessageModel = messageModel;
        }
        messageModel.preMessageModel = typingMessageModel.preMessageModel;
        messageModel.nextMessageModel = typingMessageModel.nextMessageModel;

        self.dateMessageGroups[self.dates[indexPath.section]][indexPath.row] = messageModel;
        [self _addToIndexNoLock:messageModel];
    }
    
    [self.messagesLock unlock];
    
    return indexPath;
}

-(void) addTypingMessageIfNeed:(WKMessageModel*)messageModel {
    if([self hasTyping]) {
        return;
    }
    [self addMessage:messageModel];
}

- (NSIndexPath*)typingIndexPath {
    NSIndexPath *indexPath;
    if(self.dates.count>0) {
        NSArray *messages = self.dateMessageGroups[self.dates[self.dates.count-1]];
        if(messages && messages.count>0) {
            WKMessage *message = messages[messages.count-1];
            if(message.contentType == WK_TYPING) {
                indexPath = [NSIndexPath indexPathForRow:messages.count-1 inSection:self.dates.count-1];
            }
        }
    }
    return indexPath;
}

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType {
    __block NSMutableArray<WKMessageModel*> *filterModels = [NSMutableArray array];
     [self.messagesLock lock];
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull messages, BOOL * _Nonnull stop) {
        for (WKMessageModel *messageModel in  messages) {
            if(messageModel.contentType == contentType) {
                [filterModels insertObject:messageModel atIndex:0];
            }
        }
    }];
     [self.messagesLock unlock];
    return filterModels;
}

// 获取被选中的消息
-(NSArray<WKMessageModel*>*) getSelectedMessages {
    [self.messagesLock lock];
    NSMutableArray *selectedMessages = [NSMutableArray array];
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull messages, BOOL * _Nonnull stop) {
        for (WKMessageModel *messageModel in messages) {
            if(messageModel.checked) {
                [selectedMessages addObject:messageModel];
            }
        }
    }];
    [self.messagesLock unlock];
    return selectedMessages;
}

-(void) cancelSelectedMessages {
    [self.messagesLock lock];
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull messages, BOOL * _Nonnull stop) {
        for (WKMessageModel *messageModel in messages) {
            if(messageModel.checked) {
                messageModel.checked = false;
            }
        }
    }];
    [self.messagesLock unlock];
    return;
}

// 把 orderSeq 闭区间 [min, max] 内所有可选消息的 checked 置为 YES，并集语义。
// 跨日期 section 安全：基于 orderSeq 而不是 indexPath。
-(NSInteger) selectMessagesFromOrderSeq:(uint32_t)orderSeqA toOrderSeq:(uint32_t)orderSeqB {
    if(orderSeqA == 0 || orderSeqB == 0) {
        return 0;
    }
    uint32_t minSeq = MIN(orderSeqA, orderSeqB);
    uint32_t maxSeq = MAX(orderSeqA, orderSeqB);
    __block NSInteger added = 0;
    [self.messagesLock lock];
    [self.dateMessageGroups enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<WKMessageModel *> * _Nonnull messages, BOOL * _Nonnull stop) {
        for (WKMessageModel *messageModel in messages) {
            if(messageModel.contentType == WK_TYPING) continue;
            if(messageModel.orderSeq == 0) continue;
            if(messageModel.orderSeq < minSeq || messageModel.orderSeq > maxSeq) continue;
            if(!messageModel.checked) {
                messageModel.checked = YES;
                added++;
            }
        }
    }];
    [self.messagesLock unlock];
    return added;
}

-(NSString*) formatMessageDate:(WKMessageModel*)model {
    return [self formatDate:[NSDate dateWithTimeIntervalSince1970:model.timestamp] ];
}

-(NSString*) formatDate:(NSDate*)date {
    return [WKTimeTool getTimeString:date format:@"yyyy-MM-dd" ];
}


- (NSMutableArray<NSString*> *)dates {
    if(!_dates) {
        _dates = [NSMutableArray array];
    }
    return _dates;
}

- (NSMutableDictionary<NSString *,NSMutableArray<WKMessageModel *> *> *)dateMessageGroups {
    if(!_dateMessageGroups) {
        _dateMessageGroups = [[NSMutableDictionary alloc] init];
    }
    return _dateMessageGroups;
}

-(NSLock*) messagesLock {
    if(!_messagesLock) {
        _messagesLock = [[NSLock alloc] init];
    }
    return _messagesLock;
}

- (NSMutableDictionary *)clientMsgNoIndex {
    if (!_clientMsgNoIndex) _clientMsgNoIndex = [NSMutableDictionary dictionary];
    return _clientMsgNoIndex;
}
- (NSMutableDictionary *)orderSeqIndex {
    if (!_orderSeqIndex) _orderSeqIndex = [NSMutableDictionary dictionary];
    return _orderSeqIndex;
}
- (NSMutableDictionary *)messageIdIndex {
    if (!_messageIdIndex) _messageIdIndex = [NSMutableDictionary dictionary];
    return _messageIdIndex;
}
- (NSMutableDictionary *)streamNoIndex {
    if (!_streamNoIndex) _streamNoIndex = [NSMutableDictionary dictionary];
    return _streamNoIndex;
}

- (void)dealloc {
    NSLog(@"[WKMessageList dealloc]");
}

@end
