//
//  WKMulitLabelItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/1/30.
//


#import "WKFormItemCell.h"
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKMultiLabelItemModeUpDown, // 标题和值采用上下布局
    WKMultiLabelItemModeLeftRight, // 标题和值才有左右布局
} WKMultiLabelItemMode;

@interface WKMultiLabelItemModel : WKFormItemModel
// label
@property(nonatomic,copy) NSString *label;
// value
@property(nonatomic,copy) NSString *value;

@property(nonatomic,strong) NSNumber *mode; // WKMultiLabelItemMode

@end

@interface WKMultiLabelItemCell : WKFormItemCell



@end

NS_ASSUME_NONNULL_END
