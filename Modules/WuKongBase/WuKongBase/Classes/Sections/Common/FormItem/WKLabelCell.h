//
//  WKLabelCell.h
//  WuKongWallet
//
//  Created by tt on 2020/9/16.
//

#import "WKFormItemCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKLabelModel : WKFormItemModel

@property(nonatomic,copy) NSString *text;

@property(nonatomic,strong) UIColor *textColor;

@property(nonatomic,strong) NSNumber *width; // label宽度

@property(nonatomic,strong) NSNumber *left;// label左边距离

@property(nonatomic,strong) UIFont *font; // 字体

@property(nonatomic,assign) BOOL center; // 是否居中

@end

@interface WKLabelCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
