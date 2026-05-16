//
//  WKSystemMessageHandler.m
//  WuKongBase
//
//  Created by tt on 2020/1/23.
//

#import "WKSystemMessageHandler.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"
#import "WKGroupManager.h"
#import "WKLogs.h"
#import "WKNavigationManager.h"
#import "WKApp.h"
#import <SDWebImage/SDWebImage.h>
#import "WKAvatarUtil.h"
#import "WKResource.h"
#import <AudioToolbox/AudioToolbox.h>
#import "WKLocalNotificationManager.h"
#import "WKTypingManager.h"
#import "WuKongBase.h"
#import "WKOnlineStatusManager.h"
#import "WKMySettingManager.h"
@interface WKSystemMessageHandler ()<WKChatManagerDelegate,WKConnectionManagerDelegate,WKCMDManagerDelegate>

@property(nonatomic,strong) dispatch_queue_t systemMessageHandlerQueue;

@end

@implementation WKSystemMessageHandler

static WKSystemMessageHandler *_instance = nil;

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

- (dispatch_queue_t)systemMessageHandlerQueue {
    if(!_systemMessageHandlerQueue) {
        _systemMessageHandlerQueue  = dispatch_queue_create("demo.gcd.concurrent_queue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _systemMessageHandlerQueue;
}

- (void)handle {
    [[WKSDK shared].chatManager removeDelegate:self];
    [[WKSDK shared].chatManager addDelegate:self];
    
    [[WKSDK shared].connectionManager removeDelegate:self];
    [[WKSDK shared].connectionManager addDelegate:self];
    
    [[WKSDK shared].cmdManager removeDelegate:self];
    [[WKSDK shared].cmdManager addDelegate:self];
   
    
}

#pragma mark - WKConnectionManagerDelegate
// 踢出
- (void)onKick:(uint8_t)reasonCode reason:(NSString *)reason {
    [[WKApp shared] logout];
    
    NSString *tip = reason;
    if(reasonCode == WK_REASON_KICK) {
        tip = LLang(@"账号已在其他设备上登录！");
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:LLang(@"提示") message:tip preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:LLang(@"好的") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
             
        }];
        [alertController addAction:okAction];
        [[WKNavigationManager shared].topViewController presentViewController:alertController animated:YES completion:nil];
    });
    
   
}

#pragma mark - WKChatManagerDelegate
bool needRemind = false; // 是否需要提醒
- (void)onRecvMessages:(WKMessage*)message left:(NSInteger)left {
    // [BotSpaceTrace] 收消息总入口：定位跨 Space Bot 消息为何会进入当前 Space 列表。
    // 仅对 WK_PERSON 打日志，群聊不污染日志。日志可上线后通过宏统一关。
    if(message.channel.channelType == WK_PERSON) {
        NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
        id rawMsgSpaceId = message.content.contentDict[@"space_id"];
        WKChannelInfo *info = [[WKChannelInfoDB shared] queryChannelInfo:message.channel];
        id channelInfoSpaceId = info.extra[@"space_id"];
        NSLog(@"[BotSpaceTrace] onRecvMessages channelId=%@ type=%d currentSpace=%@ msgSpaceId=%@ channelInfoSpaceId=%@ robot=%d fromUid=%@ contentType=%d",
              message.channel.channelId, message.channel.channelType,
              currentSpaceId ?: @"<nil>",
              [rawMsgSpaceId isKindOfClass:[NSString class]] ? rawMsgSpaceId : @"<missing>",
              [channelInfoSpaceId isKindOfClass:[NSString class]] ? channelInfoSpaceId : @"<missing>",
              info ? info.robot : -1,
              message.fromUid ?: @"<nil>",
              (int)message.contentType);
    }
    // BotFather空间隔离：为缺少space_id的Bot回复推断当前空间
    [self inferSpaceIdForBotMessage:message];

    [[WKTypingManager shared] removeTypingByChannel:message.channel newMessage:message];
    dispatch_async(self.systemMessageHandlerQueue, ^{
        switch (message.contentType) {
            case WK_GROUP_MEMBERADD:  // 群成员添加
            case WK_GROUP_MEMBERREMOVE: // 群成员移除
            case WK_GROUP_MEMBERSCANJOIN: // 群成员扫码加入
            case WK_GROUP_TRANSFERGROUPER: // 群转让
                [self memberChange:message.channel];
                break;
            case WK_GROUP_MEMBERINVITE: // 群成员邀请
                [self handleGroupMemberInvite:message];
                break;
            case WK_GROUP_UPDATE: // 群基础数据更新
            case WK_GROUP_FORBIDDEN_ADD_FRIEND: // 群禁止加好友
            case WK_GROUP_UPGRADE: // 群升级
                [self handleGroupUpdate:message];
                break;
//            case WK_CMD: // 命令
//                [self handleCMD:message];
            default:
                break;
        }
    });
    if(message.header.showUnread) {
        if(![WKApp shared].currentChatChannel || ![[WKApp shared].currentChatChannel isEqual:message.channel]) {
            // 空间隔离：不属于当前空间的消息不触发提醒（声音/振动/红点）
            if([[WKLocalNotificationManager shared] isMessageInCurrentSpace:message]) {
                needRemind = true;
            }
        }
    }

    // Socket 本地通知已关闭，由服务端 APNs 推送替代
    // [[WKLocalNotificationManager shared] showLocalNotificationIfNeed:message];
    
    
    if(left == 0) {
        if(needRemind) {
            needRemind = false;
            if(message.channelInfo) {
                if(message.channelInfo.mute) { // 免打扰不通知
                    return;
                }
                if(message.contentType == WK_GROUP_MEMBERADD && ![message.channelInfo settingForKey:WKChannelExtraKeyJoinGroupRemind defaultValue:YES]) {
                    return;
                }
            }
        
            [self remindUserIfNeed]; // 提醒收到消息如果需要
        }
    }else{
        needRemind = false;
    }
   
}

