//
//  WKRetryManager.m
//  WuKongIMBase
// 消息重试管理
//  Created by tt on 2019/12/29.
//

#import "WKRetryManager.h"
#import "WKSDK.h"
#import "WKMessageDB.h"
#import "WKChatManager.h"
#import "WKMessageExtraDB.h"
#import "WKReminderDB.h"
@implementation WKRetryItem


@end

@interface WKRetryManager ()

@property(nonatomic,strong) NSMutableDictionary<NSString*,WKRetryItem*> *retryDict;
@property(nonatomic,strong) NSMutableDictionary<NSString*,WKRetryItem*> *messageExtraRetryDict;
@property(nonatomic,strong) NSMutableDictionary<NSString*,WKRetryItem*> *reminderRetryDict;
@property(nonatomic,strong) NSLock *retryLock;
@property(nonatomic,strong) NSTimer *retryTimer;
@property(nonatomic,strong) NSTimer *messageExtraRetryTimer;
@property(nonatomic,strong) NSTimer *reminderRetryTimer;
@property(nonatomic,strong) NSTimer *expireMsgCheckTimer;

@property(nonatomic,assign) BOOL started; // 是否已开始

@end
@implementation WKRetryManager


static WKRetryManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKRetryManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) add:(WKMessage*)message {
    if(message.clientSeq == 0 || !message.clientMsgNo||[message.clientMsgNo isEqualToString:@""]) {
        NSLog(@"消息clientSeq为0 不能添加到重试队列里！");
        return;
    }
    NSString *key= [self getKey:message];
    
    WKRetryItem *item = [[WKRetryItem alloc] init];
    item.message = message;
    item.retryCount = 0;
    item.nextRetryTime = [[NSDate date] timeIntervalSince1970] + [WKSDK shared].options.messageRetryInterval;
    
    [self.retryLock lock];
    self.retryDict[key] = item;
    [self.retryLock unlock];
}

-(void) addMessageExtra:(WKMessageExtra*)messageExtra {
    if(!messageExtra.isEdit || messageExtra.uploadStatus != WKContentEditUploadStatusWait) {
        return;
    }
    NSString *key = [NSString stringWithFormat:@"%llu",messageExtra.messageID];
    
    WKRetryItem *item = [[WKRetryItem alloc] init];
    item.messageExtra = messageExtra;
    item.retryCount = 0;
    item.nextRetryTime = [[NSDate date] timeIntervalSince1970] + [WKSDK shared].options.messageRetryInterval;
    
    [self.retryLock lock];
    self.messageExtraRetryDict[key] = item;
    [self.retryLock unlock];
}

-(void) addReminder:(WKReminder*)reminder {
    if(reminder.uploadStatus != WKReminderUploadStatusWait) {
        return;
    }
    NSString *key = [NSString stringWithFormat:@"%lld",reminder.reminderID];
    WKRetryItem *item = [[WKRetryItem alloc] init];
    item.reminder = reminder;
    item.retryCount = 0;
    item.nextRetryTime = [[NSDate date] timeIntervalSince1970] + [WKSDK shared].options.messageRetryInterval;
    [self.retryLock lock];
    self.reminderRetryDict[key] = item;
    [self.retryLock unlock];
}

-(NSString*) getKey:(WKMessage*)message {
    NSString *key=[NSString stringWithFormat:@"%u",message.clientSeq];
    return key;
}

-(void) start {
    if(self.started) {
        return;
    }
    self.started = true;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [weakSelf startMessageRetry];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [weakSelf startMessageExtraRetry];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [weakSelf startReminderRetry];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [weakSelf startReminderRetry];
    });
    
    self.expireMsgCheckTimer = [NSTimer scheduledTimerWithTimeInterval:WKSDK.shared.options.expireMsgCheckInterval target:self selector:@selector(startExpireMsgCheck) userInfo:nil repeats:YES];
}

