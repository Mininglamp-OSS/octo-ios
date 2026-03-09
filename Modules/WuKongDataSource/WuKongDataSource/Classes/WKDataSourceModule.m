//
//  WKDataSourceModule.m
//  WuKongDataSource
//
//  Created by tt on 2019/12/27.
//

#import "WKDataSourceModule.h"
#import "WKFileUploadTask.h"
#import "WKFileDownloadTask.h"
#import "WKGroupManagerDelegateImp.h"
#import "WKMessageManagerDelegateImp.h"
#import <WuKongIMSDK/WKMOSContentConvertManager.h>
#import <WuKongIMSDK/WKReminderDB.h>
#import "WKChannelDataManagerDelegateImp.h"

@WKModule(WKDataSourceModule)

@interface WKDataSourceModule ()

@end

@implementation WKDataSourceModule



-(NSString*) moduleId {
    return @"WKDataSource";
}

// 模块初始化
- (void)moduleInit:(WKModuleContext*)context{
    NSLog(@"【WKDataSource】模块初始化！");
    // 设置频道资料更新函数
    [self setChannelInfoUpdate];
    // 离线消息提供者
    [self setOfflineMessageProvider];
    // 设置同步会话提供者
    [self setSyncConversationProvider];
    // 最近会话扩展
    [self setSyncConversationExtraProvider];
    [self setUpdateConversationExtraProvider];
    // 设置同步频道消息提供者
    [self setSyncChannelMessageProvider];
    // 扩展消息同步提供者
    [self setSyncMessageExtraProvider];
    // 设置消息扩展同步提供者
    // 设置上传任务提供者
    [self setUploadTaskProvider];
     // 设置下载任务提供者
    [self setDownloadTaskProvider];
    // 机器人提供者
    [self setRobotProvider];
  
    // 提醒项目提供者
    [self setReminderProvider];
    
    // 群相关接口
    [[WKGroupManager shared] setDelegate:[WKGroupManagerDelegateImp new]];
    // 消息管理
    [[WKMessageManager shared] setDelegate:[WKMessageManagerDelegateImp new]];
    
    [WKChannelDataManager.shared setDelegate:[WKChannelDataManagerDelegateImp new]];
    
}

// 模块启动
-(BOOL) moduleDidFinishLaunching:(WKModuleContext *)context{
    return true;
}


// 给狸猫SDK提供上传任务
-(void) setUploadTaskProvider {
    [[WKSDK shared].mediaManager setUploadTaskProvider:^id<WKTaskProto> _Nonnull(WKMessage * _Nonnull message) {
        return [[WKFileUploadTask alloc] initWithMessage:message];
    }];
    
}
// 给狸猫SDK提供下载任务
-(void) setDownloadTaskProvider {
    
    [[WKSDK shared].mediaManager setDownloadTaskProvider:^id<WKTaskProto> _Nonnull(WKMessage * _Nonnull message) {
        return [[WKFileDownloadTask alloc] initWithMessage:message];
    }];
}

  // 设置频道资料更新函数
-(void) setChannelInfoUpdate {
    
    
    [[WKSDK shared] setChannelInfoUpdate:^WKTaskOperator * (WKChannel * _Nonnull channel, WKChannelInfoCallback  _Nonnull callback) {
        
        NSURLSessionDataTask *sessionDataTask = [[WKAPIClient sharedClient] taskGET:[NSString stringWithFormat:@"channels/%@/%d",channel.channelId,channel.channelType] parameters:nil callback:^(NSError * _Nullable error, NSDictionary  *resultDict) {
            if(error) {
                WKLogError(@"获取频道信息失败！-> %@",error);
                callback(error,false);
                return;
            }
            WKChannelInfo *channelInfo  = [WKChannelUtil toChannelInfo2:resultDict];
            
            [[WKSDK shared].channelManager addOrUpdateChannelInfo:channelInfo];
            if(callback) {
                callback(nil,false);
            }
            
        }];
        return [WKTaskOperator cancel:^{
            if(sessionDataTask) {
                [sessionDataTask cancel];
            }
            
        } suspend:^{
            if(sessionDataTask) {
                [sessionDataTask suspend];
            }
        } resume:^{
            if(sessionDataTask) {
                [sessionDataTask resume];
            }
        }];
    }];
    
    
    return;
}

