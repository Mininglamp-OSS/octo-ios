//
//  WKThreadCreatedCell.m
//  WuKongBase
//

#import "WKThreadCreatedCell.h"
#import "WKThreadCreatedContent.h"
#import "WKNavigationManager.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import "WKTimeTool.h"

@interface WKThreadCurveLineView : UIView
@end

@implementation WKThreadCurveLineView
- (void)drawRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat lineX = 0;
    // 从顶部往下画竖线，再弧形转右
    [path moveToPoint:CGPointMake(lineX, 0)];
    CGFloat curveBottom = rect.size.height;
    CGFloat curveRight = 20.0f;
    [path addLineToPoint:CGPointMake(lineX, curveBottom - 12)];
    [path addQuadCurveToPoint:CGPointMake(curveRight, curveBottom)
                 controlPoint:CGPointMake(lineX, curveBottom)];

    path.lineWidth = 2.0f;
    [[[WKApp shared].config.themeColor colorWithAlphaComponent:0.3] setStroke];
    path.lineCapStyle = kCGLineCapRound;
    [path stroke];
}
@end

@interface WKThreadCreatedCell ()

@property (nonatomic, strong) WKThreadCurveLineView *curveLineView; // 弧线（有源消息时）
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) WKUserAvatar *creatorAvatar;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UILabel *timeLbl;
@property (nonatomic, strong) UILabel *threadNameLbl;
@property (nonatomic, strong) UILabel *subtitleLbl;  // 消息预览/提示
@property (nonatomic, strong) UILabel *actionLbl;
@property (nonatomic, strong) WKMessageModel *model;
@property (nonatomic, assign) BOOL hasSourceMessage;

@end

@implementation WKThreadCreatedCell

#define CARD_PADDING 12.0f
#define CARD_CORNER_RADIUS 10.0f

// 有源消息时的布局常量
#define LINKED_CARD_LEFT 56.0f   // 与消息头像右侧对齐
#define LINKED_CARD_HEIGHT 56.0f
#define LINKED_CURVE_WIDTH 24.0f
#define LINKED_CURVE_HEIGHT 18.0f

// 无源消息时的布局常量
#define STANDALONE_CARD_WIDTH 300.0f
#define STANDALONE_CARD_HEIGHT 66.0f

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
    // 判断是否有源消息
    BOOL hasSource = NO;
    if ([model.content isKindOfClass:[WKThreadCreatedContent class]]) {
        WKThreadCreatedContent *content = (WKThreadCreatedContent *)model.content;
        hasSource = (content.sourceMessageId.length > 0);
    }
    if (!hasSource && model.content.contentDict[@"source_message_id"]) {
        hasSource = ([model.content.contentDict[@"source_message_id"] longLongValue] > 0);
    }
    if (hasSource) {
        return CGSizeMake(STANDALONE_CARD_WIDTH, LINKED_CURVE_HEIGHT + LINKED_CARD_HEIGHT + 8.0f);
    }
    return CGSizeMake(STANDALONE_CARD_WIDTH, STANDALONE_CARD_HEIGHT + 12.0f);
}

- (void)initUI {
    [super initUI];

    [self.contentView addSubview:self.curveLineView];
    [self.contentView addSubview:self.cardView];
    [self.cardView addSubview:self.creatorAvatar];
    [self.cardView addSubview:self.titleLbl];
    [self.cardView addSubview:self.timeLbl];
    [self.cardView addSubview:self.threadNameLbl];
    [self.cardView addSubview:self.subtitleLbl];
    [self.cardView addSubview:self.actionLbl];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onCardTap)];
    [self.cardView addGestureRecognizer:tap];

    // 监听子区消息数量更新
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onThreadMessageCountUpdated:) name:WKThreadMessageCountUpdatedNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKThreadMessageCountUpdatedNotification object:nil];
}

/// 获取子区最新消息数量：优先从缓存取，fallback 到 content 的值
- (NSInteger)latestMessageCount:(WKThreadCreatedContent *)content {
    NSNumber *cached = [WKThreadCreatedContent messageCountCache][content.threadChannelId];
    if (cached) {
        return cached.integerValue;
    }
    return content.messageCount;
}

