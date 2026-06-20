//
//  WKGIFMessageCell.m
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import "WKGIFMessageCell.h"
#import <SDWebImage/SDWebImage.h>
#import "WKGIFContent.h"
#import "UIImage+WK.h"
#import "WKResource.h"
#import "WKImageView.h"
#define WK_GIF_MAX_WIDTH 150.0f


@interface WKGIFMessageCell ()

// 不直接用 SDAnimatedImageView 是因为它在某些 iOS 版本上播放速度被 SDDisplayLink
// 的 frameInterval 翻倍（实测 4×）。WKImageView 已经在 init 里 set playbackRate
// 补偿，所以直接用它就有正确速度。
@property(nonatomic,strong) WKImageView *imgView;

@end

@implementation WKGIFMessageCell

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    WKGIFContent *content = (WKGIFContent*)model.content;
    CGFloat width = content.width;
    CGFloat height = content.height;
    if(content.width <= 0) {
        width = 100.0f;
    }
    if(content.height <= 0) {
        height = 100.0f;
    }
    return  [UIImage lim_sizeWithImageOriginSize:CGSizeMake(width, height) maxLength:WK_GIF_MAX_WIDTH];
}

- (void)initUI {
    [super initUI];
    self.imgView = [[WKImageView alloc] init];
    [self.imgView setSd_imageIndicator:SDWebImageActivityIndicator.grayIndicator];
    self.imgView.layer.masksToBounds = YES;
    self.imgView.layer.cornerRadius = 5.0f;
    // 与 WKImageMessageCell 同一套策略: 关掉自动播放, 由 onWillDisplay/onEndDisplay
    // 通过 wk_setDisplayed: 控制可见性 —— 否则 cell 滚出屏后 CADisplayLink 仍在跑,
    // 主线程会持续被踩, 正是 PR 在 WKImageMessageCell 修过的同一个 HANG。
    self.imgView.autoPlayAnimatedImage = NO;
    [self.messageContentView addSubview:self.imgView];
    [self.messageContentView sendSubviewToBack:self.imgView];
}

- (void)onWillDisplay {
    [super onWillDisplay];
    [self.imgView wk_setDisplayed:YES];
}

- (void)onEndDisplay {
    [super onEndDisplay];
    [self.imgView wk_setDisplayed:NO];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    WKGIFContent *content = (WKGIFContent*)model.content;
    [self.imgView lim_setImageWithURL:[[WKApp shared] getImageFullUrl:content.url]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.imgView.lim_size = self.messageContentView.lim_size;
    
    
}

- (BOOL)tailWrap {
    return true;
}


+(BOOL) hiddenBubble {
    return YES;
}

- (void)layoutTrailingView {
    [super layoutTrailingView];
    // 与 WKImageMessageCell 同口径: 时间胶囊离图片右下沿太近, 各再推 10pt / 5pt 留出
    // 明显呼吸 (底部 ~15pt 内缩, 右沿 ~10pt 内缩), 横/竖动图都更耐看。
    self.trailingView.lim_top  -= 10.0f;
    self.trailingView.lim_left -= 5.0f;
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}
@end