- (void)onSendack:(WKSendackPacket *)sendackPacket left:(NSInteger)left {
    if(sendackPacket.header.noPersist) {
        return;
    }
    [self playMessageSendOutSound];
}

#pragma mark - WKCMDManagerDelegate

- (void)cmdManager:(WKCMDManager *)manager onCMD:(WKCMDModel *)model {
    [self handleCMD:model.cmd param:model.param];
}

-(BOOL) alloPlayVoice {
    return YES;
}



// 群成员改变
-(void) memberChange:(WKChannel*)channel {
    WKChannelInfo *channelInfo = [WKSDK.shared.channelManager getChannelInfo:channel];
    if(channelInfo) {
        WKGroupType groupType = [WKChannelUtil groupType:channelInfo];
        
        if(groupType == WKGroupTypeSuper) {
            [WKSDK.shared.channelManager fetchChannelInfo:channel];
        }else  {
            [self syncMembers:channel];
        }
    }
}

-(void) syncMembers:(WKChannel*)channel {
    WKLogDebug(@"同步群成员！");
    [[WKGroupManager shared] syncMemebers:channel.channelId];
}
// 处理群聊邀请确认
-(void) handleGroupMemberInvite:(WKMessage*) message {
    // 判断是否存在邀请提醒，如果存在则在原来的count基础上累加
//   NSArray<WKReminder*> *reminders = [[WKSDK shared].reminderManager getReminders:WKReminderTypeMemberInvite channel:message.channel];
//    WKReminder *reminder;
//    if(reminders && reminders.count>0) {
//        reminder = reminders[0];
//    }
//    if(reminder && reminder.data &&  reminder.data[@"count"]) {
//        NSNumber *count = reminder.data[@"count"];
//        count = @(count.intValue+1);
//        [[WKSDK shared].conversationManager appendReminder:[WKReminder initWithType:WKReminderTypeMemberInvite text:[NSString stringWithFormat:LLang(@"[%d条进群申请]"),count.intValue] data:@{@"count":count}] channel:message.channel];
//    }else { // 如果不存在，则默认为1
//         [[WKSDK shared].conversationManager appendReminder:[WKReminder initWithType:WKReminderTypeMemberInvite text:LLang(@"[1条进群申请]") data:@{@"count":@(1)}] channel:message.channel];
//    }
   
}

// 处理群更新事件
-(void) handleGroupUpdate:(WKMessage*)message {
    WKLogDebug(@"处理群基础数据更新事件！");
    [[WKGroupManager shared] syncGroupInfo:message.channel.channelId complete:nil];
}

