//
//  WKConversationUtil.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/24.
//

#import <Foundation/Foundation.h>
#import "WKConversation.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationUtil : NSObject
// 合并提醒数据
+(NSArray<WKReminder*>*) mergeReminders:(NSArray<WKReminder*>*)source dest:(NSArray<WKReminder*>*)dest;
@end

NS_ASSUME_NONNULL_END
