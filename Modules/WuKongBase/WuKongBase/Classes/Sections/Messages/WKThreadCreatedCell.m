// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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
#import "WKThreadService.h"
#import "WKThreadModel.h"
#import <WuKongIMSDK/WKMessageDB.h>

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

@property (nonatomic, strong) UIView *quoteView;      // 引用消息缩略条
@property (nonatomic, strong) UIView *quoteBar;       // 引用左侧竖线
@property (nonatomic, strong) UILabel *quoteLbl;      // 引用消息文本
@property (nonatomic, strong) WKThreadCurveLineView *curveLineView; // 弧线（不再使用，保留兼容）
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

#define CARD_WIDTH  300.0f
#define CARD_HEIGHT 66.0f
#define QUOTE_HEIGHT 24.0f  // 引用消息缩略行高度

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
    BOOL hasSource = NO;
    if ([model.content isKindOfClass:[WKThreadCreatedContent class]]) {
        WKThreadCreatedContent *content = (WKThreadCreatedContent *)model.content;
        hasSource = (content.sourceMessageId.length > 0);
    }
    if (!hasSource && model.content.contentDict[@"source_message_id"]) {
        hasSource = ([model.content.contentDict[@"source_message_id"] longLongValue] > 0);
    }
    if (hasSource) {
        // 有源消息：引用行 + 卡片 + 间距
        return CGSizeMake(CARD_WIDTH, QUOTE_HEIGHT + CARD_HEIGHT + 12.0f);
    }
    return CGSizeMake(CARD_WIDTH, CARD_HEIGHT + 12.0f);
}

- (void)initUI {
    [super initUI];

    [self.contentView addSubview:self.quoteView];
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

    // 引用消息缩略（有 sourceMessageId 时显示）
    self.quoteView.hidden = !self.hasSourceMessage;
    if (self.hasSourceMessage && content) {
        // 从 contentDict 获取引用的消息内容
        NSDictionary *lastMsg = content.contentDict[@"last_message"];
        if (lastMsg && [lastMsg isKindOfClass:[NSDictionary class]]) {
            NSString *fromName = lastMsg[@"from_name"] ?: @"";
            NSString *msgContent = lastMsg[@"content"] ?: @"";
            self.quoteLbl.text = [NSString stringWithFormat:@"%@: %@", fromName, msgContent];
        } else {
            self.quoteLbl.text = LLang(@"引用消息");
        }
    }
    self.subtitleLbl.hidden = YES;
    self.creatorAvatar.hidden = NO;
    self.titleLbl.hidden = NO;
    self.timeLbl.hidden = NO;

    // 头像
    NSString *avatarUrl = [WKAvatarUtil getAvatar:content.creatorUid];
    [self.creatorAvatar setUrl:avatarUrl];

    // 标题
    self.titleLbl.text = [NSString stringWithFormat:@"%@ 发起了子区", content.creatorName];

    // 时间（右对齐）
    if (model.message.timestamp > 0) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:model.message.timestamp];
        self.timeLbl.text = [WKTimeTool getTimeStringAutoShort2:date mustIncludeTime:YES];
    } else {
        self.timeLbl.text = @"";
    }

    // 子区名称
    self.threadNameLbl.text = [NSString stringWithFormat:@"「%@」", content.threadName];
    self.threadNameLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.threadNameLbl.textColor = [WKApp shared].config.themeColor;

    // 消息条数
    NSInteger latestCount = [self latestMessageCount:content];
    if (latestCount > 0) {
        self.actionLbl.text = [NSString stringWithFormat:@"%ld条 >", (long)latestCount];
    } else {
        self.actionLbl.text = @"查看子区";
    }

    [self.cardView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.model) return;

    CGFloat cardTop = 0;

    if (self.hasSourceMessage) {
        // 引用消息缩略条
        CGFloat quoteLeft = (self.lim_width - CARD_WIDTH) / 2.0f;
        self.quoteView.frame = CGRectMake(quoteLeft, 0, CARD_WIDTH, QUOTE_HEIGHT);
        self.quoteBar.frame = CGRectMake(0, 2, 3, QUOTE_HEIGHT - 4);
        self.quoteLbl.frame = CGRectMake(10, 2, CARD_WIDTH - 14, QUOTE_HEIGHT - 4);
        cardTop = QUOTE_HEIGHT;
    }

    // 卡片居中
    self.cardView.frame = CGRectMake((self.lim_width - CARD_WIDTH) / 2.0f,
                                     cardTop,
                                     CARD_WIDTH,
                                     CARD_HEIGHT);

    // 头像
    self.creatorAvatar.frame = CGRectMake(CARD_PADDING, (CARD_HEIGHT - 28) / 2.0f, 28, 28);

    CGFloat textLeft = self.creatorAvatar.lim_right + 8;

    // 时间（右对齐）
    [self.timeLbl sizeToFit];
    self.timeLbl.frame = CGRectMake(CARD_WIDTH - CARD_PADDING - self.timeLbl.lim_width,
                                    CARD_PADDING,
                                    self.timeLbl.lim_width,
                                    18);

    // 标题
    CGFloat titleMaxWidth = self.timeLbl.lim_left - textLeft - 4;
    self.titleLbl.frame = CGRectMake(textLeft, CARD_PADDING, titleMaxWidth, 18);

    // 条数/操作（右对齐）
    [self.actionLbl sizeToFit];
    CGFloat actionWidth = self.actionLbl.lim_width + 4;
    self.actionLbl.frame = CGRectMake(CARD_WIDTH - CARD_PADDING - self.actionLbl.lim_width,
                                      self.titleLbl.lim_bottom + 4,
                                      self.actionLbl.lim_width,
                                      18);

    // 子区名称
    CGFloat nameMaxWidth = CARD_WIDTH - textLeft - CARD_PADDING - actionWidth;
    self.threadNameLbl.frame = CGRectMake(textLeft, self.titleLbl.lim_bottom + 4, nameMaxWidth, 18);
}

