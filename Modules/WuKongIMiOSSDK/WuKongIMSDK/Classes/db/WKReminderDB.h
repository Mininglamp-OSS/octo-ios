//
//  WKReminderDB.h
//  WuKongIMSDK
//
//  Created by tt on 2022/4/19.
//

#import <Foundation/Foundation.h>
#import "WKReminder.h"
#import "WKChannel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKReminderDB : NSObject

+ (WKReminderDB *)shared;

-(void) addOrUpdates:(NSArray<WKReminder*>*)reminders;

/**
 获取等待done的提醒项
 */
-(NSDictionary<WKChannel*,NSArray<WKReminder*>*>*) getWaitDoneReminders:(NSArray<WKChannel*>*) channels;

-(NSArray<WKReminder*>*) getWaitDoneReminder:(WKChannel*) channel;

-(NSArray<WKReminder*>*) getWaitDoneReminders:(WKChannel*)channel type:(WKReminderType)type;

// 获取所有等待完成的提醒
-(NSDictionary<WKChannel*,NSArray<WKReminder*>*>*) getAllWaitDoneReminders;


-(int64_t) getMaxVersion;

// 将对应id的提醒更新为done状态
-(void) updateDone:(NSArray<NSNumber*>*)ids;

// 更新过期的done=1的数据的上传状态为失败
-(void) updateExpireDoneUploadStatusFail:(NSInteger)expireTime;

-(void) updateUploadStatus:(WKReminderUploadStatus)status reminderID:(NSNumber*)reminderID;

-(NSArray<WKReminder*>*) getWaitUploads;

// 获取提醒项列表
-(NSArray<WKReminder*>*) getReminders:(NSArray<NSNumber*>*)ids;

@end

NS_ASSUME_NONNULL_END
