//
//  WKLottieStickerCell.m
//  WuKongBase
//
//  Created by tt on 2021/8/26.
//

#import "WKLottieStickerCell.h"
#import "WKLottieStickerContent.h"
#import "WKStickerImageView.h"
#import <WuKongBase/WuKongBase-Swift.h>

#define WKLottieImgSize CGSizeMake(160.0f,160.0f)

@interface WKLottieStickerCell ()


@end

@implementation WKLottieStickerCell

- (void)onWillDisplay {
    self.animatedImageView.isPlay = true;
}

- (void)onEndDisplay {
    self.animatedImageView.isPlay = false;
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    
    return WKLottieImgSize;
}

-(void) initUI {
    [super initUI];
    
    [self.messageContentView addSubview:self.animatedImageView];
    [self.messageContentView bringSubviewToFront:self.trailingView];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.animatedImageView.isPlay = false;
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    
    WKLottieStickerContent *content = (WKLottieStickerContent*)model.content;
    
    self.animatedImageView.placehoderSvg = content.placeholder; // placehoderSvg必须现在stickerURL的前面
    self.animatedImageView.stickerURL = [[WKApp shared] getFileFullUrl:content.url];
    
    
}

- (void)onTap {
    WKLottieStickerContent *content = (WKLottieStickerContent*)self.messageModel.content;
    
    [WKApp.shared invoke:WKPOINT_TO_STICKER_INFO param:@{
        @"category":content.category?:@"",
        @"sticker_url":content.url?:@"",
        @"placeholder_svg":content.placeholder?:@"",
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (BOOL)tailWrap {
    return true;
}

+ (BOOL)hiddenBubble {
    return YES;
}

- (WKStickerImageView *)animatedImageView {
    if(!_animatedImageView) {
        _animatedImageView = [[WKStickerImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKLottieImgSize.width, WKLottieImgSize.height)];
        [_animatedImageView setUserInteractionEnabled:NO];
//        _animatedImageView.shouldCustomLoopCount = NO;
//        _animatedImageView.animationRepeatCount = 0;
//        _animatedImageView.clearBufferWhenStopped = YES;
    }
    return _animatedImageView;
}

@end