// 处理消息撤回
//-(void) handleMessageRevoke:(WKMessage*)message {
//    WKLogDebug(@" 处理消息撤回事件！");
//    WKSystemContent *sysmtemMessage =  (WKSystemContent*)message.content;
//    uint64_t messageId = 0;
//    NSString *messageIDStr;
//
//    WKMessage *revokeMessage; // 需要撤回的消息
//    if([WKSDK shared].options.proto == WK_PROTO_MOS) {
//        if(sysmtemMessage.content[@"client_msg_no"]) {
//            revokeMessage = [[WKMessageDB shared] getMessageWithClientMsgNo:sysmtemMessage.content[@"client_msg_no"]];
//        }
//    }else {
//        if(sysmtemMessage.content && sysmtemMessage.content[@"message_id"]) {
//            messageIDStr = sysmtemMessage.content[@"message_id"];
//
//        }
//        if(messageIDStr) {
//            NSDecimalNumber* formatter = [[NSDecimalNumber alloc] initWithString:messageIDStr]; // 这里需要用 NSDecimalNumber不要用NSNumberFormat NSNumberFormat数字太大会转换不正确
//            messageId =  [formatter unsignedLongLongValue];
//            revokeMessage = [[WKMessageDB shared] getMessageWithMessageId:messageId];
//        }
//    }
//   if(revokeMessage) {
//       [[WKSDK shared].chatManager revokeMessage:revokeMessage];
//   }
//
//
//}

-(void) handleMessageEerase:(NSDictionary*)param {
   NSString *eraseType =  param[@"erase_type"]?:@"from";
    if([eraseType isEqualToString:@"from"]) {
        if(param[@"from_uid"]) {
            NSString *channelID = param[@"channel_id"];
            NSNumber *channelType = param[@"channel_type"];
            [[WKSDK shared].chatManager deleteMessage:param[@"from_uid"] channel:[WKChannel channelID:channelID channelType:channelType.intValue]];
        }
    }else {
        NSString *channelID = param[@"channel_id"];
        NSNumber *channelType = param[@"channel_type"];
        [[WKSDK shared].chatManager clearMessages:[WKChannel channelID:channelID channelType:channelType.intValue]];
    }
}

-(void) handleMessageRevokeCMD:(NSDictionary*)param {
    WKMessage *revokeMessage; // 需要撤回的消息
    uint64_t messageId = 0;
    NSString *messageIDStr;
    if(param[@"message_id"]) {
        messageIDStr = param[@"message_id"];
    }
    if(messageIDStr) {
        NSDecimalNumber* formatter = [[NSDecimalNumber alloc] initWithString:messageIDStr]; // 这里需要用 NSDecimalNumber不要用NSNumberFormat NSNumberFormat数字太大会转换不正确
        messageId =  [formatter unsignedLongLongValue];
        revokeMessage = [[WKMessageDB shared] getMessageWithMessageId:messageId];
    }
   if(revokeMessage) {
       if(![[WKChannelSettingManager shared] revokeRemind:revokeMessage.channel]) {
           [[WKMessageManager shared] deleteMessages:@[[[WKMessageModel alloc] initWithMessage:revokeMessage]]]; // 如果设置了不撤回不提醒则直接删除消息
       }else{
           [[WKSDK shared].chatManager syncMessageExtra:revokeMessage.channel complete:nil];
       }
   }
    
}

// 处理群更新事件
-(void) handleCMD:(WKMessage*)message {
    
    WKCMDContent *cmdContent = (WKCMDContent*)message.content;
    NSString *cmd = cmdContent.cmd;
    [self handleCMD:cmd param:cmdContent.param];
}

