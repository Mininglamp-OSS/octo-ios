//
//  WKTextViewVC.h
//  WuKongBase
//
//  Created by tt on 2022/10/13.
//

#import "WuKongBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKTextViewVC : WKBaseVC
/**
 占位符
 */
@property(nonatomic,copy) NSString *placeholder;

@property(nonatomic,assign) BOOL editable; // 是否可编辑 默认是true

/**
 默认值
 */
@property(nonatomic,copy) NSString *defaultValue;


// 最大长度限制
@property(nonatomic,assign) NSInteger maxLength;

// 提示
@property(nonatomic,copy) NSString *tip;


/**
 完成回调
 */
@property(nonatomic,copy) void(^onFinish)(NSString *value);

@end

NS_ASSUME_NONNULL_END