-(void) setUpdateConversationExtraProvider {
    [[WKSDK shared].conversationManager setUpdateConversationExtraProvider:^(WKConversationExtra * _Nonnull extra, WKUpdateConversationExtraCallback  _Nonnull callback) {
        [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"conversations/%@/%d/extra",extra.channel.channelId,extra.channel.channelType] parameters:@{
            @"keep_message_seq": @(extra.keepMessageSeq),
            @"keep_offset_y":@(extra.keepOffsetY),
            @"draft": extra.draft?:@"",
        }].then(^(NSDictionary *result){
            int64_t version = [result[@"version"] longLongValue];
            callback(version,nil);
        }).catch(^(NSError *error){
            callback(0,error);
        });
    }];
}

// 最近会话扩展提供者
-(void) setSyncConversationExtraProvider {
    
    [[WKSDK shared].conversationManager setSyncConversationExtraProvider:^(long long version, WKSyncConversationExtraCallback  _Nonnull callback) {
        [[WKAPIClient sharedClient] POST:@"conversation/extra/sync" parameters:@{
            @"version": @(version),
        }].then(^(NSArray *results){
            NSMutableArray<WKConversationExtra*> *extras = [NSMutableArray array];
            if(results && results.count>0) {
                for (NSDictionary *extraDict in results) {
                    [extras addObject:[self toConversationExtra:extraDict]];
                }
            }
            callback(extras,nil);
        }).catch(^(NSError *error){
            callback(nil,error);
        });
    }];
    
}



// 设置最近会话提供者
-(void) setSyncConversationProvider {
    [[WKSDK shared].conversationManager setSyncConversationProviderAndAck:^(long long version, NSString * _Nonnull lastMsgSeqs, WKSyncConversationCallback  _Nonnull callback) {
        [[WKAPIClient sharedClient] POST:@"conversation/sync" parameters:@{
            @"version": @(version),
            @"device_uuid": [WKApp shared].loginInfo.deviceUUID,
            @"last_msg_seqs": lastMsgSeqs?:@"",
            @"msg_count":@([WKApp shared].config.eachPageMsgLimit),
        }].then(^(NSDictionary* dict){
            
            // ---------- conversation  ----------
            NSArray<NSDictionary*>* conversationDicts = dict[@"conversations"];
            NSMutableArray<WKSyncConversationModel*> *syncConversationModels = [NSMutableArray array];
            if(conversationDicts && conversationDicts.count>0) {
                for (NSDictionary *conversationDict in conversationDicts) {
                    [syncConversationModels addObject:[self toSyncConversationModel:conversationDict]];
                }
            }
            
            WKSyncConversationWrapModel *wrapModel = [[WKSyncConversationWrapModel alloc] init];
            wrapModel.conversations = syncConversationModels;
            callback(wrapModel,nil);
        }).catch(^(NSError *err){
            callback(nil,err);
        });
    } ack:^(uint64_t cmdVersion, void (^ _Nullable complete)(NSError * _Nullable)) {
        [[WKAPIClient sharedClient] POST:@"conversation/syncack" parameters:@{
            @"cmd_version":@(cmdVersion),
            @"device_uuid": [WKApp shared].loginInfo.deviceUUID,
        }].then(^{
            complete(nil);
        }).catch(^(NSError *error){
            complete(error);
        });
        
    }];
}

