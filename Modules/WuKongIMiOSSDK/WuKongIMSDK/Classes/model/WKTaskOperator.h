//
//  WKTaskOperator.h
//  WuKongIMSDK
//
//  Created by tt on 2021/4/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKTaskOperator : NSObject

+(WKTaskOperator*) cancel:(void(^)(void))cancel suspend:(void(^)(void))suspend resume:(void(^)(void))resume;

/**
  取消
 */
@property (nonatomic, copy) void(^cancel)(void);

/**
 挂起
 */
@property (nonatomic, copy) void(^suspend)(void);

/**
  恢复
 */
@property (nonatomic, copy) void(^resume)(void);

@end

NS_ASSUME_NONNULL_END
