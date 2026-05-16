//
//  WKLottieStickerCell.h
//  WuKongBase
//
//  Created by tt on 2021/8/26.
//

#import <WuKongBase/WuKongBase.h>
//#import <SDWebImageLottieCoder/SDWebImageLottieCoder.h>
#import "WKStickerImageView.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKLottieStickerCell : WKMessageCell

@property(nonatomic,strong) WKStickerImageView *animatedImageView;

@end

NS_ASSUME_NONNULL_END