-(void) setSyncChannelMessageProvider {
    
    [WKSDK.shared.chatManager setSyncChannelMessageProvider:^(WKChannel * _Nonnull channel, uint32_t startMessageSeq, uint32_t endMessageSeq, NSInteger limit, WKPullMode pullMode, WKSyncChannelMessageCallback  _Nonnull callback) {
        [[WKAPIClient sharedClient] POST:@"message/channel/sync" parameters:@{
            @"device_uuid": [WKApp shared].loginInfo.deviceUUID,
            @"channel_id":channel.channelId?:@"",
            @"channel_type": @(channel.channelType),
            @"start_message_seq": @(startMessageSeq),
            @"end_message_seq": @(endMessageSeq),
            @"limit": @(limit),
            @"pull_mode": @(pullMode),
        }].then(^(NSDictionary *dict){
            WKSyncChannelMessageModel *model = [WKSyncChannelMessageModel new];
            model.startMessageSeq = (uint32_t)[dict[@"start_message_seq"] unsignedLongLongValue];
            model.endMessageSeq = (uint32_t)[dict[@"end_message_seq"] unsignedLongLongValue];
            
            NSArray<NSDictionary*> *messageDicts = dict[@"messages"];
            if(messageDicts && messageDicts.count>0) {
                NSMutableArray *messages = [NSMutableArray array];
                for (NSDictionary *messageDict in messageDicts) {
                    [messages addObject:[WKMessageUtil toMessage:messageDict]];
                }
                model.messages = messages;
            }
            callback(model,nil);
            
        }).catch(^(NSError *err){
            callback(nil,err);
        });
    }];
}

// 设置离线消息提供者
-(void) setOfflineMessageProvider {
    // 离线消息提供者
    [[WKSDK shared] setOfflineMessageProvider:^(int limit, uint32_t messageSeq, WKOfflineMessageCallback  _Nonnull callback) {
        [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"message/sync"] parameters:@{@"max_message_seq":@(messageSeq),@"limit":@(limit)}].then(^(NSArray<NSDictionary*>* messageDicts){
            NSMutableArray *messages = [[NSMutableArray alloc] init];
            if(messageDicts && messageDicts.count>0) {
                for (NSDictionary *messageDict  in messageDicts) {
                    @try {
                         WKMessage *message =  [WKMessageUtil toMessage:messageDict];
                         if(message) {
                            [messages addObject:message];
                         }
                    } @catch (NSException *exception) {
                        WKLogError(@"转换离线消息时出现异常-%@",exception);
                    }
                   
                }
                callback(messages,true,nil); // 这里不能判断返回数据小于limit(count>=limit)就没有更多了, 因为有可能服务器遇到解析不出消息里的payload而服务器会丢掉此消息 这样返回数据小于limit但是服务器还有离线消息
            }else {
                callback(messages,false,nil);
            }
        }).catch(^(NSError *err){
            WKLogError(@"拉取离线消息失败！-> %@",err);
            callback(nil,false,err);
        });
    } offlineMessagesAck:^(uint32_t messageSeq, void (^ _Nonnull complete)(NSError *error)) {
        [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"message/syncack/%d",messageSeq] parameters:nil].then(^{
            if(complete) {
                complete(nil);
            }
        }).catch(^(NSError *err){
            WKLogError(@"离线消息回执失败！-> %@",err);
            if(complete) {
                complete(err);
            }
        });
    }];
}


-(void)  setSyncMessageExtraProvider {
//    __weak typeof(self) weakSelf = self;
    [[[WKSDK shared] chatManager] setSyncMessageExtraProvider:^(WKChannel * _Nonnull channel, long long extraVersion,NSInteger limit, WKSyncMessageExtraCallback  _Nonnull callback) {
        [[WKAPIClient sharedClient] POST:@"message/extra/sync" parameters:@{
            @"channel_id": channel.channelId?:@"",
            @"channel_type":@(channel.channelType),
            @"extra_version": @(extraVersion),
            @"limit": @(limit),
            @"source":[WKApp shared].loginInfo.deviceUUID?:@"",
        }].then(^(NSArray<NSDictionary*> *results){
            NSMutableArray<WKMessageExtra*> *messageExtras = [NSMutableArray array];
            for (NSDictionary *result in results) {
                [messageExtras addObject:[WKMessageUtil toMessageExtra:result channel:channel]];
            }
            callback(messageExtras,nil);
        }).catch(^(NSError *err){
            WKLogError(@"获取消息扩展失败！-> %@",err);
            callback(nil,err);
        });
    }];
}