/// 子区消息数量更新通知 → 刷新 cell
- (void)onThreadMessageCountUpdated:(NSNotification *)notification {
    if (self.model) {
        [self refresh:self.model];
    }
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    self.model = model;

    WKThreadCreatedContent *content = nil;
    if ([model.content isKindOfClass:[WKThreadCreatedContent class]]) {
        content = (WKThreadCreatedContent *)model.content;
    }

    // 判断是否有源消息
    BOOL hasSource = NO;
    if (content && content.sourceMessageId.length > 0) {
        hasSource = YES;
    }
    if (!hasSource && model.content.contentDict[@"source_message_id"]) {
        id srcId = model.content.contentDict[@"source_message_id"];
        if ([srcId longLongValue] > 0) {
            hasSource = YES;
            if (content) {
                content.sourceMessageId = [NSString stringWithFormat:@"%lld", [srcId longLongValue]];
            }
        }
    }
    self.hasSourceMessage = hasSource;

    if (self.hasSourceMessage) {
        // Discord 风格：左对齐卡片
        self.creatorAvatar.hidden = YES;
        self.titleLbl.hidden = YES;
        self.timeLbl.hidden = YES;
        self.curveLineView.hidden = NO;

        // 子区名称（加粗）
        self.threadNameLbl.text = content.threadName;
        self.threadNameLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        self.threadNameLbl.textColor = [WKApp shared].config.defaultTextColor;

        // 获取最新消息数量（优先缓存）
        NSInteger latestCount = [self latestMessageCount:content];

        // 副标题
        if (latestCount > 0) {
            self.subtitleLbl.text = [NSString stringWithFormat:@"%ld条消息", (long)latestCount];
        } else {
            self.subtitleLbl.text = @"该子区暂时没有消息。";
        }
        self.subtitleLbl.hidden = NO;

        // 操作
        self.actionLbl.text = @"查看子区 ›";
    } else {
        // 独立卡片：居中样式
        self.creatorAvatar.hidden = NO;
        self.titleLbl.hidden = NO;
        self.timeLbl.hidden = NO;
        self.curveLineView.hidden = YES;
        self.subtitleLbl.hidden = YES;

        self.titleLbl.text = [NSString stringWithFormat:@"%@ 发起了子区", content.creatorName];

        if (model.message.timestamp > 0) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:model.message.timestamp];
            self.timeLbl.text = [WKTimeTool getTimeStringAutoShort2:date mustIncludeTime:YES];
        } else {
            self.timeLbl.text = @"";
        }

        self.threadNameLbl.text = [NSString stringWithFormat:@"「%@」", content.threadName];
        self.threadNameLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        self.threadNameLbl.textColor = [WKApp shared].config.themeColor;

        // 获取最新消息数量（优先缓存）
        NSInteger latestCount = [self latestMessageCount:content];
        if (latestCount > 0) {
            self.actionLbl.text = [NSString stringWithFormat:@"%ld条 >", (long)latestCount];
        } else {
            self.actionLbl.text = @"查看子区";
        }

        NSString *avatarUrl = [WKAvatarUtil getAvatar:content.creatorUid];
        [self.creatorAvatar setUrl:avatarUrl];
    }

    [self.cardView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.model) return;

    if (self.hasSourceMessage) {
        [self layoutLinkedStyle];
    } else {
        [self layoutStandaloneStyle];
    }
}

/// Discord 风格：左对齐 + 弧线连接
- (void)layoutLinkedStyle {
    // 头像中心 X 大约在 15 + 头像宽/2 = 15+19 = 34, 弧线从头像中心下方开始
    CGFloat avatarCenterX = 34.0f;

    // 弧线
    self.curveLineView.frame = CGRectMake(avatarCenterX, 0, LINKED_CURVE_WIDTH, LINKED_CURVE_HEIGHT);

    // 卡片：左对齐，从弧线右端开始
    CGFloat cardLeft = LINKED_CARD_LEFT;
    CGFloat cardWidth = self.lim_width - cardLeft - 15.0f;
    CGFloat cardTop = LINKED_CURVE_HEIGHT;
    self.cardView.frame = CGRectMake(cardLeft, cardTop, cardWidth, LINKED_CARD_HEIGHT);

    // 子区名（第一行，加粗）
    CGFloat innerPadding = CARD_PADDING;
    [self.actionLbl sizeToFit];
    CGFloat actionWidth = self.actionLbl.lim_width;
    CGFloat nameWidth = cardWidth - innerPadding * 2 - actionWidth - 8;
    self.threadNameLbl.frame = CGRectMake(innerPadding, 10, nameWidth, 20);

    // 操作按钮（右上角）
    self.actionLbl.frame = CGRectMake(cardWidth - innerPadding - actionWidth, 10, actionWidth, 20);

    // 副标题（第二行）
    self.subtitleLbl.frame = CGRectMake(innerPadding, self.threadNameLbl.lim_bottom + 4, cardWidth - innerPadding * 2, 16);
}

