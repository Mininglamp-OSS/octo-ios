//
//  WKSwitchItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/1/22.
//

#import "WuKongBase.h"
#import "WKViewItemCell.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKSwitchItemModel : WKViewItemModel

@property(nonatomic,strong) NSNumber *on;

@property(nonatomic,assign) BOOL disable;

@property(nonatomic,strong) void(^onSwitch)(BOOL);

@end

@interface WKSwitchItemCell : WKViewItemCell

@end

NS_ASSUME_NONNULL_END
