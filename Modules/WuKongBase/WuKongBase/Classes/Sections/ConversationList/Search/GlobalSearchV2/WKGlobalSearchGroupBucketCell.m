//
//  WKGlobalSearchGroupBucketCell.m
//  WuKongBase
//

#import "WKGlobalSearchGroupBucketCell.h"
#import "WKChannelHistoryHighlighter.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import "WKApp.h"
#import "WKTimeTool.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"

#define kBucketAvatarSize 48.0f
#define kBucketHPadding   16.0f
#define kBucketVPadding   12.0f
#define kBucketAvatarGap  10.0f
#define kBucketRowHeight  76.0f
#define kBucketPreviewMaxLen 40

@interface WKGlobalSearchGroupBucketCell ()
@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UILabel *timeLbl;
@property (nonatomic, assign) CGFloat measuredTimeWidth;
@property (nonatomic, strong) UILabel *previewLbl;   // 高亮预览片段
@property (nonatomic, strong) UILabel *countLbl;     // 「约N条」
@property (nonatomic, assign) CGFloat measuredCountWidth;
@property (nonatomic, strong) UIImageView *chevron;
@property (nonatomic, strong) UIView *separator;
@end

@implementation WKGlobalSearchGroupBucketCell

+ (NSString *)reuseIdentifier { return NSStringFromClass(self); }
+ (CGFloat)cellHeight { return kBucketRowHeight; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

        _avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_avatarView];

        _titleLbl = [UILabel new];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        _titleLbl.textColor = [WKApp shared].config.defaultTextColor;
        _titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLbl];

        _timeLbl = [UILabel new];
        _timeLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _timeLbl.textColor = [UIColor grayColor];
        _timeLbl.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_timeLbl];

        _previewLbl = [UILabel new];
        _previewLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
        _previewLbl.textColor = [UIColor grayColor];
        _previewLbl.numberOfLines = 1;
        _previewLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_previewLbl];

        _countLbl = [UILabel new];
        _countLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _countLbl.textColor = [WKApp shared].config.themeColor;
        _countLbl.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_countLbl];

        _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        _chevron.tintColor = [[UIColor grayColor] colorWithAlphaComponent:0.6];
        _chevron.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_chevron];

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

    CGFloat avatarY = (h - kBucketAvatarSize) / 2.0f;
    self.avatarView.frame = CGRectMake(kBucketHPadding, avatarY, kBucketAvatarSize, kBucketAvatarSize);

    // chevron 右侧固定
    CGFloat chevW = 10.0f;
    self.chevron.frame = CGRectMake(w - kBucketHPadding - chevW, (h - 14.0f) / 2.0f, chevW, 14.0f);

    CGFloat textX = CGRectGetMaxX(self.avatarView.frame) + kBucketAvatarGap;
    CGFloat textRight = self.chevron.lim_left - 8.0f;
    CGFloat textW = textRight - textX;

    // 第一行：名称 + 时间
    CGFloat timeW = MIN(self.measuredTimeWidth, MAX(textW - 60.0f, 40.0f));
    self.timeLbl.frame = CGRectMake(textRight - timeW, kBucketVPadding + 2.0f, timeW, 16.0f);
    self.titleLbl.frame = CGRectMake(textX, kBucketVPadding, textW - timeW - 6.0f, 18.0f);

    // 第二行：预览片段 + 约N条
    CGFloat line2Y = CGRectGetMaxY(self.titleLbl.frame) + 6.0f;
    CGFloat countW = MIN(self.measuredCountWidth, MAX(textW - 60.0f, 40.0f));
    self.countLbl.frame = CGRectMake(textRight - countW, line2Y, countW, 16.0f);
    self.previewLbl.frame = CGRectMake(textX, line2Y, textW - countW - 8.0f, 18.0f);

    self.separator.frame = CGRectMake(textX, h - 0.5f, w - textX, 0.5f);
}

- (void)applyBucket:(WKGlobalSearchGroupBucket *)bucket keyword:(nullable NSString *)keyword {
    UIColor *theme = [WKApp shared].config.themeColor;

    // 头像：群/子区用群头像（子区取父群），私聊用对端用户头像。
    NSString *avatarUrl = nil;
    if (bucket.isDM) {
        avatarUrl = bucket.channelId.length > 0 ? [WKAvatarUtil getAvatar:bucket.channelId] : nil;
    } else if (bucket.isThread) {
        NSString *g = bucket.parentGroupNo.length > 0 ? bucket.parentGroupNo : bucket.channelId;
        avatarUrl = g.length > 0 ? [WKAvatarUtil getGroupAvatar:g] : nil;
    } else {
        avatarUrl = bucket.channelId.length > 0 ? [WKAvatarUtil getGroupAvatar:bucket.channelId] : nil;
    }
    self.avatarView.url = avatarUrl;

    self.titleLbl.text = bucket.displayTitle.length > 0 ? bucket.displayTitle : @" ";

    NSString *timeStr = bucket.latestAt > 0
        ? [WKTimeTool searchResultTimeString:[NSDate dateWithTimeIntervalSince1970:bucket.latestAt]]
        : @"";
    self.timeLbl.text = timeStr;
    CGSize tSize = [timeStr sizeWithAttributes:@{ NSFontAttributeName: self.timeLbl.font }];
    self.measuredTimeWidth = timeStr.length > 0 ? ceil(tSize.width) + 2.0f : 0;

    // 约N条：match_count 恒近似，显示「约N条」。
    NSString *countStr = [self countTextForBucket:bucket];
    self.countLbl.text = countStr;
    CGSize cSize = [countStr sizeWithAttributes:@{ NSFontAttributeName: self.countLbl.font }];
    self.measuredCountWidth = countStr.length > 0 ? ceil(cSize.width) + 2.0f : 0;

    // 预览：取 preview[0] 的 snippet，按 <mark>/keyword 居中截断后高亮。
    NSString *previewText = [self previewTextForBucket:bucket];
    if (previewText.length > 0) {
        NSString *centered = [WKChannelHistoryHighlighter centerSnippetFromServerText:previewText
                                                                              keyword:keyword
                                                                            maxLength:kBucketPreviewMaxLen];
        self.previewLbl.attributedText = [WKChannelHistoryHighlighter attributedFromText:centered
                                                                                 keyword:keyword
                                                                                    font:self.previewLbl.font
                                                                               textColor:[UIColor grayColor]
                                                                          highlightColor:theme];
    } else {
        self.previewLbl.text = @"";
    }

    [self setNeedsLayout];
}

- (NSString *)countTextForBucket:(WKGlobalSearchGroupBucket *)bucket {
    if (bucket.matchCount <= 0) return @"";
    if (bucket.matchCountApprox) {
        return [NSString stringWithFormat:LLang(@"约%ld条"), (long)bucket.matchCount];
    }
    return [NSString stringWithFormat:LLang(@"%ld条"), (long)bucket.matchCount];
}

- (NSString *)previewTextForBucket:(WKGlobalSearchGroupBucket *)bucket {
    WKChannelHistorySearchItem *first = bucket.preview.firstObject;
    if (!first) return @"";
    NSString *sender = first.senderName;
    NSString *body = first.snippet.length > 0 ? first.snippet : first.richTextPlain;
    if (body.length == 0 && first.quotedText.length > 0) body = first.quotedText;
    if (body.length == 0) return @"";
    // 预览行前缀发送人名（群/子区里有多人，前缀更清晰；私聊省略）。
    if (!bucket.isDM && sender.length > 0) {
        return [NSString stringWithFormat:@"%@: %@", sender, body];
    }
    return body;
}

@end
