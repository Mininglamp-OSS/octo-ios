//
//  WKReminderManager.h
//  WuKongIMSDK
//
//  Created by tt on 2022/4/19.
//

#import <Foundation/Foundation.h>
#import "WKReminder.h"
@class WKReminderManager;
NS_ASSUME_NONNULL_BEGIN

// 消息提醒提供
typedef void(^WKReminderCallback)(NSArray<WKReminder*> * __nullable reminders,NSError * __nullable error);
typedef void(^WKReminderProvider)(WKReminderCallback callback);


// 消息提醒done提供
typedef void(^WKReminderDoneCallback)(NSError * __nullable error);
typedef void(^WKReminderDoneProvider)(NSArray<NSNumber*> *ids,WKReminderDoneCallback callback);

@protocol WKReminderManagerDelegate <NSObject>

@optional

// 某个频道的reminders发生变化
-(void) reminderManager:(WKReminderManager*)manager didChange:(WKChannel*)channel reminders:(NSArray<WKReminder*>*) reminders;

@end

@interface WKReminderManager : NSObject

+ (WKReminderManager *)shared;

-(void) sync;

-(void) done:(NSArray<NSNumber*>*)ids;

/**
 添加委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKReminderManagerDelegate>) delegate;


/**
 移除委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKReminderManagerDelegate>) delegate;

@property(nonatomic,copy) WKReminderProvider reminderProvider; // 消息提醒项内容同步提供者
@property(nonatomic,copy) WKReminderDoneProvider reminderDoneProvider; // 消息提醒项完成提供者



@end

NS_ASSUME_NONNULL_END
