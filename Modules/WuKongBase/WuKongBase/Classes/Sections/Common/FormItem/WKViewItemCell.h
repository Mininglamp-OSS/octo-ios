//
//  WKViewItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/1/22.
//

#import "WKFormItemCell.h"
#import "WKFormItemModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKViewItemModel : WKFormItemModel

@property(nonatomic,copy) NSString *label;

@property(nonatomic,copy) UIColor *labelColor;

@end

@interface WKViewItemCell : WKFormItemCell
@property(nonatomic,strong) UILabel *labelLbl;
@property(nonatomic,strong) UIView *valueView;

@end

NS_ASSUME_NONNULL_END
