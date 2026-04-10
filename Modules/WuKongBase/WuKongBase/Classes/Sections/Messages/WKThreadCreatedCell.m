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

@interface WKThreadCreatedCell ()

@property (nonatomic, strong) UIView *connectLineView;   // 连接线（有源消息时显示）
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) WKUserAvatar *creatorAvatar; // 创建者头像
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UILabel *timeLbl;        // 创建时间（右对齐）
@property (nonatomic, strong) UILabel *threadNameLbl;
@property (nonatomic, strong) UILabel *actionLbl;
@property (nonatomic, strong) WKMessageModel *model;
@property (nonatomic, assign) BOOL hasSourceMessage;

@end

@implementation WKThreadCreatedCell

#define CARD_WIDTH  300.0f
#define CARD_HEIGHT 66.0f
#define CARD_PADDING 12.0f
#define CARD_CORNER_RADIUS 10.0f
#define CONNECT_LINE_HEIGHT 20.0f

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
    WKThreadCreatedContent *content = (WKThreadCreatedContent *)model.content;
    if (content.sourceMessageId.length > 0) {
        // 有源消息：连接线 + 卡片 + 底部间距
        return CGSizeMake(CARD_WIDTH, CONNECT_LINE_HEIGHT + CARD_HEIGHT + 8.0f);
    }
    // 无源消息：卡片 + 底部间距
    return CGSizeMake(CARD_WIDTH, CARD_HEIGHT + 12.0f);
}

- (void)initUI {
    [super initUI];

    [self.contentView addSubview:self.connectLineView];
    [self.contentView addSubview:self.cardView];
    [self.cardView addSubview:self.creatorAvatar];
    [self.cardView addSubview:self.titleLbl];
    [self.cardView addSubview:self.timeLbl];
    [self.cardView addSubview:self.threadNameLbl];
    [self.cardView addSubview:self.actionLbl];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onCardTap)];
    [self.cardView addGestureRecognizer:tap];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    self.model = model;

    WKThreadCreatedContent *content = (WKThreadCreatedContent *)model.content;
    self.hasSourceMessage = (content.sourceMessageId.length > 0);

    self.titleLbl.text = [NSString stringWithFormat:@"%@ 发起了子区", content.creatorName];

    // 时间右对齐
    if (model.message.timestamp > 0) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:model.message.timestamp];
        self.timeLbl.text = [WKTimeTool getTimeStringAutoShort2:date mustIncludeTime:YES];
    } else {
        self.timeLbl.text = @"";
    }
    self.threadNameLbl.text = [NSString stringWithFormat:@"「%@」", content.threadName];

    if (content.messageCount > 0) {
        self.actionLbl.text = [NSString stringWithFormat:@"%ld条 >", (long)content.messageCount];
    } else {
        self.actionLbl.text = @"查看子区";
    }

    // 设置创建者头像
    NSString *avatarUrl = [WKAvatarUtil getAvatar:content.creatorUid];
    [self.creatorAvatar setUrl:avatarUrl];

    // 连接线显示/隐藏
    self.connectLineView.hidden = !self.hasSourceMessage;

    [self.cardView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.model) return;

    CGFloat cardTop = 0;

    if (self.hasSourceMessage) {
        // 连接线：从顶部到卡片，居中偏左（对齐气泡左侧）
        CGFloat lineX = self.lim_width / 2.0f - CARD_WIDTH / 2.0f + 24.0f;
        self.connectLineView.frame = CGRectMake(lineX, 0, 2.0f, CONNECT_LINE_HEIGHT);
        cardTop = CONNECT_LINE_HEIGHT;
    }

    // 卡片居中
    self.cardView.frame = CGRectMake((self.lim_width - CARD_WIDTH) / 2.0f,
                                     cardTop,
                                     CARD_WIDTH,
                                     CARD_HEIGHT);

    // 创建者头像
    self.creatorAvatar.frame = CGRectMake(CARD_PADDING, (CARD_HEIGHT - 28) / 2.0f, 28, 28);

    // 时间（右对齐）
    CGFloat textLeft = self.creatorAvatar.lim_right + 8;
    [self.timeLbl sizeToFit];
    self.timeLbl.frame = CGRectMake(CARD_WIDTH - CARD_PADDING - self.timeLbl.lim_width,
                                    CARD_PADDING,
                                    self.timeLbl.lim_width,
                                    18);

    // 标题（左对齐，宽度到时间左边）
    CGFloat titleMaxWidth = self.timeLbl.lim_left - textLeft - 4;
    self.titleLbl.frame = CGRectMake(textLeft, CARD_PADDING, titleMaxWidth, 18);

    // 子区名（用整行宽度，不受时间标签约束）
    [self.actionLbl sizeToFit];
    CGFloat actionWidth = self.actionLbl.lim_width + 4;
    CGFloat nameMaxWidth = CARD_WIDTH - textLeft - CARD_PADDING - actionWidth;
    self.threadNameLbl.frame = CGRectMake(textLeft, self.titleLbl.lim_bottom + 4, nameMaxWidth, 18);

    // 操作按钮
    self.actionLbl.frame = CGRectMake(CARD_WIDTH - CARD_PADDING - self.actionLbl.lim_width,
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

- (UIView *)connectLineView {
    if (!_connectLineView) {
        _connectLineView = [[UIView alloc] init];
        _connectLineView.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.3];
        _connectLineView.hidden = YES;
    }
    return _connectLineView;
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