-(void) setReminderProvider {
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].reminderManager setReminderProvider:^(WKReminderCallback  _Nonnull callback) {
        NSMutableArray *channelIDs = [NSMutableArray array];
        NSArray<WKConversation*> *conversations = [[WKSDK shared].conversationManager getConversationList];
        if(conversations && conversations.count>0) {
            for (WKConversation *conversation in conversations) {
                if(conversation.channel.channelType == WK_GROUP) {
                    [channelIDs addObject:conversation.channel.channelId];
                }
            }
        }
        int64_t maxVersion = [[WKReminderDB shared] getMaxVersion];
        [[WKAPIClient sharedClient] POST:@"message/reminder/sync" parameters:@{
            @"version":@(maxVersion),
            @"limit": @(1000),
            @"channel_ids": channelIDs,
        }].then(^(NSArray *results){
            if(results && results.count>0) {
                NSMutableArray<WKReminder*> *reminders = [NSMutableArray array];
                for (NSDictionary *result in results) {
                    [reminders addObject:[weakSelf toReminder:result]];
                }
                callback(reminders,nil);
            }
        }).catch(^(NSError *error){
            callback(nil,error);
        });
    }];
    
    [[WKSDK shared].reminderManager setReminderDoneProvider:^(NSArray<NSNumber *> * _Nonnull ids, WKReminderDoneCallback  _Nonnull callback) {
        [[WKAPIClient sharedClient] POST:@"message/reminder/done" parameters:ids].then(^{
            callback(nil);
        }).catch(^(NSError *error){
            callback(error);
        });
    }];
}


-(void) setRobotProvider {
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].robotManager setSyncRobotProvider:^(NSArray<NSDictionary *> * _Nonnull robotVersionDicts, WKSyncRobotCallback  _Nonnull callback) {
        [[WKAPIClient sharedClient] POST:@"robot/sync" parameters:robotVersionDicts].then(^(NSArray<NSDictionary*>*results){
            NSMutableArray<WKRobot*> *robots = [NSMutableArray array];
            if(results && results.count>0) {
                for (NSDictionary *result in results) {
                    [robots addObject:[weakSelf toRobot:result]];
                }
            }
            callback(robots,nil);
        }).catch(^(NSError *error){
            callback(nil,error);
        });
    }];
}

-(WKRobot*) toRobot:(NSDictionary*)dict {
    WKRobot *robot = [WKRobot new];
    robot.robotID = dict[@"robot_id"]?:@"";
    robot.version = [dict[@"version"] longValue];
    robot.status = [dict[@"status"] integerValue];
    robot.inlineOn = dict[@"inline_on"]?[dict[@"inline_on"] boolValue]:false;
    robot.placeholder = dict[@"placeholder"]?:@"";
    robot.username = dict[@"username"]?:@"";
    NSArray<NSDictionary*> *menusDicts = dict[@"menus"];
    if(menusDicts && menusDicts.count>0) {
        NSMutableArray<WKRobotMenus*> *menusList = [NSMutableArray array];
        for (NSDictionary *menusDict in menusDicts) {
            WKRobotMenus *menus = [WKRobotMenus new];
            menus.cmd = menusDict[@"cmd"]?:@"";
            menus.remark = menusDict[@"remark"]?:@"";
            menus.type = menusDict[@"type"]?:@"";
            menus.robotID = robot.robotID;
            [menusList addObject:menus];
        }
        robot.menus = menusList;
    }
    return robot;
}

