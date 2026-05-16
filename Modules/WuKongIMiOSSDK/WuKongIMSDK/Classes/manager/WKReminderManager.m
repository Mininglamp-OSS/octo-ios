//
//  WKReminderManager.m
//  WuKongIMSDK
//
//  Created by tt on 2022/4/19.
//

#import "WKReminderManager.h"
#import "WKReminderDB.h"
#import "WKConversationDB.h"
#import "WKSDK.h"
#import "WKRetryManager.h"
#import "WKConversationManagerInner.h"
@interface WKReminderManager ()

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

@implementation WKReminderManager


static WKReminderManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKReminderManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(NSArray<WKReminder*>*) getReminders:(WKReminderType)reminderType channel:(WKChannel*)channel {
    return  [[WKReminderDB shared] getWaitDoneReminders:channel type:reminderType];
}

-(void) sync {
    if(!self.reminderProvider) {
        NSLog(@"##########reminderProvider没有提供##########");
        return;
    }
    __weak typeof(self) weakSelf = self;
    self.reminderProvider(^(NSArray<WKReminder *> * _Nonnull reminders, NSError * _Nullable error) {
        if(error) {
            NSLog(@"同步提醒项失败！->%@",error);
            return;
        }
        if(!reminders ||reminders.count == 0) {
            return;
        }
        NSMutableSet *sets = [[NSMutableSet alloc] init];
        for (WKReminder *reminder in reminders) {
            [sets addObject:reminder.channel];
        }
        [[WKReminderDB shared] addOrUpdates:reminders];
        [weakSelf updateConversations:sets];
        
    });
}

-(void) done:(NSArray<NSNumber*>*)ids {
    if(!ids || ids.count==0) {
        return;
    }
    if(!self.reminderDoneProvider) {
        NSLog(@"##########reminderDoneProvider没有提供##########");
        return;
    }
    
    NSArray<WKReminder*> *reminders = [[WKReminderDB shared] getReminders:ids];
    if(!reminders || reminders.count == 0) {
        return;
    }
    
    [[WKReminderDB shared] updateDone:ids];
    NSMutableSet *sets = [[NSMutableSet alloc] init];
    for (WKReminder *reminder in reminders) {
        [sets addObject:reminder.channel];
        [[WKRetryManager shared] addReminder:reminder];
    }
    [self updateConversations:sets];
    
    self.reminderDoneProvider(ids, ^(NSError * _Nullable error) {
        if(!error) {
            for (NSNumber *idI in ids) {
                NSString *key = idI.stringValue;
                [[WKRetryManager shared] removeReminderRetryItem:key];
            }
        }
    });
    
}

-(void) updateConversations:(NSSet<WKChannel*>*)channels {
    NSMutableArray *channelArray = [NSMutableArray array];
    for (WKChannel *channel in channels) {
        [channelArray addObject:channel];
    }
    NSDictionary<WKChannel*,NSArray<WKReminder*>*> *reminderDict = [[WKReminderDB shared] getWaitDoneReminders:channelArray];
    if(!reminderDict) {
        reminderDict = [NSMutableDictionary dictionary];
    }
   
    NSArray<WKConversation*> *conversations = [[WKConversationDB shared] getConversations:channelArray];
    if(!conversations||conversations.count ==0) {
        return;
    }
    for (WKConversation *conversation in conversations) {
        conversation.reminders = reminderDict[conversation.channel];
        [self callRemindersDidChangeDelegate:conversation.channel reminders:conversation.reminders];
    }
    [[WKSDK shared].conversationManager callOnConversationUpdateDelegates:conversations];
    
    
    
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

- (void)callRemindersDidChangeDelegate:(WKChannel*)channel reminders:(NSArray<WKReminder*>*) reminders {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(reminderManager:didChange:reminders:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate reminderManager:self didChange:channel reminders:reminders];
                });
            }else {
                [delegate reminderManager:self didChange:channel reminders:reminders];
            }
        }
    }
}

@end
