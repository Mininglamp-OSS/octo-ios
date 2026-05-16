//
//  WKCountdownFormItemCell.h
//  WuKongBase
//
//  Created by tt on 2022/11/21.
//

#import "WKCell.h"
#import "WKLabelItemCell.h"
#import "UIView+WK.h"
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKCountdownFormItemModel: WKLabelItemModel

@property(nonatomic,assign) NSInteger second;

@end

@interface WKCountdownFormItemCell : WKLabelItemCell

@end

NS_ASSUME_NONNULL_END
