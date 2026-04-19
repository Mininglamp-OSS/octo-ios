//
//  WKLocalNotificationManager.m
//  WuKongBase
//
//  Created by tt on 2020/7/21.
//

#import "WKLocalNotificationManager.h"
#import <UserNotifications/UserNotifications.h>
#import "WKLogs.h"
#import "WKMySettingManager.h"
#import "WuKongBase.h"
#import "WKConversationListVM.h"
#import "WKConversationVC.h"
@implementation WKLocalNotificationManager

static WKLocalNotificationManager *_instance = nil;

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
-(void) showLocalNotificationIfNeed:(WKMessage*)message {
    if(message.contentType == WK_CMD || !message.header.showUnread || ![WKMySettingManager shared].newMsgNotice) {
        return;
    }

    // 空间隔离：不属于当前空间的消息不显示推送通知
    if(![self isMessageInCurrentSpace:message]) {
        return;
    }

    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if(state == UIApplicationStateActive) {
        return;
    }
    [self showLocalNotification:message];
}

/// 判断消息是否属于当前空间
-(BOOL) isMessageInCurrentSpace:(WKMessage*)message {
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(!currentSpaceId || currentSpaceId.length == 0) {
        return YES; // 无空间上下文，不过滤
    }

    // 系统通知和文件助手是全局的，始终通知
    NSString *channelId = message.channel.channelId;
    if([channelId isEqualToString:[WKApp shared].config.systemUID] ||
       [channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
        return YES;
    }

    // 核心判断：检查该会话是否在当前空间的会话列表中
    // 会话列表通过 conversation/sync?space_id= 从服务端加载，已按空间过滤
    WKConversationWrapModel *existModel = [[WKConversationListVM shared] modelAtChannel:message.channel];
    if(!existModel) {
        // 子区不在会话列表中，通过 groupNo 前缀匹配父群聊判断
        if(message.channel.channelType == WK_COMMUNITY_TOPIC) {
            NSRange sep = [channelId rangeOfString:@"____"];
            if(sep.location != NSNotFound) {
                NSString *groupNo = [channelId substringToIndex:sep.location];
                WKChannel *parentChannel = [WKChannel channelID:groupNo channelType:WK_GROUP];
                WKConversationWrapModel *parentModel = [[WKConversationListVM shared] modelAtChannel:parentChannel];
                if(parentModel) {
                    return YES; // 父群聊在当前空间，子区消息允许通知
                }
            }
        }
        return NO; // 不在当前空间的会话列表中，不通知
    }

    // Person 频道（含 BotFather）：检查消息的 space_id，避免跨空间消息触发提醒
    if(message.channel.channelType == WK_PERSON) {
        NSString *msgSpaceId = message.content.contentDict[@"space_id"];
        if(msgSpaceId && [msgSpaceId isKindOfClass:[NSString class]] && msgSpaceId.length > 0) {
            return [msgSpaceId isEqualToString:currentSpaceId];
        }
    }

    return YES;
}

-(void) showLocalNotification:(WKMessage*)message {
    WKChannelInfo *channelInfo = message.channelInfo;
    if(!channelInfo) {
        // 子区可能还没有本地 channelInfo，用父群聊的信息兜底
        if(message.channel.channelType == WK_COMMUNITY_TOPIC) {
            NSRange sep = [message.channel.channelId rangeOfString:@"____"];
            if(sep.location != NSNotFound) {
                NSString *groupNo = [message.channel.channelId substringToIndex:sep.location];
                WKChannel *parentChannel = [WKChannel channelID:groupNo channelType:WK_GROUP];
                channelInfo = [[WKSDK shared].channelManager getChannelInfo:parentChannel];
            }
        }
        if(!channelInfo) {
            return;
        }
    }
    if(channelInfo.mute) { // 免打扰不通知
        return;
    }
    
    NSString *title;
    NSString *alert;
    NSString *content;
     WKChannelInfo *from = [message from];
    if(message.channel && message.channel.channelType == WK_PERSON) {
        if(from) {
            title = from.displayName;
        }else {
            title = LLang(@"聊天"); // TODO：如果发送者数据还没下载下来，这先用默认的代替
        }
    }else {
        title =channelInfo.displayName;
    }
    switch (message.contentType) {
        case WK_TEXT:
            alert = ((WKTextContent*)message.content).content;
            break;
        case WK_IMAGE:
            alert = LLang(@"[图片]");
            break;
        case WK_GIF:
            alert =LLang(@"[GIF]");
            break;
        case WK_VOICE:
            alert = LLang(@"[语音]");
            break;
        default:
           return;
    }
    if(from &&  message.channel.channelType != WK_PERSON) {
        content = [NSString stringWithFormat:@"%@：%@",from.displayName,alert];
    }else{
        content = [NSString stringWithFormat:@"%@",alert];
    }
     NSInteger totalBadge = [[UIApplication sharedApplication] applicationIconBadgeNumber];
    if (@available(iOS 10.0, *)) {
       
        UNMutableNotificationContent *notifContent = [[UNMutableNotificationContent alloc] init];
        notifContent.badge = @(totalBadge+1);
        notifContent.title = title;
        if([WKMySettingManager shared].muteOfApp) {
            notifContent.sound = nil;
        } else {
            notifContent.sound = [UNNotificationSound defaultSound];
        }
        notifContent.categoryIdentifier = [NSString stringWithFormat:@"%llu",message.messageId];
        notifContent.body = content;
        notifContent.userInfo = @{
            @"channel_id": message.channel.channelId ?: @"",
            @"channel_type": @(message.channel.channelType),
            @"message_seq": @(message.messageSeq),
        };
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSString stringWithFormat:@"%llu",message.messageId] content:notifContent trigger:nil];
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if(error) {
                WKLogError(@"推送失败！-> %@",error);
            }
        }];

    } else {
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.alertBody = content;
        localNotification.applicationIconBadgeNumber = totalBadge+1;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    }
    
}

