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

/**
 *  dictLock 用于保护 channelTypingMessageDict / cancelTypingBlockDict 的读写。
 *  超时 timer 现已挂在后台队列(见 addTypingByMessage)，回调会从后台线程访问这两个
 *  dict，无锁访问 NSMutableDictionary 在多群并发 typing 时会崩溃，故统一加锁。
 */
@property(nonatomic,strong) NSObject *dictLock;

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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 提前初始化共享状态，保证后台 timer 回调与主线程访问看到的是同一份 dict / lock。
        _channelTypingMessageDict = [[NSMutableDictionary alloc] init];
        _cancelTypingBlockDict = [[NSMutableDictionary alloc] init];
        _dictLock = [[NSObject alloc] init];
        // 监听 conversation-sync 落库通知：后台期间 bot 回复经同步直写 DB 绕过
        // onRecvMessages，导致 typing 卡死，这里收到通知后清除对应 channel 的 typing。
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onConversationSyncedNewMessages:)
                                                     name:@"WKConversationSyncedNewMessages"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onConversationSyncedNewMessages:(NSNotification *)notification {
    WKChannel *channel = notification.object;
    if (![channel isKindOfClass:[WKChannel class]]) {
        return;
    }
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeTypingByChannel:channel newMessage:nil];
        });
    } else {
        [self removeTypingByChannel:channel newMessage:nil];
    }
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

- (NSObject *)dictLock {
    if (_dictLock == nil) {
        _dictLock = [[NSObject alloc] init];
    }
    return _dictLock;
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
    WKMessage *message = nil;
    @synchronized (self.dictLock) {
        message = self.channelTypingMessageDict[channel];
    }
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
    __weak typeof(self) weakSelf = self;
    BOOL isNewTyping = NO;
    @synchronized (self.dictLock) {
        WKMessage *oldTypingMessage = self.channelTypingMessageDict[channel];
        self.channelTypingMessageDict[channel] = typingMessage;
        isNewTyping = (oldTypingMessage == nil);

        dispatch_block_t oldCancelBlock = self.cancelTypingBlockDict[channel];
        if(oldCancelBlock) {
            dispatch_block_cancel(oldCancelBlock);
        }
        // timer 改挂后台队列，避免 App 进后台时 main queue 挂起导致 8s 超时冻结，
        // 切回前台后 typing 卡死不消失。回调内按时间戳判定是否过期再清除。
        dispatch_block_t cancelTypingBlock = dispatch_block_create(0, ^{
            WKMessage *cur = nil;
            @synchronized (weakSelf.dictLock) {
                cur = weakSelf.channelTypingMessageDict[channel];
            }
            if (cur && ([[NSDate date] timeIntervalSince1970] - cur.timestamp >= 8.0)) {
                [weakSelf removeTypingByChannel:channel newMessage:nil];
            }
        });
        self.cancelTypingBlockDict[channel] = cancelTypingBlock;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), cancelTypingBlock);
    }
    if(isNewTyping) {
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
    @synchronized (self.dictLock) {
        return [self.channelTypingMessageDict allValues];
    }
}

- (WKMessage *)getTypingMessage:(WKChannel *)channel {
    @synchronized (self.dictLock) {
        return self.channelTypingMessageDict[channel];
    }
}


- (void)removeTypingByChannel:(WKChannel *)channel newMessage:(WKMessage*)newMessage{
    WKMessage *message = nil;
    @synchronized (self.dictLock) {
        message = [self.channelTypingMessageDict objectForKey:channel];
        if(message) {
            [self.channelTypingMessageDict removeObjectForKey:channel];
            dispatch_block_t cancelBlock = self.cancelTypingBlockDict[channel];
            if(cancelBlock) {
                dispatch_block_cancel(cancelBlock);
                [self.cancelTypingBlockDict removeObjectForKey:channel];
            }
        }
    }
    if(message) {
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
                dispatch_async(dispatch_get_main_queue(), ^{
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
                dispatch_async(dispatch_get_main_queue(), ^{
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate typingRemove:self message:message newMessage:newMessage];
                });
            }else {
                [delegate typingRemove:self message:message newMessage:newMessage];
            }
        }
    }
}

@end
