//
//  WKButtonItemCell2.h
//  WuKongBase
//
//  Created by tt on 2020/8/17.
//

#import "WKFormItemCell.h"

NS_ASSUME_NONNULL_BEGIN
@interface WKButtonItemModel2 : WKFormItemModel

@property(nonatomic,assign) CGFloat width;
@property(nonatomic,assign) CGFloat height;

@property(nonatomic,copy) NSString *title;

@property(nonatomic,copy) void(^onPressed)(void);

@end

@interface WKButtonItemCell2 : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