-(void) registerAsNotificationDelegate {
    if (@available(iOS 10.0, *)) {
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    }
}

#pragma mark - UNUserNotificationCenterDelegate

// 点击通知时打开对应聊天窗口并定位到消息
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(10.0)) {
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSString *channelId = userInfo[@"channel_id"];
    NSNumber *channelType = userInfo[@"channel_type"];
    NSNumber *messageSeq = userInfo[@"message_seq"];

    if (channelId.length > 0 && channelType) {
        [self navigateToChannel:channelId channelType:channelType messageSeq:messageSeq retryCount:0];
    }
    completionHandler();
}

// 跳转到聊天窗口，冷启动时导航栈未就绪则延迟重试
-(void) navigateToChannel:(NSString *)channelId channelType:(NSNumber *)channelType messageSeq:(NSNumber *)messageSeq retryCount:(NSInteger)retryCount {
    // 检查导航栈是否就绪（冷启动时可能还没初始化完成）
    if (![WKNavigationManager shared].topViewController || retryCount > 0) {
        if (retryCount >= 10) return; // 最多重试 10 次（5 秒）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self navigateToChannel:channelId channelType:channelType messageSeq:messageSeq retryCount:retryCount + 1];
        });
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WKChannel *channel = [WKChannel channelID:channelId channelType:channelType.integerValue];
        WKConversationVC *vc = [WKConversationVC new];
        vc.channel = channel;
        if (messageSeq && messageSeq.unsignedIntValue > 0) {
            vc.locationAtOrderSeq = [[WKSDK shared].chatManager getOrderSeq:messageSeq.unsignedIntValue];
        }
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    });
}

// 前台收到通知时仍然显示横幅
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler API_AVAILABLE(ios(10.0)) {
    completionHandler(UNNotificationPresentationOptionBadge);
}

@end
