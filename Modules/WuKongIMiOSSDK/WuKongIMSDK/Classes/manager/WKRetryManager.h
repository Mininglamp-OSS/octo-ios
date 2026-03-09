//
//  WKRetryManager.h
//  WuKongIMBase
//
//  Created by tt on 2019/12/29.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
#import "WKReminder.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKRetryItem : NSObject
// 消息
@property(nonatomic,strong) WKMessage *message;
@property(nonatomic,strong) WKMessageExtra *messageExtra;
@property(nonatomic,strong) WKReminder *reminder;
// 重试次数
@property(nonatomic,assign) long retryCount;
// 下次重试时间
@property(nonatomic,assign) long nextRetryTime;

@property(nonatomic,assign) long nextRetryTime2;


@end

@interface WKRetryManager : NSObject

+ (WKRetryManager *)shared;


/**
 开启重试
 */
-(void) start;


/**
 停止重试
 */
-(void) stop;
/**
 添加重试项

 @param message 消息
 */
-(void) add:(WKMessage*)message;

-(void) addMessageExtra:(WKMessageExtra*)messageExtra;

/**
 移除重试项

 @param key key
 */
-(void) removeRetryItem:(NSString*) key;

-(void) removeMessageExtraRetryItem:(NSString*) key;

-(void) addReminder:(WKReminder*)reminder;
-(void) removeReminderRetryItem:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