-(void) handleCMD:(NSString*)cmd param:(NSDictionary*)param {
    NSLog(@"[PCDebug] handleCMD: cmd='%@'", cmd);
    if([cmd isEqualToString:WKCMDMemberUpdate]) { // 群成员更新
        WKLogDebug(@"处理群成员更新命令！");
        if(param&&param[@"group_no"]) {
            // 同步群成员
            [[WKGroupManager shared] syncMemebers:param[@"group_no"]];
        }
    }else if([cmd isEqualToString:WKCMDUnreadClear]) { // 清除未读数
         WKLogDebug(@"处理清除未读消息命令！");
        NSInteger unread = 0;
        if(param[@"unread"]) {
            unread = [param[@"unread"] integerValue];
        }
        WKChannel *channel = [[WKChannel alloc] initWith:param[@"channel_id"] channelType:[param[@"channel_type"] intValue]];
        [[WKSDK shared].conversationManager setConversationUnreadCount:channel unread:unread];
    }else if([cmd isEqualToString:WKCMDGroupAvatarUpdate] && param&&param[@"group_no"]) { // 群头像更新
         WKLogDebug(@"处理群头像更新！->%@",param[@"group_no"]);
        [[SDImageCache sharedImageCache] removeImageForKey:[WKAvatarUtil getGroupAvatar:param[@"group_no"]] withCompletion:nil];
        
        [WKApp.shared notifyChannelAvatarUpdate:[WKChannel channelID:param[@"group_no"] channelType:WK_GROUP]];
        
    } else if([cmd isEqualToString:WKCMDUserAvatarUpdate] && param&&param[@"uid"]) { // 用户头像更新
        WKLogDebug(@"处理用户头像更新！->%@",[WKAvatarUtil getAvatar:param[@"uid"]]);
        
        [[SDImageCache sharedImageCache] removeImageForKey:[WKAvatarUtil getAvatar:param[@"uid"]] withCompletion:nil];
        
        [WKApp.shared notifyChannelAvatarUpdate:[WKChannel channelID:param[@"uid"] channelType:WK_PERSON]];
        
    } else if([cmd isEqualToString:WKCMDChannelUpdate]) { // 频道信息更新
        WKLogDebug(@"处理频道信息更新！");
        NSString *channelID = param[@"channel_id"];
        NSNumber *channelType = param[@"channel_type"];
        if(!channelID || !channelType) {
            return;
        }
        [[WKSDK shared].channelManager fetchChannelInfo:[[WKChannel alloc] initWith:channelID channelType:channelType.intValue]];
    }else if([cmd isEqualToString:WKCMDVoiceReaded]) { // 语音已读
        NSString *messageIDStr = param[@"message_id"];
        unsigned long long messageID = strtoull([messageIDStr UTF8String], NULL, 0);
        WKMessage *message = [[WKMessageDB shared] getMessageWithMessageId:messageID];
        if(message) {
            message.voiceReaded = true;
            [[WKSDK shared].chatManager updateMessageVoiceReaded:message];
        }
    }else if([cmd isEqualToString:WKCMDTyping]) { // 输入中
        [[WKTypingManager shared] addTypingByMessage:[[WKTypingManager shared] convertParamToTypingMessage:param]];
    }else if([cmd isEqualToString:WKCMDOnlineStatus]) { // 在线状态通知
       NSLog(@"[PCDebug] CMD onlineStatus: param=%@", param);
       WKChannel *channel = [[WKChannel alloc] initWith:param[@"uid"] channelType:WK_PERSON];
        BOOL allOffline = false;
        if(param[@"all_offline"]) {
            allOffline = [param[@"all_offline"] integerValue];
        }
        WKDeviceFlagEnum mainDeviceFlag = WKDeviceFlagEnumUnknown;
        if(param[@"main_device_flag"]) {
                mainDeviceFlag =  [param[@"main_device_flag"] integerValue];
        }
        [[WKOnlineStatusManager shared] setChannelOnline:channel online:!allOffline deviceFlag:mainDeviceFlag];

        NSLog(@"[PCDebug] CMD uid compare: channelId='%@' loginUid='%@' match=%d, allOffline=%d", channel.channelId, [WKApp shared].loginInfo.uid, [channel.channelId isEqualToString:[WKApp shared].loginInfo.uid], allOffline);
        if(channel.channelType == WK_PERSON && [channel.channelId isEqualToString:[WKApp shared].loginInfo.uid]) {
            WKDeviceFlagEnum deviceFlag = WKDeviceFlagEnumAPP;
            if(param[@"device_flag"]) {
                deviceFlag = [param[@"device_flag"] integerValue];
            }
            BOOL online = [param[@"online"] boolValue];
            NSLog(@"[PCDebug] CMD isSelf=YES: deviceFlag=%ld(Web=1,PC=2,APP=0) online=%d allOffline=%d", (long)deviceFlag, online, allOffline);
            // 只对Web(1)和PC(2)设备状态变化显示"已登录"banner
            if(deviceFlag == WKDeviceFlagEnumWeb || deviceFlag == WKDeviceFlagEnumPC) {
                NSLog(@"[PCDebug] CMD matched PC/Web, setting pcOnline=%d", online);
                WKOnlineStatusManager.shared.pcOnline = online;
                WKPCOnlineResp *pcOnlineResp = [WKPCOnlineResp new];
                pcOnlineResp.online = online;
                pcOnlineResp.deviceFlag = deviceFlag;
                [WKOnlineStatusManager.shared callOnlineStatusChangeMyPCOnlineStatusDelegate:pcOnlineResp];
            } else {
                NSLog(@"[PCDebug] CMD deviceFlag=%ld NOT Web/PC, skipped PC update", (long)deviceFlag);
            }
        } else {
            NSLog(@"[PCDebug] CMD isSelf=NO, skipped. channelType=%hhu", channel.channelType);
        }
      
        
        
    }else if([cmd isEqualToString:WKCMDMessageRevoke]) { // 消息撤回
        [self handleMessageRevokeCMD:param];
    }else if([cmd isEqualToString:WKCMDSyncMessageExtra]) { // 同步消息扩展数据
        
        WKChannel *channel = [[WKChannel alloc] initWith:param[@"channel_id"] channelType:[param[@"channel_type"] intValue]];
        [[WKSDK shared].chatManager syncMessageExtra:channel complete:nil];
        
    }else if([cmd isEqualToString:WKCMDSyncMessageReaction]) { // 同步消息回应
        
        WKChannel *channel = [[WKChannel alloc] initWith:param[@"channel_id"] channelType:[param[@"channel_type"] intValue]];
        [[WKSDK shared].reactionManager sync:channel];
        
    } else if([cmd isEqualToString:WKCMDMessageEerase]) { // 擦除消息
        [self handleMessageEerase:param];
    } else if([cmd isEqualToString:WKCMDSyncReminders]) { // 同步提醒项
        [[WKSDK shared].reminderManager sync];
    } else if([cmd isEqualToString:WKCMDSyncConversationExtra]) { // 同组最近会话扩展
        [[WKSDK shared].conversationManager syncExtra];
    } else if([cmd isEqualToString:WKCMDConversationDeleted]) { // 最近会话被删除（web 端解散群/删除会话 → 服务端 fanout 此 CMD）
        // 对齐 web `packages/dmworkbase/src/module.tsx` 的 "conversationDeleted" 分支：
        // 从本地 DB 删除该会话并触发 onConversationDelete: 让 UI 移除对应行。
        NSString *channelID = param[@"channel_id"];
        NSNumber *channelType = param[@"channel_type"];
        if(channelID.length > 0 && channelType) {
            WKChannel *channel = [[WKChannel alloc] initWith:channelID channelType:channelType.intValue];
            [[WKSDK shared].conversationManager deleteConversation:channel];
        }
    }
}