-(void) stop {
    self.started = false;
    if(self.retryTimer) {
        [self.retryTimer invalidate];
        self.retryTimer = nil;
    }
    if(self.messageExtraRetryTimer) {
        [self.messageExtraRetryTimer invalidate];
        self.messageExtraRetryTimer = nil;
    }
    if(self.reminderRetryTimer) {
        [self.reminderRetryTimer invalidate];
        self.reminderRetryTimer = nil;
    }
    if(self.expireMsgCheckTimer) {
        [self.expireMsgCheckTimer invalidate];
        self.expireMsgCheckTimer = nil;
    }
}

-(void) startExpireMsgCheck {
   NSArray<WKMessage*> *messages = [WKMessageDB.shared getExpireMessages:WKSDK.shared.options.expireMsgLimit];
    if(messages && messages.count>0) {
        for (WKMessage *message in messages) {
            [WKSDK.shared.chatManager deleteMessage:message];
        }
        
    }
}

-(void) startMessageRetry {
    // 将上传中的消息状态变为失败
     [[WKMessageDB shared] updateMessageUploadingToFailStatus];
    
    // 将待发送的消息修改为发送失败
    [self.retryLock lock];
    [self.retryDict removeAllObjects];
     [self.retryLock unlock];
    NSArray<WKMessage*> *messages = [[WKMessageDB shared] getMessagesWaitSend];
    if(messages && messages.count>0) {
        NSInteger i =messages.count - 1;
        for (WKMessage *message in messages) {
            if(message.localTimestamp + [WKSDK shared].options.messageRetryInterval*[WKSDK shared].options.messageRetryCount > [[NSDate date] timeIntervalSince1970] ) {
//                [[WKRetryManager shared] add:message];
                 [[[WKSDK shared] chatManager] sendMessage:message addRetryQueue:true];
            }else {
                // 更新消息状态 c为失败
                 message.status =WK_MESSAGE_FAIL;
                 [[WKMessageDB shared] updateMessageStatus:WK_MESSAGE_FAIL withClientSeq:message.clientSeq];
                 // 通知上层
                 [[WKSDK shared].chatManager callMessageUpdateDelegate:message left:i total:messages.count];
            }
            i--;
        }
    }
    
    NSTimeInterval retryInterval = [WKSDK shared].options.messageRetryInterval/2.0f;
    if(retryInterval<=0) {
        retryInterval = 1.0f;
    }
    if(self.retryTimer) {
        [self.retryTimer invalidate];
        self.retryTimer = nil;
    }
    // 定时器必须在主线程才能执行
     __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.retryTimer = [NSTimer scheduledTimerWithTimeInterval:retryInterval target:weakSelf selector:@selector(retrySend) userInfo:nil repeats:YES];
    });
   
}

-(void) startMessageExtraRetry {
    // 将上传中的消息状态变为失败
     [[WKMessageExtraDB shared] updateContentEditUploadStatusToFailStatus];
    [self.retryLock lock];
    [self.messageExtraRetryDict removeAllObjects];
    [self.retryLock unlock];
    
    NSArray<WKMessageExtra*> *messageExtras = [[WKMessageExtraDB shared] getContentEditWaitUpload];
    if(messageExtras && messageExtras.count>0) {
        for (WKMessageExtra *messageExtra in messageExtras) {
            if(messageExtra.editedAt + [WKSDK shared].options.contentEditRetryInterval*[WKSDK shared].options.contentEditRetryCount > [[NSDate date] timeIntervalSince1970] ) {
                [self addMessageExtra:messageExtra];
            }else{ // 超时
                [[WKMessageExtraDB shared] updateUploadStatus:WKContentEditUploadStatusError withMessageID:messageExtra.messageID];
                
                WKMessage *message = [[WKMessageDB shared] getMessageWithMessageId:messageExtra.messageID];
                 if(message) {
                     [[WKSDK shared].chatManager callMessageUpdateDelegate:message];
                 }
            }
        }
    }
    
    NSTimeInterval retryInterval = [WKSDK shared].options.contentEditRetryInterval/2.0f;
    if(retryInterval<=0) {
        retryInterval = 1.0f;
    }
    if(self.messageExtraRetryTimer) {
        [self.messageExtraRetryTimer invalidate];
        self.messageExtraRetryTimer = nil;
    }
    // 定时器必须在主线程才能执行
     __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.messageExtraRetryTimer = [NSTimer scheduledTimerWithTimeInterval:retryInterval target:weakSelf selector:@selector(contentEditRetryUpload) userInfo:nil repeats:YES];
    });
}

