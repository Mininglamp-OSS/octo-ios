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
    if(reminders&&reminders.count>0) {
        
        for (WKReminder *reminder  in reminders) {
            if(reminder.publisher && WKSDK.shared.options.connectInfo && [reminder.publisher isEqualToString:WKSDK.shared.options.connectInfo.uid]) {
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
