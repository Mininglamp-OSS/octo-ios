//
//  WKCMDManager.m
//  WuKongIMSDK
//
//  Created by tt on 2020/10/7.
//

#import "WKCMDManager.h"
#import "WKSDK.h"
#import "WKCMDDB.h"
@interface WKCMDManager ()

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
@implementation WKCMDManager



-(void) pullCMDMessages {
   
    if(![WKSDK shared].offlineMessagePull) {
        NSLog(@"警告：离线CMD消息提供者没有设置！[WKSDK setOfflineMessageProvider:(WKOfflineMessagePull) offlineMessageCallback offlineMessagesAck:(WKOfflineMessageAck) offlineMessageAckCallback]");
        return;
    }
    // 获取消息表里的最大messageSeq
    uint32_t maxMessageSeq = [[WKCMDDB shared] getMaxMessageSeq];
    __weak typeof(self) weakSelf = self;
    [WKSDK shared].offlineMessagePull((int)[WKSDK shared].options.offlineMessageLimit, maxMessageSeq, ^(NSArray<WKMessage *> * _Nullable messages, bool more,NSError *error) {
        if(error) {
            // 如果拉取离线消息发生错误 则休息3秒再拉取
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                [weakSelf pullCMDMessages];
            });
            return;
        }
        if(!messages || messages.count<=0) { // 如果没有拉取到离线消息，完成离线拉取
            if([WKSDK shared].isDebug) {
                NSLog(@"离线cmd拉取完成！");
            }
           [weakSelf finishedPullOffline];
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSArray<WKMessage*> *newMessages = [messages copy];
            // 处理消息
            [weakSelf handleCMDMessages:newMessages];
            // 离线消息ack回执
            [WKSDK shared].offlineMessageAck(newMessages[newMessages.count-1].messageSeq,^(NSError *error){
                if(error) {
                    NSLog(@"WARN: 离线cmd ack失败！-> %@",error);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                        [weakSelf pullCMDMessages];
                    });
                }else {
                    if(more) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                            [weakSelf pullCMDMessages];
                        });
                    }else {
                        if([WKSDK shared].isDebug) {
                            NSLog(@"离线cmd 拉取完成！");
                        }
                        [weakSelf finishedPullOffline];
                    }
                }
                
            });
        });
    });
}

-(void) finishedPullOffline {
    
}

-(void) handleCMDMessages:(NSArray<WKMessage*>*)messages{
    if(!messages || messages.count<=0) {
        return;
    }
    // 存储消息
    NSArray *cmdMessages = [self mergeCMDMessages:[self toCMDMessages:messages]];
    [[WKCMDDB shared] replaceCMDMessages:cmdMessages];
    NSMutableArray *ids = [NSMutableArray array];
    cmdMessages = [[WKCMDDB shared] queryAllCMDMessages];
    if (cmdMessages && cmdMessages.count>0) {
        for (WKCMDMessage *cmdMessage in cmdMessages) {
            [ids addObject:@(cmdMessage.mid)];
        }
       
    }
    cmdMessages = [self mergeCMDMessages:cmdMessages];
    
    for (WKCMDMessage *cmdMessage in cmdMessages) {
        WKCMDModel *cmdModel = [WKCMDModel cmdMessage:cmdMessage];
        NSDictionary *param = [NSJSONSerialization JSONObjectWithData:[cmdMessage.param dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
        cmdModel.param = param;
        [self callOnCMDDelegate:cmdModel];
    }
    [[WKCMDDB shared] deleteCMDMessagesWithIDs:ids];
}

// 合并cmd消息
-(NSArray*) mergeCMDMessages:(NSArray<WKCMDMessage*>*)messages {
    if(!messages) {
        return @[];
    }
    
    NSMutableArray *newCMDMessages = [NSMutableArray array];
    for (NSInteger i=0;i<messages.count;i++) {
        BOOL same = false;
        for (NSInteger j=i+1;j<messages.count;j++) {
            if([messages[i] same:messages[j]]) {
                same = true;
                break;
            }
        }
        if(!same) {
            [newCMDMessages addObject:messages[i]];
        }
    }
    return newCMDMessages;
}

-(NSArray<WKCMDMessage*>*) toCMDMessages:(NSArray<WKMessage*>*) messages {
    if(!messages) {
        return @[];
    }
    NSMutableArray *cmdMessages = [NSMutableArray array];
    for (WKMessage *message in messages) {
        if(message.contentType != WK_CMD) {
            NSLog(@"warn: 不是cmd消息，不能进行cmd逻辑！-> %ld",(long)message.contentType);
            continue;
        }
        WKCMDMessage *cmdMessage = [WKCMDMessage new];
        cmdMessage.messageId = message.messageId;
        cmdMessage.messageSeq = message.messageSeq;
        cmdMessage.clientMsgNo = message.clientMsgNo;
        cmdMessage.timestamp = message.timestamp;
        if(message.content && message.content.contentDict) {
           NSString *cmd =  message.content.contentDict[@"cmd"];
            NSString *paramStr = @"";
            NSMutableDictionary *newParam = [NSMutableDictionary dictionary];
            if(message.content.contentDict[@"param"]) {
                [newParam addEntriesFromDictionary:message.content.contentDict[@"param"]];
            }
            if(!newParam[@"channel_id"] || [newParam[@"channel_id"] isEqualToString:@""]) {
                if(message.channel && ![message.channel.channelId isEqualToString:@""]) {
                    newParam[@"channel_id"] = message.channel.channelId;
                    newParam[@"channel_type"] = @(message.channel.channelType);
                }
            }
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:newParam options:kNilOptions error:nil];
            paramStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            cmdMessage.cmd =cmd;
            cmdMessage.param = paramStr;
            [cmdMessages addObject:cmdMessage];
        }
    }
    return cmdMessages;
   
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


-(void) addDelegate:(id<WKCMDManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKCMDManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

-(void) callOnCMDDelegate:(WKCMDModel*)model {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(cmdManager:onCMD:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate cmdManager:self onCMD:model];
                });
            }else {
                [delegate cmdManager:self onCMD:model];
            }
        }
    }
}

@end
