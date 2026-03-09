//
//  WKPinnedMessageManager.m
//  WuKongIMSDK
//
//  Created by tt on 2024/5/22.
//

#import "WKPinnedMessageManager.h"
#import "WKPinnedMessageDB.h"
#import "WKMessageDB.h"

@interface WKPinnedMessageManager ()

/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

@end

@implementation WKPinnedMessageManager


static WKPinnedMessageManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKPinnedMessageManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(NSArray<WKMessage*>*) getPinnedMessagesByChannel:(WKChannel*)channel {
    NSArray<WKPinnedMessage*> *pinnedMessages = [WKPinnedMessageDB.shared getPinnedMessagesByChannel:channel];
    if(pinnedMessages.count==0) {
        return nil;
    }
    NSMutableArray<NSNumber*> *messageIds = [NSMutableArray array];
    for (WKPinnedMessage *pinnedMessage in pinnedMessages) {
        [messageIds addObject:@(pinnedMessage.messageId)];
    }
   return [WKMessageDB.shared getMessagesWithMessageIDs:messageIds];
}

-(uint64_t) getMaxVersion:(WKChannel*)channel {
    
    return [WKPinnedMessageDB.shared getMaxVersion:channel];
}

-(void) deletePinnedByChannel:(WKChannel*)channel {
    [WKPinnedMessageDB.shared deletePinnedByChannel:channel];
    [self callOnDelegate:channel];
}

-(void) deletePinnedByMessageId:(uint64_t)messageId {
    WKPinnedMessage *pinnedMessage = [WKPinnedMessageDB.shared getPinnedMessageByMessageId:messageId];
    if(!pinnedMessage) {
        return;
    }
    [self callOnDelegate:pinnedMessage.channel];
}

-(void) addOrUpdatePinnedMessages:(NSArray<WKPinnedMessage*>*)messages {
    if(!messages || messages.count==0) {
        return;
    }
    
    NSMutableArray<WKChannel*> *channels = [NSMutableArray array];
    for (WKPinnedMessage *pinnedMessage in messages) {
        BOOL exist = false;
        for (WKChannel *channel in channels) {
            if([pinnedMessage.channel isEqual:channel]) {
                exist = true;
                break;
            }
        }
        if(!exist) {
            [channels addObject:pinnedMessage.channel];
        }
    }
    
    [WKPinnedMessageDB.shared addOrUpdatePinnedMessages:messages];
    
    for (WKChannel *channel in channels) {
        [self callOnDelegate:channel];
    }
    
}

-(BOOL) hasPinned:(uint64_t)messageId {
    
    return [WKPinnedMessageDB.shared hasPinned:messageId];
}

-(void) addDelegate:(id<WKPinnedMessageManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKPinnedMessageManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}


-(void) callOnDelegate:(WKChannel*)channel {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(pinnedMessageChange:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate pinnedMessageChange:channel];
                });
            }else {
                [delegate pinnedMessageChange:channel];
            }
        }
    }
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




@end
