//
//  WKCheckBoxCell.h
//  WuKongBase
//
//  Created by tt on 2023/9/28.
//

#import "WKViewItemCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKCheckBoxModel : WKViewItemModel

@property(nonatomic,assign) BOOL on;
@property(nonatomic,copy) void(^onCheck)(BOOL on);

@end



@interface WKCheckBoxCell : WKViewItemCell

@end

NS_ASSUME_NONNULL_END
