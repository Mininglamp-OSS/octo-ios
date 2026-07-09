//
//  WKChannelHistoryMediaRowCell.m
//

#import "WKChannelHistoryMediaRowCell.h"
#import "WKChannelHistoryHighlighter.h"
#import "WKApp.h"
#import "WKTimeTool.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import <SDWebImage/SDWebImage.h>

#define kRowMediaHeight 88.0f
#define kThumbSize      56.0f
#define kHPadding       16.0f
#define kGap            12.0f

@interface WKChannelHistoryMediaRowCell ()
@property (nonatomic, strong) UIImageView *thumbView;
@property (nonatomic, strong) UIImageView *playBadge;       // 视频角标
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UILabel *metaLbl;
@property (nonatomic, strong) UIView *separator;
@end

@implementation WKChannelHistoryMediaRowCell

+ (NSString *)reuseIdentifier { return NSStringFromClass(self); }
+ (CGFloat)cellHeight { return kRowMediaHeight; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

        _thumbView = [UIImageView new];
        _thumbView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.08];
        _thumbView.layer.cornerRadius = 6.0f;
        _thumbView.layer.masksToBounds = YES;
        _thumbView.contentMode = UIViewContentModeScaleAspectFill;
        [self.contentView addSubview:_thumbView];

        _playBadge = [UIImageView new];
        _playBadge.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
        _playBadge.layer.cornerRadius = 12.0f;
        _playBadge.layer.masksToBounds = YES;
        _playBadge.hidden = YES;
        // 用 unicode 三角形占位（与项目其它地方对视频角标的简化处理一致；如需自定义图标可改 image）
        UILabel *tri = [UILabel new];
        tri.text = @"▶";
        tri.textColor = [UIColor whiteColor];
        tri.font = [UIFont systemFontOfSize:12.0f];
        tri.textAlignment = NSTextAlignmentCenter;
        tri.frame = CGRectMake(0, 0, 24, 24);
        [_playBadge addSubview:tri];
        [self.contentView addSubview:_playBadge];

        _nameLbl = [UILabel new];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        [self.contentView addSubview:_nameLbl];

        _metaLbl = [UILabel new];
        _metaLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _metaLbl.textColor = [UIColor grayColor];
        _metaLbl.numberOfLines = 1;
        _metaLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_metaLbl];

        _separator = [UIView new];
        _separator.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.12];
        [self.contentView addSubview:_separator];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.lim_width;
    CGFloat h = self.contentView.lim_height;
    self.thumbView.frame = CGRectMake(kHPadding, (h - kThumbSize) / 2.0f, kThumbSize, kThumbSize);
    self.playBadge.frame = CGRectMake(CGRectGetMaxX(self.thumbView.frame) - 24.0f - 4.0f,
                                       CGRectGetMaxY(self.thumbView.frame) - 24.0f - 4.0f,
                                       24.0f, 24.0f);
    CGFloat textX = CGRectGetMaxX(self.thumbView.frame) + kGap;
    CGFloat textW = w - textX - kHPadding;
    self.nameLbl.frame = CGRectMake(textX, (h / 2.0f) - 22.0f, textW, 20.0f);
    self.metaLbl.frame = CGRectMake(textX, (h / 2.0f) + 2.0f, textW, 16.0f);
    self.separator.frame = CGRectMake(textX, h - 0.5f, w - textX, 0.5f);
}

- (void)applyItem:(WKChannelHistorySearchItem *)item keyword:(NSString *)keyword {
    self.nameLbl.text = item.senderName.length > 0 ? item.senderName : @" ";
    NSMutableArray *meta = [NSMutableArray array];
    NSString *kindLbl = item.mediaKind == WKChannelHistorySearchMediaKindVideo ? LLang(@"视频") : LLang(@"图片");
    [meta addObject:kindLbl];
    if (item.timestamp > 0) {
        [meta addObject:[WKTimeTool searchResultTimeString:[NSDate dateWithTimeIntervalSince1970:item.timestamp]]];
    }
    self.metaLbl.text = [meta componentsJoinedByString:@" · "];

    NSString *thumb = item.thumbUrl.length > 0 ? item.thumbUrl : item.previewUrl;
    if (thumb.length == 0) thumb = item.originalUrl;
    if (thumb.length > 0) {
        // 见 WKChannelHistoryMediaGridCell.m 同源注释, 走 getImageFullUrl: 兜相对 URL。
        [self.thumbView sd_setImageWithURL:[[WKApp shared] getImageFullUrl:thumb]
                          placeholderImage:nil];
    } else {
        self.thumbView.image = nil;
    }
    self.playBadge.hidden = item.mediaKind != WKChannelHistorySearchMediaKindVideo;
}

@end
