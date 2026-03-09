//
//  WKReactionManager.m
//  WuKongIMSDK
//
//  Created by tt on 2021/9/13.
//

#import "WKReactionManager.h"
#import "WKReactionDB.h"
#import "WKMessageDB.h"
@interface WKReactionManager ()

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

@implementation WKReactionManager

static WKReactionManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKReactionManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) addOrCancelReaction:(NSString*)reactionName messageID:(uint64_t)messageID complete:(void(^)(NSError *error))complete{
    if(!self.addOrCancelReactionProvider) {
        NSLog(@"没有设置addOrCancelReactionProvider，忽略添加或取消回应！");
        return;
    }
    WKMessage *message =  [[WKMessageDB shared] getMessageWithMessageId:messageID];
    if(!message) {
        NSLog(@"没有查询到消息！,不能回应");
        return;
    }
    self.addOrCancelReactionProvider(message.channel, messageID,reactionName, ^(NSError *error){
        if(error) {
            NSLog(@"回应返回失败！->%@",error);
        }
        if(complete) {
            complete(error);
        }
    });
}


-(void) sync:(WKChannel*)channel {
    if(!self.syncReactionsProvider) {
        NSLog(@"没有设置syncReactionsProvider，忽略同步！");
        return;
    }
    uint64_t version = [[WKReactionDB shared] maxVersion:channel];
    __weak typeof(self) weakSelf = self;
    self.syncReactionsProvider(channel, version, ^(NSArray<WKReaction *> * _Nullable reactions, NSError * _Nullable error) {
        if(error) {
            NSLog(@"同步回应失败！-> %@",error);
            return;
        }
        if(!reactions || reactions.count==0) {
            return;
        }
        
        [[WKReactionDB shared] insertOrUpdateReactions:reactions];
        
        [weakSelf callReactionManagerChangeDelegate:reactions channel:channel];
    });
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


- (void)callReactionManagerChangeDelegate:(NSArray<WKReaction *> *)reactions channel:(WKChannel*)channel {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(reactionManagerChange:reactions:channel:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate reactionManagerChange:self reactions:reactions channel:channel];
                });
            }else {
                [delegate reactionManagerChange:self reactions:reactions channel:channel];
            }
        }
    }
}

-(void) addDelegate:(id<WKReactionManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKReactionManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

@end