// 提示数据上传
-(void) startReminderRetry {
    NSInteger expire =  [[NSDate date] timeIntervalSince1970] - [WKSDK shared].options.reminderDoneUploadExpire;
    [[WKReminderDB shared] updateExpireDoneUploadStatusFail:expire];
    [self.retryLock lock];
    [self.reminderRetryDict removeAllObjects];
    [self.retryLock unlock];
    
    NSArray<WKReminder*> *reminders = [[WKReminderDB shared] getWaitUploads];
    if(reminders && reminders.count>0) {
        for (WKReminder *reminder in reminders) {
            [self addReminder:reminder];
        }
    }
    NSTimeInterval retryInterval = [WKSDK shared].options.reminderRetryInterval/2.0f;
    if(retryInterval<=0) {
        retryInterval = 1.0f;
    }
    if(self.reminderRetryTimer) {
        [self.reminderRetryTimer invalidate];
        self.reminderRetryTimer = nil;
    }
    // 定时器必须在主线程才能执行
     __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.reminderRetryTimer = [NSTimer scheduledTimerWithTimeInterval:retryInterval target:weakSelf selector:@selector(reminderUpload) userInfo:nil repeats:YES];
    });
}


-(void) reminderUpload {
    [self.retryLock lock];
    NSArray *keys = self.reminderRetryDict.allKeys;
    [self.retryLock unlock];
    
    for (NSString *key  in keys) {
        [self.retryLock lock];
        WKRetryItem *item =  self.reminderRetryDict[key];
        [self.retryLock unlock];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        // 如果重试次数小于目标重试次数并且满足重试时间，则重试
        if(item && item.retryCount<[WKSDK shared].options.reminderRetryCount) {
            if((now - item.nextRetryTime)>=0) {
                if([WKSDK shared].isDebug) {
                    NSLog(@"重试上传提醒项  key:[%@] retryCount: [%ld] nextRetryTime: [%ld]",key,item.retryCount,item.nextRetryTime);
                }
                item.retryCount++;
                item.nextRetryTime =now+[WKSDK shared].options.reminderRetryInterval;
                [self uploadReminder:item.reminder];
            }
        }
    }
}

-(void) contentEditRetryUpload {
    [self.retryLock lock];
    NSArray *keys = self.messageExtraRetryDict.allKeys;
    [self.retryLock unlock];
    
    for (NSString *key  in keys) {
        [self.retryLock lock];
        WKRetryItem *item =  self.messageExtraRetryDict[key];
        [self.retryLock unlock];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        
        // 如果重试次数小于目标重试次数并且满足重试时间，则重试
        if(item && item.retryCount<[WKSDK shared].options.contentEditRetryCount) {
            if(item.retryCount<[WKSDK shared].options.contentEditRetryCount ) {
                if((now - item.nextRetryTime)>=0) {
                    if([WKSDK shared].isDebug) {
                        NSLog(@"重试上传编辑正文  key:[%@] retryCount: [%ld] nextRetryTime: [%ld]",key,item.retryCount,item.nextRetryTime);
                    }
                    item.retryCount++;
                    item.nextRetryTime =now+[WKSDK shared].options.contentEditRetryInterval;
                    [self uploadContentEdit:item.messageExtra];
                }
            }
        }
    }
}

-(void) uploadReminder:(WKReminder*)reminder {
    if(![WKSDK shared].reminderManager.reminderDoneProvider) {
        return;
    }
    [WKSDK shared].reminderManager.reminderDoneProvider(@[@(reminder.reminderID)], ^(NSError * _Nullable error) {
        if(error) {
            [[WKReminderDB shared] updateUploadStatus:WKReminderUploadStatusError reminderID:@(reminder.reminderID)];
        }else {
            NSString *key = [NSString stringWithFormat:@"%llu",reminder.reminderID];
            [self removeReminderRetryItem:key];
            [[WKReminderDB shared] updateUploadStatus:WKReminderUploadStatusSuccess reminderID:@(reminder.reminderID)];
        }
    });
}