/// 独立卡片：居中样式
- (void)layoutStandaloneStyle {
    self.cardView.frame = CGRectMake((self.lim_width - STANDALONE_CARD_WIDTH) / 2.0f,
                                     0,
                                     STANDALONE_CARD_WIDTH,
                                     STANDALONE_CARD_HEIGHT);

    self.creatorAvatar.frame = CGRectMake(CARD_PADDING, (STANDALONE_CARD_HEIGHT - 28) / 2.0f, 28, 28);

    CGFloat textLeft = self.creatorAvatar.lim_right + 8;

    [self.timeLbl sizeToFit];
    self.timeLbl.frame = CGRectMake(STANDALONE_CARD_WIDTH - CARD_PADDING - self.timeLbl.lim_width,
                                    CARD_PADDING,
                                    self.timeLbl.lim_width,
                                    18);

    CGFloat titleMaxWidth = self.timeLbl.lim_left - textLeft - 4;
    self.titleLbl.frame = CGRectMake(textLeft, CARD_PADDING, titleMaxWidth, 18);

    [self.actionLbl sizeToFit];
    CGFloat actionWidth = self.actionLbl.lim_width + 4;
    CGFloat nameMaxWidth = STANDALONE_CARD_WIDTH - textLeft - CARD_PADDING - actionWidth;
    self.threadNameLbl.frame = CGRectMake(textLeft, self.titleLbl.lim_bottom + 4, nameMaxWidth, 18);

    self.actionLbl.frame = CGRectMake(STANDALONE_CARD_WIDTH - CARD_PADDING - self.actionLbl.lim_width,
                                      self.threadNameLbl.lim_top,
                                      self.actionLbl.lim_width,
                                      18);
}

#pragma mark - Actions

- (void)onCardTap {
    WKThreadCreatedContent *content = (WKThreadCreatedContent *)self.model.content;
    if (content.threadChannelId.length > 0) {
        WKChannel *channel = [WKChannel channelID:content.threadChannelId channelType:content.threadChannelType];
        [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:channel];
    }
}

#pragma mark - Lazy Init

- (WKThreadCurveLineView *)curveLineView {
    if (!_curveLineView) {
        _curveLineView = [[WKThreadCurveLineView alloc] init];
        _curveLineView.backgroundColor = [UIColor clearColor];
        _curveLineView.hidden = YES;
    }
    return _curveLineView;
}

- (UIView *)cardView {
    if (!_cardView) {
        _cardView = [[UIView alloc] init];
        _cardView.layer.cornerRadius = CARD_CORNER_RADIUS;
        _cardView.layer.masksToBounds = YES;
        _cardView.userInteractionEnabled = YES;
    }
    return _cardView;
}

- (WKUserAvatar *)creatorAvatar {
    if (!_creatorAvatar) {
        _creatorAvatar = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
        _creatorAvatar.userInteractionEnabled = NO;
    }
    return _creatorAvatar;
}

- (UILabel *)titleLbl {
    if (!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [UIFont systemFontOfSize:13];
        _titleLbl.textColor = [UIColor grayColor];
        _titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _titleLbl;
}

- (UILabel *)timeLbl {
    if (!_timeLbl) {
        _timeLbl = [[UILabel alloc] init];
        _timeLbl.font = [UIFont systemFontOfSize:11];
        _timeLbl.textColor = [UIColor lightGrayColor];
        _timeLbl.textAlignment = NSTextAlignmentRight;
    }
    return _timeLbl;
}

- (UILabel *)threadNameLbl {
    if (!_threadNameLbl) {
        _threadNameLbl = [[UILabel alloc] init];
        _threadNameLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        _threadNameLbl.textColor = [WKApp shared].config.themeColor;
        _threadNameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _threadNameLbl;
}

- (UILabel *)subtitleLbl {
    if (!_subtitleLbl) {
        _subtitleLbl = [[UILabel alloc] init];
        _subtitleLbl.font = [UIFont systemFontOfSize:12];
        _subtitleLbl.textColor = [UIColor grayColor];
        _subtitleLbl.hidden = YES;
    }
    return _subtitleLbl;
}

- (UILabel *)actionLbl {
    if (!_actionLbl) {
        _actionLbl = [[UILabel alloc] init];
        _actionLbl.text = @"查看子区";
        _actionLbl.font = [UIFont systemFontOfSize:13];
        _actionLbl.textColor = [WKApp shared].config.themeColor;
    }
    return _actionLbl;
}

@end
