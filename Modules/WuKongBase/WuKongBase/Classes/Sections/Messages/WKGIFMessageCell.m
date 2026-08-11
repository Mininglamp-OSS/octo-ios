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
    // 竞态兜底: 复用/漂移下错配的非 WKGIFContent 会 unrecognized selector 崩 (同 WKImageMessageCell)
    if (![model.content isKindOfClass:[WKGIFContent class]]) {
        // 早退前取消在飞请求 + 清图: super refresh: 已经把气泡换成新 model, 动图还留着
        // 上一条的 —— 那是"别的消息的图配这条", 可能跨会话。只 nil image 不够: SDWebImage
        // 只在发起新请求时才取消上一个 operation, 而这条分支不发起新请求, 上一条的回调
        // 之后仍会把旧图装上。只在错配这条异常路径上跑, 正常动图消息不经过。
        [self.imgView sd_cancelCurrentImageLoad];
        self.imgView.image = nil;
        return;
    }
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
