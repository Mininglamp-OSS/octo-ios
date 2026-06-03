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
#import "WKSpaceConversationCache.h"
#import "WKSpaceConvSyncCache.h"
#import "WKApp.h"

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
    // mark-read 上报队列的 provider 注入(SDK 不能直接依赖 WKAPIClient)
    [self setUnreadAckProvider];
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

        // 子区(topic)不走通用 channels/{id}/{type} 接口 —— 通用接口不返回 thread_setting 里的用户维度 mute,
        // 会把刚写入的 thread mute 覆盖回 0。改走 thread 详情接口,和 web 端 channelInfoCallback 保持一致。
        if (channel.channelType == WK_COMMUNITY_TOPIC) {
            NSRange sep = [channel.channelId rangeOfString:@"____"];
            if (sep.location != NSNotFound) {
                NSString *groupNo = [channel.channelId substringToIndex:sep.location];
                NSString *shortID = [channel.channelId substringFromIndex:NSMaxRange(sep)];
                if (groupNo.length > 0 && shortID.length > 0) {
                    NSURLSessionDataTask *threadTask = [[WKAPIClient sharedClient] taskGET:[NSString stringWithFormat:@"groups/%@/threads/%@", groupNo, shortID] parameters:nil callback:^(NSError * _Nullable tErr, NSDictionary *threadDict) {
                        if (tErr) {
                            WKLogError(@"获取子区详情失败！-> %@", tErr);
                            if (callback) callback(tErr, false);
                            return;
                        }
                        // 保留本地 channelInfo 的 mute 值作为"当前已知状态",避免 null 覆盖为错误值。
                        WKChannelInfo *existingInfo = [[WKSDK shared].channelManager getChannelInfo:channel];
                        WKChannelInfo *channelInfo = [[WKChannelInfo alloc] init];
                        channelInfo.channel = channel;
                        channelInfo.name = threadDict[@"name"] ?: @"";
                        // 子区沿用父群头像
                        channelInfo.logo = [NSString stringWithFormat:@"groups/%@/avatar", groupNo];
                        // tri-state mute 处理:
                        //   NSNumber → 服务端显式值,权威,直接采用
                        //   NSNull/missing → 服务端无显式 thread_setting 记录(或 QuerySetting 失败被吞错)。
                        //     此时不覆盖本地现有值 —— 因为冷启动父群 channelInfo 不一定已加载,
                        //     直接 fallback 到 parentInfo.mute 会在 parentInfo==nil 时变成 NO,
                        //     把用户明确设置过的"静音"误覆盖。仅当本地也没有 channelInfo 时,才用父群做初始化。
                        id muteVal = threadDict[@"mute"];
                        if ([muteVal isKindOfClass:[NSNumber class]]) {
                            channelInfo.mute = [muteVal boolValue];
                        } else if (existingInfo) {
                            channelInfo.mute = existingInfo.mute;
                        } else {
                            WKChannel *parentChannel = [WKChannel channelID:groupNo channelType:WK_GROUP];
                            WKChannelInfo *parentInfo = [[WKSDK shared].channelManager getChannelInfo:parentChannel];
                            channelInfo.mute = parentInfo ? parentInfo.mute : NO;
                        }
                        [[WKSDK shared].channelManager addOrUpdateChannelInfo:channelInfo];
                        if (callback) callback(nil, false);
                    }];
                    return [WKTaskOperator cancel:^{
                        if (threadTask) [threadTask cancel];
                    } suspend:^{
                        if (threadTask) [threadTask suspend];
                    } resume:^{
                        if (threadTask) [threadTask resume];
                    }];
                }
            }
        }

        NSURLSessionDataTask *sessionDataTask = [[WKAPIClient sharedClient] taskGET:[NSString stringWithFormat:@"channels/%@/%d",channel.channelId,channel.channelType] parameters:nil callback:^(NSError * _Nullable error, NSDictionary  *resultDict) {
            if(error) {
                WKLogError(@"获取频道信息失败！-> %@",error);
                callback(error,false);
                return;
            }
            WKChannelInfo *channelInfo  = [WKChannelUtil toChannelInfo2:resultDict];

            // mute 三态保护：server channels/{id}/{type} 接口不一定带 mute（mute 在 setting 表，
            // 不在 channel 表）。toChannelInfo2: 走 `resultDict[@"mute"] ? ... : false` 三元式,
            // 字段缺失时把 channelInfo.mute 直接置 false，addOrUpdateChannelInfo: 会把 SDK 缓存
            // 里正确的 mute 覆盖掉 — 用户报告的「进会话页返回后关注 badge 闪 99+」就是这条路径。
            // 子区分支已经做过同款保护（见本文件子区 callback），普通群/DM 这里补齐：
            //   - resultDict 显式给了 NSNumber → toChannelInfo2: 已经取到，无需调整
            //   - 缺失 / NSNull → 沿用 SDK 缓存里的旧 mute（fail-safe），避免擦写
            id muteVal = resultDict[@"mute"];
            if (![muteVal isKindOfClass:[NSNumber class]]) {
                WKChannelInfo *existing = [[WKSDK shared].channelManager getChannelInfo:channel];
                if (existing) channelInfo.mute = existing.mute;
            }

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
        // 获取当前 Space ID（参考 Web 端实现）
        NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
        NSString *syncPath = @"conversation/sync";
        if (currentSpaceId && currentSpaceId.length > 0) {
            // URL 编码 space_id 参数
            NSString *encodedSpaceId = [currentSpaceId stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            syncPath = [NSString stringWithFormat:@"conversation/sync?space_id=%@", encodedSpaceId];
        }

        [[WKAPIClient sharedClient] POST:syncPath parameters:@{
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
            // 预填 channelInfo.extra[@"space_id"] / channelMember.extra[@"source_space_id"]
            // 让 WKSpaceFilter 在 conv sync 落地前即可作 Keep/Skip 判定，消除 fail-open。
            [self prefillSpaceFieldsFromSyncModels:syncConversationModels];
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
        NSString *currentUID = [WKSDK shared].options.connectInfo.uid;
        [[WKAPIClient sharedClient] POST:@"message/reminder/sync" parameters:@{
            @"version":@(maxVersion),
            @"limit": @(1000),
            @"channel_ids": channelIDs,
        }].then(^(NSArray *results){
            if(results && results.count>0) {
                NSMutableArray<WKReminder*> *reminders = [NSMutableArray array];
                for (NSDictionary *result in results) {
                    // 过滤非当前用户的提醒项，只保留目标为自己的 reminder
                    NSString *uid = result[@"uid"];
                    if(uid && currentUID && ![uid isEqualToString:currentUID]) {
                        continue;
                    }
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

#pragma mark - octo-server PR#154：conv sync space_id 预填

// 把 conv sync 解析出的 `space_id` 写入对应群的 channelInfo.extra；
// 把 `my_source_space_id` 写入对应群我自己的 channelMember.extra。
//
// 写法分两路（PR #136 round-2 review 修复，重要）：
//   ✅ 真实记录已在缓存：read-modify-write，保留其它字段；
//   ✅ 真实记录尚未缓存：写入 WKSpaceConvSyncCache 内存表，**不**建 DB stub。
//
// 为什么不再建 DB stub？
//   - channelInfo stub：会让 `getChannelInfo` 命中非 nil，调用方
//     （WKConversationListCell / WKConversationVC 等）判 `info != nil` 就停止
//     fetchChannelInfo，导致群名/头像永远拉不到（真实 channelInfo 不会被请求）。
//   - channelMember stub：默认 status=inactive，而 `WKChannelMemberDB.get:memberUID:`
//     的 SQL 强制 `status=1`，stub 写了也读不回；在已存在的 inactive row 上 upsert
//     还会错把已离群的人 mark 回 active。
//
//   WKSpaceFilter 改为 DB → 内存缓存 二级查找；channelInfo / member 真正同步落地
//   后 DB 路径自然命中并覆盖内存值。
//
// 处理 GROUP 与 PERSON / Bot（PR #136 round-4 review 修复）：
//   - GROUP：channelInfo.extra[space_id] + 自己 channelMember.extra[source_space_id]
//   - PERSON / Bot：仅 channelInfo.extra[space_id]
//     WKSpaceFilter `decideWithChannelId:` 对 WK_PERSON 也读 channelSpaceId
//     做"跨 Space Bot/私聊"判定（WKSpaceFilter.m:158-165），且
//     WKConversationListVM 会对 WK_PERSON 调 decideChannel
//     （WKConversationListVM.m:802-809）—— 不预填会让裸 UID 的 Bot 在
//     channelInfo 真正落地前漏过过滤，造成跨 Space 漏判。
//   - COMMUNITY_TOPIC：归属由 parent group 的 space_id 决定，不在此预填。
//   - 服务端未部署 PR#154（spaceId/mySourceSpaceId 均为 nil）→ 自然跳过。
-(void) prefillSpaceFieldsFromSyncModels:(NSArray<WKSyncConversationModel*>*)models {
    if(!models || models.count == 0) return;
    NSString *myUID = [WKApp shared].loginInfo.uid;
    BOOL hasMyUID = ([myUID isKindOfClass:[NSString class]] && myUID.length > 0);

    for (WKSyncConversationModel *m in models) {
        if(!m.channel) continue;
        uint8_t cType = m.channel.channelType;
        if(cType != WK_GROUP && cType != WK_PERSON) continue;
        NSString *channelId = m.channel.channelId;
        if(channelId.length == 0) continue;

        // 1) channelInfo.extra[@"space_id"] —— GROUP 与 PERSON 都需要。
        if(m.spaceId.length > 0) {
            WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:m.channel];
            if(info) {
                if(!info.extra) {
                    info.extra = [NSMutableDictionary dictionary];
                }
                NSString *existing = nil;
                id existingRaw = info.extra[@"space_id"];
                if([existingRaw isKindOfClass:[NSString class]]) existing = (NSString*)existingRaw;
                if(![existing isEqualToString:m.spaceId]) {
                    info.extra[@"space_id"] = m.spaceId;
                    [[WKSDK shared].channelManager addOrUpdateChannelInfo:info];
                }
            } else {
                // 未缓存：写内存缓存而非 DB stub（见函数 doc）
                [[WKSpaceConvSyncCache shared] setSpaceId:m.spaceId
                                              forChannelId:channelId
                                               channelType:cType];
            }
        } else {
            // PR #136 round-5 review 修复（Jerry-Xin，对齐 Android Round-3）：
            // 后续 conv sync 不再带 space_id 时，必须 per-key 清掉旧缓存，
            // 否则 WKSpaceFilter 会一直按过期值决策。DB 路径上若真有 channelInfo，
            // 等后续 channelInfo 同步覆盖；这里只负责清 cache 兜底值。
            [[WKSpaceConvSyncCache shared] removeSpaceIdForChannelId:channelId
                                                         channelType:cType];
        }

        // 2) channelMember.extra[@"source_space_id"]（自己在群内的成员记录）
        //    仅 GROUP 有成员概念，PERSON 跳过。
        if(cType == WK_GROUP && hasMyUID && m.mySourceSpaceId.length > 0) {
            WKChannelMember *me = [[WKChannelMemberDB shared] get:m.channel memberUID:myUID];
            if(me) {
                if(!me.extra) {
                    me.extra = [NSMutableDictionary dictionary];
                }
                NSString *existing = nil;
                id existingRaw = me.extra[@"source_space_id"];
                if([existingRaw isKindOfClass:[NSString class]]) existing = (NSString*)existingRaw;
                if(![existing isEqualToString:m.mySourceSpaceId]) {
                    me.extra[@"source_space_id"] = m.mySourceSpaceId;
                    [[WKChannelMemberDB shared] addOrUpdateMembers:@[me]];
                }
                // PR #136 round-4 review 修复（lml2468）：
                // 已存在 member row 时也写一份 cache 兜底。后续不带 source_space_id
                // 的 member 全量同步会覆盖 DB extra（WKGroupMemberModel.toChannelMember
                // 在缺字段时不会保留旧值），此时 WKSpaceFilter 走 DB→cache 二级查找
                // 仍能从 cache 拿到 conv sync 下发的值，避免外部群被误判为非成员。
                [[WKSpaceConvSyncCache shared] setMySourceSpaceId:m.mySourceSpaceId
                                                     forChannelId:channelId
                                                      channelType:WK_GROUP];
            } else {
                // 未缓存：写内存缓存而非 DB stub（见函数 doc）
                [[WKSpaceConvSyncCache shared] setMySourceSpaceId:m.mySourceSpaceId
                                                     forChannelId:channelId
                                                      channelType:WK_GROUP];
            }
        } else if(cType == WK_GROUP && m.mySourceSpaceId.length == 0) {
            // PR #136 round-5 review 修复（Jerry-Xin，对齐 Android Round-3）：
            // 后续 conv sync 不再带 my_source_space_id 时（例如成员被踢、
            // 服务端不再下发跨 Space 标），清掉旧缓存避免 WKSpaceFilter 继续把
            // 已不属于来源 Space 的群当外部群放行。
            [[WKSpaceConvSyncCache shared] removeMySourceSpaceIdForChannelId:channelId
                                                                 channelType:WK_GROUP];
        }
    }
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
    // 区分 "server 没下发字段" 与 "server 明确下发 false". 在 handleSyncConversation
    // 写回 channelInfo 那一步会用这两个 flag 做 gate, 避免 server 偶发漏字段时把本地
    // 用户置顶/静音擦掉. NSNull 与 nil 都视为未下发. 顺便规避了老写法
    // `dataDict[@"stick"] ? [.. boolValue] : false` 撞到 NSNull 时
    // -[NSNull boolValue] 的 unrecognized-selector 风险.
    id _stickRaw = dataDict[@"stick"];
    model.stickPresent = (_stickRaw != nil && ![_stickRaw isKindOfClass:[NSNull class]]);
    model.stick = model.stickPresent ? [_stickRaw boolValue] : NO;
    id _muteRaw = dataDict[@"mute"];
    model.mutePresent = (_muteRaw != nil && ![_muteRaw isKindOfClass:[NSNull class]]);
    model.mute = model.mutePresent ? [_muteRaw boolValue] : NO;
    
    if(dataDict[@"extra"]) {
        model.remoteExtra = [self toConversationExtra:dataDict[@"extra"]];
    }

    // ---------- octo-server PR#154：会话级 Space 隔离字段 ----------
    // server 在 conversation/sync 响应里直接下发已解析的 `space_id` 和 `my_source_space_id`，
    // 让客户端无需再等 group 详情 / member 全量同步即可作 Keep/Skip 判定。
    // NSNull 防御：仅接受非空 NSString，避免污染缓存。
    id spaceIdRaw = dataDict[@"space_id"];
    if([spaceIdRaw isKindOfClass:[NSString class]] && [(NSString*)spaceIdRaw length] > 0) {
        model.spaceId = (NSString*)spaceIdRaw;
    }
    id mySourceSpaceIdRaw = dataDict[@"my_source_space_id"];
    if([mySourceSpaceIdRaw isKindOfClass:[NSString class]] && [(NSString*)mySourceSpaceIdRaw length] > 0) {
        model.mySourceSpaceId = (NSString*)mySourceSpaceIdRaw;
    }

    NSArray<NSDictionary*> *messageDicts = dataDict[@"recents"];
    if(messageDicts && messageDicts.count>0) {
        NSMutableArray *messages = [NSMutableArray array];
        for (NSDictionary *messageDict in messageDicts) {
            [messages addObject:[WKMessageUtil toMessage:messageDict]];
        }
        model.recents = messages.reverseObjectEnumerator.allObjects;
    }
    // 仅缓存 server 的 space_last_message（用于会话列表按 space 过滤的"最后一条消息"展示）。
    // server 的 space_unread 字段不再被读取——它在消息数超过 msg_count 窗口后会聚合失真返 0，
    // 引入 cache 后又会被重启清空 / 再 sync 重新 seed 为 0，导致红点丢失。
    // 改用 Android 风格：UI 层只按 lastMessage.space_id 跨空间过滤，unread 直接信任 SDK DB。
    NSDictionary *spaceLastMsgDict = dataDict[@"space_last_message"];
    if (model.channel.channelType == WK_PERSON
        && spaceLastMsgDict && [spaceLastMsgDict isKindOfClass:[NSDictionary class]]) {
        WKMessage *spaceLastMsg = [WKMessageUtil toMessage:spaceLastMsgDict];
        [[WKSpaceConversationCache shared] setSpaceLastMessage:spaceLastMsg forChannel:model.channel];
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
    NSLog(@"[ReminderDebug] toReminder: id=%lld, channel=%@/%ld, reminder_type=%lu, text=%@, done=%d, raw=%@", reminder.reminderID, channelID, (long)channelType, (unsigned long)reminder.type, dataDict[@"text"], [dataDict[@"done"] boolValue], dataDict);
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

#pragma mark - Unread mark-read ack queue

-(void) setUnreadAckProvider {
    [[WKUnreadAckRunner shared] setUploadProvider:^(WKChannel *channel, uint32_t lastReadSeq, void(^complete)(NSError * _Nullable)) {
        // unread=0 表示"已读到 message_seq=lastReadSeq".server 端已有的
        // PUT coversation/clearUnread 接受这种语义.
        [[WKAPIClient sharedClient] PUT:@"coversation/clearUnread" parameters:@{
            @"channel_id": channel.channelId ?: @"",
            @"channel_type": @(channel.channelType),
            @"unread": @(0),
            @"message_seq": @(lastReadSeq),
        }].then(^{
            if (complete) complete(nil);
        }).catch(^(NSError *err){
            if (complete) complete(err);
        });
    }];
}



@end