-(void) uploadContentEdit:(WKMessageExtra*)extra {
    if(![WKSDK shared].chatManager.messageEditProvider) {
        return;
    }
    if(!extra.isEdit || !extra.contentEditData || [extra.contentEditData length] == 0) {
        return;
    }
    [WKSDK shared].chatManager.messageEditProvider(extra, ^(NSError * _Nullable error) {
        if(error) {
            [[WKMessageExtraDB shared] updateUploadStatus:WKContentEditUploadStatusError withMessageID:extra.messageID];
        }else {
            NSString *key = [NSString stringWithFormat:@"%llu",extra.messageID];
            [self removeMessageExtraRetryItem:key];
            [[WKMessageExtraDB shared] updateUploadStatus:WKContentEditUploadStatusSuccess withMessageID:extra.messageID];
        }
       WKMessage *message = [[WKMessageDB shared] getMessageWithMessageId:extra.messageID];
        if(message) {
            [[WKSDK shared].chatManager callMessageUpdateDelegate:message];
        }
       
    });
}

-(void) retrySend{
    [self.retryLock lock];
    NSArray *keys = self.retryDict.allKeys;
    [self.retryLock unlock];
    for (NSString *key  in keys) {
        [self.retryLock lock];
        WKRetryItem *item =  self.retryDict[key];
        [self.retryLock unlock];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        // 如果重试次数小于目标重试次数并且满足重试时间，则重试
        if(!item) continue;
        if(item.retryCount<[WKSDK shared].options.messageRetryCount ) {
            if((now - item.nextRetryTime)>=0) {
                if([WKSDK shared].isDebug) {
                    NSLog(@"重发消息  key:[%@] retryCount: [%ld] nextRetryTime: [%ld]",key,item.retryCount,item.nextRetryTime);
                }
                item.retryCount++;
                item.nextRetryTime =now+[WKSDK shared].options.messageRetryInterval;
                [[[WKSDK shared] chatManager] sendMessage:item.message addRetryQueue:false];
            }
        }else { // 超过重试次数 消息状态设置为发送失败
            [self.retryLock lock];
            [self.retryDict removeObjectForKey:key];
            [self.retryLock unlock];
            // 更新消息状态为失败
            item.message.status =WK_MESSAGE_FAIL;
            [[WKMessageDB shared] updateMessageStatus:WK_MESSAGE_FAIL withClientSeq:item.message.clientSeq];
           
            // 通知上层
            [[WKSDK shared].chatManager callMessageUpdateDelegate:item.message];
        }
    }
}

// TODO: retrySend如果执行时间过长 removeRetryItem会出现阻塞情况 (待观察)
-(void) removeRetryItem:(NSString*) key {
    [self.retryLock lock];
    [self.retryDict removeObjectForKey:key];
    [self.retryLock unlock];
}

-(void) removeMessageExtraRetryItem:(NSString*) key {
    [self.retryLock lock];
    [self.messageExtraRetryDict removeObjectForKey:key];
    [self.retryLock unlock];
}

-(void) removeReminderRetryItem:(NSString*)key {
    [self.retryLock lock];
    [self.reminderRetryDict removeObjectForKey:key];
    [self.retryLock unlock];
}

-(NSLock*) retryLock {
    if(!_retryLock) {
        _retryLock = [[NSLock alloc] init];
    }
    return _retryLock;
}

-(NSMutableDictionary*)retryDict {
    if(!_retryDict) {
        _retryDict = [[NSMutableDictionary alloc] init];
    }
    return _retryDict;
}

- (NSMutableDictionary<NSString *,WKRetryItem *> *)messageExtraRetryDict {
    if(!_messageExtraRetryDict) {
        _messageExtraRetryDict = [[NSMutableDictionary alloc] init];
    }
    return _messageExtraRetryDict;
}

- (NSMutableDictionary<NSString *,WKRetryItem *> *)reminderRetryDict {
    if(!_reminderRetryDict) {
        _reminderRetryDict = [[NSMutableDictionary alloc] init];
    }
    return _reminderRetryDict;
}


@end
