//
//  WKIconItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/1/22.
//

#import  "WuKongBase.h"
#import "WKViewItemCell.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKIconItemModel : WKViewItemModel

@property(nonatomic,strong) NSNumber *width;
@property(nonatomic,strong) NSNumber *height;

@property(nonatomic,strong) UIImage *icon;

@end

@interface WKIconItemCell : WKViewItemCell

@property(nonatomic,strong) UIImageView *iconImgView;

@end

NS_ASSUME_NONNULL_END
