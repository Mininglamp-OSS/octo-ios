//
//  WKTaskManager.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/15.
//

#import <Foundation/Foundation.h>
#import "WKTaskProto.h"
NS_ASSUME_NONNULL_BEGIN

@protocol WKTaskManagerDelegate <NSObject>

@optional


/**
 任务完成

 @param task <#task description#>
 */
-(void) taskComplete:(id<WKTaskProto>)task;


/**
 任务进度

 @param task <#task description#>
 */
-(void) taskProgress:(id<WKTaskProto>)task;

@end

@interface WKTaskManager : NSObject

@property(nonatomic,weak) id<WKTaskManagerDelegate> delegate;

/**
 添加任务

 @param task <#task description#>
 */
-(void) add:(id<WKTaskProto>)task;


/**
 获取任务

 @param taskId <#taskId description#>
 */
-(id<WKTaskProto> __nullable) get:(NSString *)taskId;
/**
 移除任务

 @param task <#task description#>
 */
-(void) remove:(id<WKTaskProto>)task;

@end

NS_ASSUME_NONNULL_END
