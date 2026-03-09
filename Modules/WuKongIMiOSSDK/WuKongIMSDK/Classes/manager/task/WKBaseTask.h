//
//  WKBaseTask.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/16.
//

#import <Foundation/Foundation.h>
#import "WKTaskProto.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKBaseTask : NSObject<WKTaskProto>

/**
 错误 如果任务下载失败，则有值
 */
@property(nullable,nonatomic,strong) NSError *error;

/**
 下载进度
 */
@property(nonatomic,assign) CGFloat progress;

@end

NS_ASSUME_NONNULL_END
