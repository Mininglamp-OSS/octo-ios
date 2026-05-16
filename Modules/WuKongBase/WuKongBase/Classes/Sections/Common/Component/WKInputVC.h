//
//  WKInputVC.h
//  WuKongBase
//
//  Created by tt on 2020/1/27.
//

#import <UIKit/UIKit.h>
#import "WKBaseVC.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKInputVC : WKBaseVC


/**
 占位符
 */
@property(nonatomic,copy) NSString *placeholder;


/**
 默认值
 */
@property(nonatomic,copy) NSString *defaultValue;

// 最大长度限制
@property(nonatomic,assign) NSInteger maxLength;


/**
 完成回调
 */
@property(nonatomic,copy) void(^onFinish)(NSString *value);

@end

NS_ASSUME_NONNULL_END
