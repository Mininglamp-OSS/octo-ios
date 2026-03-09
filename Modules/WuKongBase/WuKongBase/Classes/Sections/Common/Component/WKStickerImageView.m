//
//  WKStickerImageView.m
//  WuKongBase
//
//  Created by tt on 2022/5/15.
//

#import "WKStickerImageView.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import <SDWebImage/SDWebImage.h>
#import "WuKongBase.h"
@interface WKStickerImageViewInner : SDAnimatedImageView


@property(nonatomic,copy) void(^setImageFinishedBlock)(void);

@end

@interface WKStickerImageView ()

@property(nonatomic,strong) WKStickerImageViewInner *stickerImgView;
@property(nonatomic,strong) StickerShimmerEffectNode *placeholder;

@property(nonatomic,assign) CGSize size;

@end

@implementation WKStickerImageView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.size = frame.size;
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    self.stickerImgView = [[WKStickerImageViewInner alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.size.width, self.size.height)];
    self.stickerImgView.shouldIncrementalLoad = true;
    self.stickerImgView.autoPlayAnimatedImage = false;
    self.stickerImgView.clearBufferWhenStopped = true;
    [self addSubview:self.stickerImgView];
    
//    [self addSubview:self.placeholder.view];
    
}

- (void)setIsPlay:(BOOL)isPlay {
    _isPlay = isPlay;
    if(isPlay) {
        [self.stickerImgView startAnimating];

    }else {
        [self.stickerImgView stopAnimating];
    }
}

- (void)setPlacehoderSvg:(NSString *)placehoderSvg {
    _placehoderSvg = placehoderSvg;
    
}

-(void) renderPlaceholder {
    if(!self.placeholder.view.superview) {
        [self addSubview:self.placeholder.view];
    }
   
    if(self.placehoderSvg && ![self.placehoderSvg isEqualToString:@""]) {
        [self.placeholder updateWithBackgroundColor:nil foregroundColor:[UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f] shimmeringColor:[UIColor colorWithRed:116.0f/255.0f green:131.0f/255.0f blue:145.0f/255.0f alpha:1.0f] data:[self.placehoderSvg dataUsingEncoding:NSUTF8StringEncoding] size:CGSizeMake(self.size.width, self.size.height) imageSize:CGSizeMake(512.0f, 512.0f) isDecode:false];
        
        [self.placeholder updateAbsoluteRect:CGRectMake(0.0f, 0.0f, self.size.width, self.size.height) within:CGSizeMake(self.size.width, self.size.height)];
        
        self.placeholder.frame = self.bounds;
    }else {
        [self.placeholder.view removeFromSuperview];
    }
}

- (void)setStickerURL:(NSURL *)stickerURL {
    BOOL change = false;
    if(![stickerURL.absoluteString isEqualToString:self.stickerURL.absoluteString]) {
        change = true;
    }
    _stickerURL = stickerURL;
    
//    if(!change) {
//        return;
//    }
    
    [self renderPlaceholder];
    
    __weak typeof(self) weakSelf = self;
    CGSize pixelSize = CGSizeMake(self.size.width*2, self.size.height*2);
    
    self.stickerImgView.setImageFinishedBlock = ^{
        [weakSelf.stickerImgView startAnimating];
        [weakSelf removePlaceholder:NO]; // 这里用YES 会导致占位错乱，应该跟动画结束时 cell被复用有关系
    };
    
    UIImage *placeholderImg;
   
    if(!self.placeholder.view.superview) {
        placeholderImg = [WKApp shared].config.defaultStickerPlaceholder;
    }
   
    [self.stickerImgView lim_setImageWithURL:stickerURL placeholderImage:placeholderImg options:0 context:@{
        SDWebImageContextImageThumbnailPixelSize:@(pixelSize), // TODO: 这个大小必须固定 如果中途改变会报 decode error
    }];
    
}


-(void) removePlaceholder:(BOOL) animated {
    if(!animated) {
        [self.placeholder removeFromSupernode];
    }else {
        self.placeholder.alpha = 0.0;
        [self.placeholder.layer animateAlphaFrom:1.0f to:0.0f duration:0.2f delay:0 timingFunction:@"easeInEaseOut" mediaTimingFunction:nil removeOnCompletion:true completion:^(BOOL completion) {
            [self.placeholder removeFromSupernode];
           
        }];
    }
}

- (StickerShimmerEffectNode *)placeholder {
    if(!_placeholder) {
        _placeholder = [[StickerShimmerEffectNode alloc] init];
        [_placeholder setUserInteractionEnabled:false];
    }
    return _placeholder;
}


@end



@implementation WKStickerImageViewInner

- (void)setImage:(UIImage *)image {
    [super setImage:image];
    if(image && self.setImageFinishedBlock) {
        self.setImageFinishedBlock();
    }
}


@end
