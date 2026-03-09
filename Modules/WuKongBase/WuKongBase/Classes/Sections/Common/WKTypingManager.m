//
//  WKTypingManager.m
//  WuKongBase
//
//  Created by tt on 2020/8/13.
//

#import "WKTypingManager.h"
#import "WKTypingContent.h"
#import "WKApp.h"
@interface WKTypingManager ()
/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

@property(nonatomic,strong) NSMutableDictionary<WKChannel*,WKMessage*> *channelTypingMessageDict;

@property(nonatomic,strong) NSMutableDictionary<WKChannel*,dispatch_block_t> *cancelTypingBlockDict; // 取消输入中状态的的block

@property(nonatomic,assign) BOOL offTyping; // 是否关闭typing
@end

@implementation WKTypingManager

static WKTypingManager *_instance = nil;

+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

- (NSMutableDictionary<WKChannel *,WKMessage *> *)channelTypingMessageDict {
    if(!_channelTypingMessageDict) {
        _channelTypingMessageDict = [[NSMutableDictionary alloc] init];
    }
    return _channelTypingMessageDict;
}

- (NSMutableDictionary<WKChannel *,dispatch_block_t> *)cancelTypingBlockDict {
    if(!_cancelTypingBlockDict) {
        _cancelTypingBlockDict = [[NSMutableDictionary alloc] init];
    }
    return _cancelTypingBlockDict;
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

-(void) addDelegate:(id<WKTypingManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKTypingManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

-(BOOL) hasTyping:(WKChannel*)channel {
    WKMessage *message = self.channelTypingMessageDict[channel];
    if(message) {
        return true;
    }
    return false;
}

- (void)addTypingByMessage:(WKMessage *)typingMessage {
    
//    WKMessage *typingMessage = [self convertMessageToTypingMessage:message];
    if( [typingMessage.fromUid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return;
    }
    
    WKChannel *channel = typingMessage.channel;
    WKMessage *oldTypingMessage = self.channelTypingMessageDict[channel];
    self.channelTypingMessageDict[channel] = typingMessage;
    
    dispatch_block_t cancelTypingBlock = self.cancelTypingBlockDict[channel];
     if(cancelTypingBlock) {
         dispatch_block_cancel(cancelTypingBlock);
     }
     __weak typeof(self) weakSelf = self;
     cancelTypingBlock = dispatch_block_create(0, ^{
         [weakSelf removeTypingByChannel:channel newMessage:nil];
     });
     self.cancelTypingBlockDict[channel] = cancelTypingBlock;
     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(),cancelTypingBlock);
    if(!oldTypingMessage) {
        [self callTypingAddDelegate:typingMessage];
    }
     
    
}

-(WKMessage*) convertParamToTypingMessage:(NSDictionary*)param {
    NSString *channelID = param[@"channel_id"];
    NSString *fromUID = param[@"from_uid"];
    NSString *fromName = param[@"from_name"];
    NSInteger channelType = [param[@"channel_type"] integerValue];
    
    WKMessage *typingMessage = [[WKMessage alloc] init];
    WKMessageHeader *header = [[WKMessageHeader alloc] init];
    header.showUnread = false;
    header.noPersist = YES;
    typingMessage.clientMsgNo = [[NSUUID UUID] UUIDString];
//    typingMessage.clientSeq = 1;
    typingMessage.header = header;
    typingMessage.messageId = 1234567;
//    typingMessage.messageSeq = message.messageSeq;
    typingMessage.timestamp = [[NSDate date] timeIntervalSince1970];
//    typingMessage.localTimestamp = message.localTimestamp;
    typingMessage.fromUid = fromUID;
    typingMessage.channel = [[WKChannel alloc] initWith:channelID channelType:channelType];
    
    WKTypingContent *content = [[WKTypingContent alloc] init];
    content.typingUID = fromUID;
    content.typingName = fromName;
    typingMessage.content = content;
    
    typingMessage.contentType = [WKTypingContent contentType].integerValue;
    return typingMessage;
}

- (NSArray<WKMessage *> *)getAllTypingMessages {
    
    return [self.channelTypingMessageDict allValues];
}

- (WKMessage *)getTypingMessage:(WKChannel *)channel {
    
    return self.channelTypingMessageDict[channel];
}


- (void)removeTypingByChannel:(WKChannel *)channel newMessage:(WKMessage*)newMessage{
    WKMessage *message = [self.channelTypingMessageDict objectForKey:channel];
    if(message) {
        [self.channelTypingMessageDict removeObjectForKey:channel];
        [self callTypingRemoveDelegate:message newMessage:newMessage];
    }
}

- (void)callTypingAddDelegate:(WKMessage*)message {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(typingAdd:message:)]) {
            if (![NSThread isMainThread]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [delegate typingAdd:self message:message];
                });
            }else {
                [delegate typingAdd:self message:message];
            }
        }
    }
}

- (void)callTypingReplaceDelegate:(WKMessage*)newmessage oldMessage:(WKMessage*)oldMessage {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(typingReplace:newmessage:oldmessage:)]) {
            if (![NSThread isMainThread]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [delegate typingReplace:self newmessage:newmessage oldmessage:oldMessage];
                });
            }else {
               [delegate typingReplace:self newmessage:newmessage oldmessage:oldMessage];
            }
        }
    }
}

- (void)callTypingRemoveDelegate:(WKMessage*)message newMessage:(WKMessage*)newMessage{
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(typingRemove:message:newMessage:)]) {
            if (![NSThread isMainThread]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [delegate typingRemove:self message:message newMessage:newMessage];
                });
            }else {
                [delegate typingRemove:self message:message newMessage:newMessage];
            }
        }
    }
}

@end