-(WKSyncConversationModel*) toSyncConversationModel:(NSDictionary*)dataDict {
    WKSyncConversationModel *model = [WKSyncConversationModel new];
    NSInteger  channelType = [dataDict[@"channel_type"] integerValue];
    NSString *channelID = dataDict[@"channel_id"];
    model.channel = [[WKChannel alloc] initWith:channelID channelType:channelType];
    
    if(model.channel.channelType == WK_COMMUNITY_TOPIC) {
        NSArray<NSString*> *parentChannels =  [model.channel.channelId componentsSeparatedByString:@"@"];
        if(parentChannels && parentChannels.count>0) {
            NSString *parentChannelID = parentChannels[0];
            if(parentChannelID && ![parentChannelID isEqualToString:@""]) {
                model.parentChannel = [WKChannel channelID:parentChannelID channelType:WK_COMMUNITY];
            }
        }
    }
    model.unread =[dataDict[@"unread"] integerValue];
    model.timestamp = [dataDict[@"timestamp"] doubleValue];
    model.lastMsgSeq = (uint32_t)[dataDict[@"last_msg_seq"] unsignedLongValue];
    model.lastMsgClientNo = dataDict[@"last_client_msg_no"];
    model.version = [dataDict[@"version"] longLongValue];
    model.stick = dataDict[@"stick"]?[dataDict[@"stick"] boolValue]:false;
    model.mute = dataDict[@"mute"]?[dataDict[@"mute"] boolValue]:false;
    
    if(dataDict[@"extra"]) {
        model.remoteExtra = [self toConversationExtra:dataDict[@"extra"]];
    }
    
    NSArray<NSDictionary*> *messageDicts = dataDict[@"recents"];
    if(messageDicts && messageDicts.count>0) {
        NSMutableArray *messages = [NSMutableArray array];
        for (NSDictionary *messageDict in messageDicts) {
            [messages addObject:[WKMessageUtil toMessage:messageDict]];
        }
        model.recents = messages.reverseObjectEnumerator.allObjects;
    }
    return model;
}

-(WKConversationExtra*) toConversationExtra:(NSDictionary*)dataDict {
    WKConversationExtra *extra = [[WKConversationExtra alloc] init];
    NSInteger  channelType = [dataDict[@"channel_type"] integerValue];
    NSString *channelID = dataDict[@"channel_id"];
    extra.channel = [[WKChannel alloc] initWith:channelID channelType:channelType];
    if(dataDict[@"keep_message_seq"]) {
        extra.keepMessageSeq = (uint32_t)[dataDict[@"keep_message_seq"] unsignedLongLongValue];
    }
    if(dataDict[@"keep_offset_y"]) {
        extra.keepOffsetY = [dataDict[@"keep_offset_y"] integerValue];
    }
    if(dataDict[@"draft"]) {
        extra.draft = [dataDict[@"draft"] stringValue];
    }
    if(dataDict[@"version"]) {
        extra.version = [dataDict[@"version"] longLongValue];
    }
   
    return extra;
}

-(WKReminder*) toReminder:(NSDictionary*)dataDict {
    WKReminder *reminder = [[WKReminder alloc] init];
    reminder.reminderID = [dataDict[@"id"] longLongValue];
    NSInteger  channelType = [dataDict[@"channel_type"] integerValue];
    NSString *channelID = dataDict[@"channel_id"];
    reminder.channel = [[WKChannel alloc] initWith:channelID channelType:channelType];
    
    if(dataDict[@"message_id"]) {
        NSDecimalNumber* messageIDNumber = [[NSDecimalNumber alloc] initWithString:dataDict[@"message_id"]];
        reminder.messageId = [messageIDNumber unsignedLongLongValue];
    }
    if(dataDict[@"message_seq"]) {
        reminder.messageSeq = (uint32_t)[dataDict[@"message_seq"] unsignedLongValue];
    }
    reminder.type = [dataDict[@"reminder_type"] integerValue];
    if(dataDict[@"text"]) {
        reminder.text = dataDict[@"text"];
    }
    if(dataDict[@"data"]) {
        reminder.data = dataDict[@"data"];
    }
    if(dataDict[@"is_locate"]) {
        reminder.isLocate = [dataDict[@"is_locate"] boolValue];
    }
    if(dataDict[@"version"]) {
        reminder.version = [dataDict[@"version"] longLongValue];
    }
    if(dataDict[@"done"]) {
        reminder.done = [dataDict[@"done"] boolValue];
    }
    if(dataDict[@"publisher"]) {
        reminder.publisher = dataDict[@"publisher"];
    }
    
    return reminder;
}



@end
