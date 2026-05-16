//
//  WKTextFielItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/10/30.
//

#import "WKFormItemCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKTextFieldItemModel : WKFormItemModel

@property(nonatomic,copy) NSString *label;
@property(nonatomic,copy) NSString *placeholder;

@property(nonatomic,assign) BOOL password; // 是否是密码模式
@property(nonatomic,assign) NSNumber *keyboardType; // 键盘类型
@property(nonatomic,strong) NSNumber *maxLen;

@property(nonatomic,copy) void(^onChange)(NSString *value);

@end

@interface WKTextFieldItemCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
