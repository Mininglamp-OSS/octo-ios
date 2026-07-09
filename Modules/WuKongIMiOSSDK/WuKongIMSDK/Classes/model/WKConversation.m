//
//  WKConversation.m
//  WuKongIMSDK
//
//  Created by tt on 2019/12/8.
//

#import "WKConversation.h"
#import "WKChannelManager.h"
#import "WKMessageDB.h"
#import "WKSDk.h"

@interface WKConversation ()

@property(nonatomic,strong) NSMutableArray<WKReminder*> *simpleReminderInners;

@end

@implementation WKConversation


-(WKChannelInfo*) channelInfo {
    return [[WKChannelManager shared] getChannelInfo:self.channel];
}


- (WKMessage *)lastMessage {
    if(!_lastMessage) {
        if(self.lastClientMsgNo && ![self.lastClientMsgNo isEqualToString:@""]) {
            _lastMessage = [[WKMessageDB shared] getMessageWithClientMsgNo:self.lastClientMsgNo];
        }
        
    }
    return _lastMessage;
}

-(WKMessage*)lastMessageInner {
    return _lastMessage;
}

- (void)setLastMessageInner:(WKMessage *)lastMessageInner {
    _lastMessage = lastMessageInner;
}

- (void)setReminders:(NSArray<WKReminder *> *)reminders {
    _reminders = reminders;
    NSMutableArray *newSimpleReminderArray = [NSMutableArray array];
    NSString *selfUid = WKSDK.shared.options.connectInfo.uid;
    if(reminders&&reminders.count>0) {

        for (WKReminder *reminder  in reminders) {
            if(reminder.publisher && WKSDK.shared.options.connectInfo && [reminder.publisher isEqualToString:WKSDK.shared.options.connectInfo.uid]) {
                continue;
            }
            // 兜底校验：服务端偶发下发脏的 @我 reminder（消息实际未 @ 到自己），
            // 客户端拿到消息本体后按 mention.uids/humans/all 复核；若消息在本地
            // 明确未 @ 到自己，则不进入 simpleReminders，避免会话/子区 cell 上
            // 挂出"没人@我 却提醒"的假 badge。消息未同步到本地时保守放行。
            // 对齐 web 端 ConversationWrap.isMentionMe 的"看 mention.uids"分支。
            if(![WKConversation isReminderTrustworthy:reminder selfUid:selfUid]) {
                continue;
            }
            BOOL exist = false;
            NSInteger i = 0;
            for (WKReminder *simpleReminder in newSimpleReminderArray) {
                if(reminder.type == simpleReminder.type) {
                    exist = true;
                    break;
                }
                i++;
            }
            if(!exist) {
                [newSimpleReminderArray addObject:reminder];
            }else {
                newSimpleReminderArray[i] = reminder;
            }

        }
    }
    self.simpleReminderInners = newSimpleReminderArray;
}

/// 校验 @我 reminder 是否可信：只有当本地已经拿到 reminder 指向的消息，且能
/// 明确判断该消息「没有 @ 到自己」（uids 不含自己 + humans=0 + type 非 All/Humans）
/// 时才拒绝，其它情况一律放行（避免误伤）。返回 NO 表示丢弃。
+ (BOOL)isReminderTrustworthy:(WKReminder *)reminder selfUid:(NSString *)selfUid {
    if(!reminder) {
        return YES;
    }
    // 非 @我 reminder 走原路
    if(reminder.type != WKReminderTypeMentionMe) {
        return YES;
    }
    // selfUid / messageId 缺失，无法校验，保守放行
    if(!selfUid || selfUid.length == 0) {
        return YES;
    }
    if(reminder.messageId == 0) {
        return YES;
    }
    WKMessage *msg = [[WKMessageDB shared] getMessageWithMessageId:reminder.messageId];
    if(!msg) {
        // 消息未同步到本地（长时间未登录后 reminder 先到达）：保守放行，
        // 后续消息补齐 / 用户进入会话时若真是脏 reminder，可靠 orphan-check
        // 或 done 上报兜底
        return YES;
    }
    WKMentionedInfo *mi = msg.content.mentionedInfo;
    if(!mi) {
        // content 未解析出 mentionedInfo（老消息 / 解析失败）：无法反证，放行
        return YES;
    }
    // 广播型 @：@所有人 / @所有人类，视为可能命中人类自己，放行
    if(mi.type == WK_Mentioned_All || mi.type == WK_Mentioned_Humans || mi.humans) {
        return YES;
    }
    // 明确 @ 到自己
    if(mi.uids && [mi.uids containsObject:selfUid]) {
        return YES;
    }
    // 消息在本地 + mention 信息完整 + 明确未 @ 自己 → 判定为服务端脏 reminder
    #if DEBUG
    NSLog(@"[ReminderTrace] drop fake mention reminder: channelId=%@ msgId=%llu msgSeq=%u uids=%@ humans=%d selfUid=%@",
          reminder.channel.channelId, reminder.messageId, reminder.messageSeq,
          mi.uids, mi.humans, selfUid);
    #endif
    return NO;
}


- (NSArray<WKReminder *> *)simpleReminders {
    return self.simpleReminderInners;
}

- (WKConversationExtra *)remoteExtra {
    if(!_remoteExtra) {
        _remoteExtra = [[WKConversationExtra alloc] init];
        _remoteExtra.channel = self.channel;
    }
    return _remoteExtra;
}

-(void) reloadLastMessage {
    _lastMessage = [[WKMessageDB shared] getMessageWithClientMsgNo:self.lastClientMsgNo?:@""];
}



- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKConversation *conversation = [WKConversation allocWithZone:zone];
    conversation.channel = [self.channel copy];
    if(conversation.parentChannel) {
        conversation.parentChannel = [self.parentChannel copy];
    }
    if(self.avatar) {
        conversation.avatar = [self.avatar copy];
    }
    if(self.lastClientMsgNo) {
        conversation.lastClientMsgNo = [self.lastClientMsgNo copy];
    }
    conversation.lastMessageSeq = self.lastMessageSeq;
    conversation.lastMessage = self.lastMessage;
    conversation.lastMessageInner = self.lastMessageInner;
    conversation.lastMsgTimestamp = self.lastMsgTimestamp;
    conversation.unreadCount = self.unreadCount;
    conversation.simpleReminderInners = self.simpleReminderInners;
    conversation.reminders = self.reminders;
    conversation.extra = self.extra;
    conversation.version = self.version;
    conversation.mute = self.mute;
    conversation.stick = self.stick;
    conversation.remoteExtra = self.remoteExtra;
    
    return conversation;
}
@end