#pragma mark - Actions

- (void)onCardTap {
    WKThreadCreatedContent *content = (WKThreadCreatedContent *)self.model.content;
    if (content.threadChannelId.length == 0) return;

    // 解析 groupNo 和 shortId
    NSRange sep = [content.threadChannelId rangeOfString:@"____"];
    if (sep.location == NSNotFound) {
        WKChannel *channel = [WKChannel channelID:content.threadChannelId channelType:content.threadChannelType];
        [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:channel];
        return;
    }
    NSString *groupNo = [content.threadChannelId substringToIndex:sep.location];
    NSString *shortId = [content.threadChannelId substringFromIndex:sep.location + sep.length];

    // 先查询子区状态，防止打开已关闭的子区
    [[WKThreadService shared] getThread:groupNo shortId:shortId].then(^(WKThreadModel *thread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (thread.isDeleted || thread.status == WKThreadStatusDeleted) {
                [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"该子区已被关闭")];
            } else {
                WKChannel *channel = [WKChannel channelID:content.threadChannelId channelType:content.threadChannelType];
                [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:channel];
            }
        });
    }).catch(^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *errMsg = error.domain ?: @"";
            if ([errMsg containsString:@"deleted"] || [errMsg containsString:@"已关闭"]) {
                [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"该子区已被关闭")];
            } else {
                // 其他网络错误降级直接打开
                WKChannel *channel = [WKChannel channelID:content.threadChannelId channelType:content.threadChannelType];
                [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:channel];
            }
        });
    });
}

- (void)onQuoteTap {
    if (![self.model.content isKindOfClass:[WKThreadCreatedContent class]]) return;
    WKThreadCreatedContent *content = (WKThreadCreatedContent *)self.model.content;
    if (content.sourceMessageId.length == 0) return;

    // 从 sourceMessageId 查找消息的 messageSeq，然后定位
    uint64_t sourceId = (uint64_t)[content.sourceMessageId longLongValue];
    WKMessage *sourceMsg = [[WKMessageDB shared] getMessageWithMessageId:sourceId];
    if (sourceMsg && sourceMsg.messageSeq > 0) {
        [self.conversationContext locateMessageCell:sourceMsg.messageSeq];
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

- (UIView *)quoteView {
    if (!_quoteView) {
        _quoteView = [[UIView alloc] init];
        _quoteView.hidden = YES;
        _quoteView.userInteractionEnabled = YES;

        _quoteBar = [[UIView alloc] init];
        _quoteBar.backgroundColor = [WKApp shared].config.themeColor;
        _quoteBar.layer.cornerRadius = 1.5f;
        [_quoteView addSubview:_quoteBar];

        _quoteLbl = [[UILabel alloc] init];
        _quoteLbl.font = [UIFont systemFontOfSize:12];
        _quoteLbl.textColor = [UIColor grayColor];
        _quoteLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [_quoteView addSubview:_quoteLbl];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onQuoteTap)];
        [_quoteView addGestureRecognizer:tap];
    }
    return _quoteView;
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