/// 已废弃：参考 web 实现（packages/dmworkbase/src/Service/SpaceService.tsx
/// `shouldSkipSystemBotConversation`），跨 Space Bot 消息隔离应当在 UI 层做"过滤"，
/// 而不是在收消息时给 message 盖戳改写 space_id。
///
/// 旧实现把 `currentSpaceId` 强行写进 contentDict，会让另一个 Space 的 Bot 推送
/// 在到达时被错误标记为当前 Space，从而绕过 `WKConversationListVC` 的
/// `isMessageFromCurrentSpace` gate（m:1500-1503）造成串台。
///
/// 现在策略：完全不改 message —— 信任服务端下发的 space_id；缺失也不补。
/// 由 `WKConversationListVC` 的现有 gate（系统 Bot + 跨 Space lastMessage）在
/// uiAddOrUpdateConversationForOne / onlyAddOrUpdateConversation 处统一拦截。
/// 保留方法以避免 callsite 改动，body 留空仅做兼容回退。
-(void) inferSpaceIdForBotMessage:(WKMessage*)message {
    // 不再做任何 space_id 推断/盖戳。详见函数注释。
    (void)message;
}

-(void) remindUserIfNeed {
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if(state != UIApplicationStateActive) { //app在后台 不播铃声，因为WKLocalNotificationManager会播
        return;
    }
    if([WKMySettingManager shared].muteOfApp) { // app全局静音不做提醒
        return;
    }
    if([WKMySettingManager shared].newMsgNotice) { // 是否开启新消息提醒
        if([WKMySettingManager shared].voiceOn) {
            [self playSystemSound];
        }
        if([WKMySettingManager shared].shockOn) {
            // //震动
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
    }
   
}



// 播放系统声音
-(void)playSystemSound {
     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
          static SystemSoundID messageSoundID = 0;
             if (messageSoundID == 0) {
                 NSBundle *b= [WKApp.shared resourceBundle:@"WuKongBase"];
                 NSString *path = [b pathForResource:@"newmsg" ofType:@"wav" inDirectory:@"Other"];
                 NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
                 AudioServicesCreateSystemSoundID((__bridge CFURLRef)filePath, &messageSoundID);
             }
         AudioServicesPlaySystemSound(messageSoundID);
     });
}

// 播放消息发送成功的声音
-(void) playMessageSendOutSound {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
         static SystemSoundID soundID = 0;
        if (soundID == 0) {
            NSBundle *b=[WKApp.shared resourceBundle:@"WuKongBase"];
            
            NSString *path = [b pathForResource:@"sound_out" ofType:@"wav" inDirectory:@"Other"];
            if(path) {
                NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
                AudioServicesCreateSystemSoundID((__bridge CFURLRef)filePath, &soundID);
            }
            
        }
        AudioServicesPlaySystemSound(soundID);
    });
}

@end
