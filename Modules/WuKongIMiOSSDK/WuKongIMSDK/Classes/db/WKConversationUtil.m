//
//  WKConversationUtil.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/24.
//

#import "WKConversationUtil.h"

@implementation WKConversationUtil

// 合并提醒数据
+(NSArray<WKReminder*>*) mergeReminders:(NSArray<WKReminder*>*)source dest:(NSArray<WKReminder*>*)dest {
    if(!source || source.count<=0) {
        return dest;
    }
    if(!dest || dest.count<=0) {
        return source;
    }
    NSMutableArray<WKReminder*> *newReminders = [NSMutableArray arrayWithArray:dest];
    for (WKReminder *reminderSource in source) {
        BOOL has = false;
        for (WKReminder *reminderDest in dest) {
            if(reminderSource.type == reminderDest.type) {
                has = true;
                break;
            }
        }
        if(!has) {
            [newReminders addObject:reminderSource];
        }
    }
    return newReminders;
}

@end
