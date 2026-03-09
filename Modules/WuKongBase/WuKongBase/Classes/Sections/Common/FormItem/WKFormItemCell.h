//
//  WKFormItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import "WKCell.h"
#import "WKFormItemModel.h"
#import "UIView+WK.h"
#import "WKConstant.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKFormItemCell : WKCell

@property(nonatomic,strong) UIImageView *arrowImgView; // 箭头

+(CGSize) sizeForModel:(WKFormItemModel*)model;

-(void) refresh:(WKFormItemModel*)model;

-(void) onWillDisplay;

-(void) onEndDisplay;
@end

NS_ASSUME_NONNULL_END
