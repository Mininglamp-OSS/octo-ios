//
//  WKButtonItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/1/27.
//

#import "WKFormItemCell.h"
#import "WKFormItemModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKButtonItemModel : WKFormItemModel

@property(nonatomic,copy) NSString *title;

@property(nonatomic,strong) UIColor *color;

@end

@interface WKButtonItemCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
