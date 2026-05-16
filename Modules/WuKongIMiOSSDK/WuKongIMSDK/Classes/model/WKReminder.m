//
//  WKReminder.m
//  WuKongIMSDK
//
//  Created by tt on 2022/4/19.
//

#import "WKReminder.h"

@implementation WKReminder

+(instancetype) initWithType:(WKReminderType)type text:(NSString*)text data:(NSDictionary*)data {
    WKReminder *reminder = [WKReminder new];
    reminder.type = type;
    reminder.text = text;
    reminder.data = data;
    return reminder;
}

-(NSDictionary*) toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"type"] = @(self.type);
    dict[@"text"] = self.text?:@"";
    if(self.data) {
        dict[@"data"] = self.data;
    }
    return dict;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKReminder *reminder = [WKReminder allocWithZone:zone];
    reminder.reminderID = self.reminderID;
    reminder.messageId = self.messageId;
    reminder.messageSeq = self.messageSeq;
    reminder.channel = [self.channel copy];
    reminder.type = self.type;
    reminder.text = [self.text copy];
    reminder.data = [self.data copy];
    reminder.isLocate = self.isLocate;
    reminder.version = self.version;
    reminder.done = self.done;
    reminder.uploadStatus = self.uploadStatus;
    reminder.publisher = self.publisher;
    return reminder;
    
}

@end
