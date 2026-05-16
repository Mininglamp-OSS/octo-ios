//
//  WKTask.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKTaskStatusWait, // 任务等待执行
     WKTaskStatusSuccess, // 任务执行成功
    WKTaskStatusProgressing, // 任务处理中
    WKTaskStatusSuspend, // 任务挂起
    WKTaskStatusError, // 任务执行错误
     WKTaskStatusCancel, // 任务执行错误
} WKTaskStatus;

typedef void(^WKTaskListener)(void);


@protocol WKTaskProto <NSObject>


/**
 设置任务监听者
 */
@property(nonatomic,copy,readonly) NSArray<WKTaskListener> *listeners;

/**
 任务唯一ID
 */
@property(nonatomic,copy) NSString *taskId;


/**
 任务状态
 */
@property(nonatomic,assign) WKTaskStatus status;


/**
 添加监听者

 @param listener 监听者
 @param target 目标
 */
- (void)addListener:(nonnull WKTaskListener)listener target:(id) target;


/**
 移除监听者

 @param target <#target description#>
 */
-(void) removeListener:(id) target;

/**
 恢复任务
 */
-(void) resume;
/**
 暂停任务
 */
-(void) suspend;


/**
取消任务
 */
-(void) cancel;


/**
 任务更新
 */
-(void) update;


@end

NS_ASSUME_NONNULL_END
