//
//  WKChannelHistoryMediaGridCell.m
//

#import "WKChannelHistoryMediaGridCell.h"
#import "WKApp.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import <SDWebImage/SDWebImage.h>

@interface WKChannelHistoryMediaGridCell ()
@property (nonatomic, strong) UIImageView *thumbView;
@property (nonatomic, strong) UIView *videoOverlay;    // 视频底部渐变背景
@property (nonatomic, strong) UILabel *durationLbl;    // 时长 mm:ss
@property (nonatomic, strong) UIView *playBadge;       // 视频中心播放标
@end

@implementation WKChannelHistoryMediaGridCell

+ (NSString *)reuseIdentifier { return NSStringFromClass(self); }

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.08];
        self.contentView.clipsToBounds = YES;

        _thumbView = [UIImageView new];
        _thumbView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbView.clipsToBounds = YES;
        [self.contentView addSubview:_thumbView];

        _videoOverlay = [UIView new];
        _videoOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
        _videoOverlay.hidden = YES;
        [self.contentView addSubview:_videoOverlay];

        _durationLbl = [UILabel new];
        _durationLbl.font = [UIFont systemFontOfSize:10.0f];
        _durationLbl.textColor = [UIColor whiteColor];
        _durationLbl.textAlignment = NSTextAlignmentRight;
        _durationLbl.hidden = YES;
        [self.contentView addSubview:_durationLbl];

        _playBadge = [UIView new];
        _playBadge.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        _playBadge.layer.cornerRadius = 16.0f;
        _playBadge.layer.masksToBounds = YES;
        _playBadge.hidden = YES;
        UILabel *tri = [UILabel new];
        tri.text = @"▶";
        tri.textColor = [UIColor whiteColor];
        tri.font = [UIFont systemFontOfSize:14.0f];
        tri.textAlignment = NSTextAlignmentCenter;
        tri.frame = CGRectMake(0, 0, 32, 32);
        [_playBadge addSubview:tri];
        [self.contentView addSubview:_playBadge];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.thumbView.frame = self.contentView.bounds;
    CGFloat w = self.contentView.lim_width;
    CGFloat h = self.contentView.lim_height;
    self.videoOverlay.frame = CGRectMake(0, h - 18.0f, w, 18.0f);
    self.durationLbl.frame = CGRectMake(0, h - 16.0f, w - 4.0f, 14.0f);
    self.playBadge.frame = CGRectMake((w - 32.0f) / 2.0f, (h - 32.0f) / 2.0f, 32.0f, 32.0f);
}

- (NSString *)durationStringFromMs:(NSInteger)ms {
    if (ms <= 0) return @"";
    NSInteger sec = ms / 1000;
    NSInteger m = sec / 60;
    NSInteger s = sec % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)s];
}

- (void)applyItem:(WKChannelHistorySearchItem *)item {
    NSString *url = item.thumbUrl.length > 0 ? item.thumbUrl : item.previewUrl;
    if (url.length == 0) url = item.originalUrl;
    if (url.length > 0) {
        // 服务端返回的 URL 可能是相对路径, 走 WKApp.getImageFullUrl: 拼 apiBaseUrl,
        // 与同模块 WKChannelHistoryMediaBrowser.resolveRemoteURL: 同口径 (PR #64 review
        // yujiawei 命中: cells 直接 URLWithString 导致相对 URL thumb 空白, 但 browser
        // 打开又能显示)。
        [self.thumbView sd_setImageWithURL:[[WKApp shared] getImageFullUrl:url] placeholderImage:nil];
    } else {
        self.thumbView.image = nil;
    }
    BOOL isVideo = item.mediaKind == WKChannelHistorySearchMediaKindVideo;
    self.videoOverlay.hidden = !isVideo;
    self.durationLbl.hidden = !isVideo;
    self.playBadge.hidden = !isVideo;
    if (isVideo) {
        self.durationLbl.text = [self durationStringFromMs:item.durationMs];
    }
}

@end
