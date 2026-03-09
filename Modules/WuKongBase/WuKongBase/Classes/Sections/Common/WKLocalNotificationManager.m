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
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if(state == UIApplicationStateActive) {
        return;
    }
    [self showLocalNotification:message];
}

-(void) showLocalNotification:(WKMessage*)message {
    WKChannelInfo *channelInfo = message.channelInfo;
    if(!channelInfo) { // 如果频道信息不存在，则不显示通知信息 TODO: 如果app从来没有收到过此频道的消息 第一次收到可能没本地通知。这里情况应该出现的概率非常小，先这样处理
        return;
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
        notifContent.sound = [UNNotificationSound defaultSound];
        notifContent.categoryIdentifier = [NSString stringWithFormat:@"%llu",message.messageId];
        notifContent.body = content;
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

@end
