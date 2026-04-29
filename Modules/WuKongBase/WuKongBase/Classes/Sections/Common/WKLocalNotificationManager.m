//
//  WKLocalNotificationManager.m
//  WuKongBase
//
//  Created by tt on 2020/7/21.
//

#import "WKLocalNotificationManager.h"
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
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

// 临时调试：悬浮展示 APNs userInfo，用于在 Release 包中确认服务端推送的字段名
// 排查完成后删除此方法和调用处
- (void)showPushDebugPanel:(NSDictionary *)userInfo API_AVAILABLE(ios(10.0)) {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    NSString *jsonStr = jsonData
        ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
        : [userInfo description];

    dispatch_async(dispatch_get_main_queue(), ^{
        // 用独立 UIWindow 浮在最顶层，不影响正常导航
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
        }
        UIWindow *panel = scene
            ? [[UIWindow alloc] initWithWindowScene:scene]
            : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        panel.windowLevel = UIWindowLevelStatusBar + 100;
        panel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.88];
        panel.layer.cornerRadius = 12;
        panel.clipsToBounds = YES;

        CGRect screen = [UIScreen mainScreen].bounds;
        panel.frame = CGRectMake(16, 80, screen.size.width - 32, screen.size.height * 0.55);

        // 标题
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, panel.bounds.size.width - 60, 24)];
        title.text = @"[PushDebug] APNs userInfo";
        title.font = [UIFont boldSystemFontOfSize:13];
        title.textColor = [UIColor colorWithRed:1 green:0.8 blue:0 alpha:1];
        [panel addSubview:title];

        // 关闭按钮
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(panel.bounds.size.width - 44, 4, 40, 36);
        [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [panel addSubview:closeBtn];

        // 可滚动内容
        UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 40, panel.bounds.size.width, panel.bounds.size.height - 40)];
        UILabel *content = [[UILabel alloc] init];
        content.text = jsonStr;
        content.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
        content.textColor = [UIColor colorWithRed:0.6 green:1.0 blue:0.6 alpha:1];
        content.numberOfLines = 0;
        content.lineBreakMode = NSLineBreakByCharWrapping;
        CGSize size = [content sizeThatFits:CGSizeMake(panel.bounds.size.width - 16, CGFLOAT_MAX)];
        content.frame = CGRectMake(8, 4, panel.bounds.size.width - 16, size.height);
        scroll.contentSize = CGSizeMake(panel.bounds.size.width, size.height + 8);
        [scroll addSubview:content];
        [panel addSubview:scroll];

        [panel makeKeyAndVisible];

        // 关闭时隐藏 window（需要持有引用避免被释放）
        static NSMutableArray *debugWindows;
        static dispatch_once_t once;
        dispatch_once(&once, ^{ debugWindows = [NSMutableArray array]; });
        [debugWindows addObject:panel];

        void(^dismiss)(void) = ^{
            panel.hidden = YES;
            [debugWindows removeObject:panel];
        };
        objc_setAssociatedObject(closeBtn, "dismissBlock", dismiss, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [closeBtn addTarget:self action:@selector(onDebugPanelClose:) forControlEvents:UIControlEventTouchUpInside];

        // 60 秒后自动消失
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), dismiss);
    });
}

- (void)onDebugPanelClose:(UIButton *)sender {
    void(^dismiss)(void) = objc_getAssociatedObject(sender, "dismissBlock");
    if (dismiss) dismiss();
}

// 点击通知时打开对应聊天窗口并定位到消息
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(10.0)) {
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSLog(@"[PushDebug] didReceiveNotificationResponse userInfo=%@", userInfo);

    // Debug 面板已关闭
    // [self showPushDebugPanel:userInfo];

    // 本地通知：我们自己存的 channel_id/channel_type/message_seq
    NSString *channelId = userInfo[@"channel_id"];
    NSNumber *channelType = userInfo[@"channel_type"];
    NSNumber *messageSeq = userInfo[@"message_seq"];

    // 远程推送（APNs）：服务端可能用不同的字段名
    if (!channelId || channelId.length == 0) {
        channelId = userInfo[@"channelID"] ?: userInfo[@"channel_ID"];
        channelType = userInfo[@"channelType"] ?: userInfo[@"channel_Type"];
        messageSeq = userInfo[@"messageSeq"] ?: userInfo[@"message_Seq"];
    }

    if (channelId.length > 0 && channelType) {
        [self navigateToChannel:channelId channelType:channelType messageSeq:messageSeq retryCount:0];
    }
    completionHandler();
}

// 跳转到聊天窗口，冷启动时导航栈未就绪则延迟重试
-(void) navigateToChannel:(NSString *)channelId channelType:(NSNumber *)channelType messageSeq:(NSNumber *)messageSeq retryCount:(NSInteger)retryCount {
    // 检查是否已登录且导航栈就绪（冷启动时需要等登录+主页加载完成）
    BOOL isReady = [WKNavigationManager shared].topViewController != nil
                && [WKApp shared].loginInfo.uid.length > 0
                && [WKApp shared].loginInfo.token.length > 0;

    if (!isReady) {
        if (retryCount >= 20) return; // 最多重试 20 次（10 秒）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self navigateToChannel:channelId channelType:channelType messageSeq:messageSeq retryCount:retryCount + 1];
        });
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        WKChannel *channel = [WKChannel channelID:channelId channelType:channelType.integerValue];

        // 如果当前已经在相同 channel 的聊天窗口，直接定位消息，不再 push 新页面
        UIViewController *topVC = [WKNavigationManager shared].topViewController;
        if ([topVC isKindOfClass:[WKConversationVC class]]) {
            WKConversationVC *existingVC = (WKConversationVC *)topVC;
            if ([existingVC.channel.channelId isEqualToString:channel.channelId]
                && existingVC.channel.channelType == channel.channelType) {
                if (messageSeq && messageSeq.unsignedIntValue > 0) {
                    [existingVC locateToMessageSeq:messageSeq.unsignedIntValue];
                }
                return;
            }
        }

        WKConversationVC *vc = [WKConversationVC new];
        vc.channel = channel;
        if (messageSeq && messageSeq.unsignedIntValue > 0) {
            uint32_t orderSeq = [[WKSDK shared].chatManager getOrderSeq:messageSeq.unsignedIntValue];
            if (orderSeq == 0) {
                orderSeq = messageSeq.unsignedIntValue;
            }
            vc.locationAtOrderSeq = orderSeq;
        }
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    });
}

// 前台收到通知时仍然显示横幅
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler API_AVAILABLE(ios(10.0)) {
    completionHandler(UNNotificationPresentationOptionBadge);
}

@end
