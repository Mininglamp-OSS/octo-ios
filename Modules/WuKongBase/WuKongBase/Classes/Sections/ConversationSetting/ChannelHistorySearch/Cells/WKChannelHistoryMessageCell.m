//
//  WKChannelHistoryMessageCell.m
//

#import "WKChannelHistoryMessageCell.h"
#import "WKChannelHistoryHighlighter.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import "WKApp.h"
#import "WKTimeTool.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"

#define kAvatarSize 36.0f
#define kHPadding   16.0f
#define kVPadding   12.0f
#define kAvatarGap  10.0f
#define kSnippetGap 4.0f
// snippet 至少留出 2 行显示 (14pt system 单行 ~19pt)。原来是 34pt/一行半, UIKit 会
// clip 掉第二行, 用户视觉只看到一行。改成 44pt 保 2 行渲染。
#define kSnippetLineH 22.0f
#define kSnippetLines 2
// 合并转发卡片
#define kCardHPadding 12.0f
#define kCardVPadding 10.0f
#define kCardIndent   12.0f   // 卡片相对左侧文本区的进一步缩进 (视觉上像"引用块")
#define kCardCorner   8.0f
#define kCardTitleH   20.0f
#define kCardInnerLineH 20.0f
#define kForwardInnerLimit 4
// snippet 居中截断字符上限 — 兼顾 2 行渲染 (系统 14pt CJK 约 40 字, 拉丁 60+)。
#define kSnippetCenterMaxLen 60

static NSInteger WKCHS_ClampInt(NSInteger v, NSInteger lo, NSInteger hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

@interface WKChannelHistoryMessageCell ()
@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UILabel *timeLbl;
@property (nonatomic, assign) CGFloat measuredTimeWidth; // 按实际字号测量, 避免固定宽度截断
@property (nonatomic, strong) UILabel *snippetLbl;     // 非合并转发的主体内容, 最多 2 行
@property (nonatomic, strong) UILabel *reasonLbl;      // 命中理由 (合并转发 / 富文本)
@property (nonatomic, strong) UIView *separator;

// 合并转发卡片
@property (nonatomic, strong) UIView *forwardCardBg;
@property (nonatomic, strong) UIView *forwardCardBar;   // 卡片左边 2pt 主题色竖条
@property (nonatomic, strong) UILabel *forwardTitleLbl;
@property (nonatomic, strong) NSMutableArray<UILabel *> *forwardInnerLbls;
@property (nonatomic, strong) UILabel *forwardMoreLbl;
@end

@implementation WKChannelHistoryMessageCell

+ (NSString *)reuseIdentifier { return NSStringFromClass(self); }

#pragma mark - height calc

+ (NSInteger)visibleInnerCountForItem:(WKChannelHistorySearchItem *)item {
    return WKCHS_ClampInt((NSInteger)item.innerMessages.count, 0, kForwardInnerLimit);
}

+ (NSInteger)hiddenInnerCountForItem:(WKChannelHistorySearchItem *)item visible:(NSInteger)visible {
    NSInteger totalKnown = (NSInteger)item.innerMessages.count;
    NSInteger childCount = item.forwardChildCount;
    NSInteger total = (childCount > totalKnown) ? childCount : totalKnown;
    return MAX(0, total - visible);
}

+ (CGFloat)forwardCardHeightForItem:(WKChannelHistorySearchItem *)item {
    NSInteger visible = [self visibleInnerCountForItem:item];
    NSInteger hidden = [self hiddenInnerCountForItem:item visible:visible];
    CGFloat h = kCardVPadding * 2;
    h += kCardTitleH;               // 标题行
    h += visible * kCardInnerLineH; // 前 N 条子消息
    if (hidden > 0) h += kCardInnerLineH; // "还有 N 条聊天记录"
    return h;
}

+ (BOOL)itemNeedsReasonLine:(WKChannelHistorySearchItem *)item {
    if (item.matchReason.length > 0) return YES;
    if (item.messageKind == WKChannelHistorySearchMessageKindForward) return YES;
    return NO;
}

+ (CGFloat)heightForItem:(WKChannelHistorySearchItem *)item width:(CGFloat)width {
    CGFloat h = kVPadding + 18.0f; // top padding + name line
    if ([self itemNeedsReasonLine:item]) {
        h += kSnippetGap + 16.0f;
    }
    if (item.messageKind == WKChannelHistorySearchMessageKindForward
        && item.innerMessages.count > 0) {
        h += 6.0f + [self forwardCardHeightForItem:item];
    } else {
        h += kSnippetGap + (kSnippetLineH * kSnippetLines);
    }
    h += kVPadding;
    return h;
}

#pragma mark - init

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

        _avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(kHPadding, kVPadding, kAvatarSize, kAvatarSize)];
        [self.contentView addSubview:_avatarView];

        _nameLbl = [UILabel new];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        [self.contentView addSubview:_nameLbl];

        _timeLbl = [UILabel new];
        _timeLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _timeLbl.textColor = [UIColor grayColor];
        _timeLbl.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_timeLbl];

        _reasonLbl = [UILabel new];
        _reasonLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _reasonLbl.textColor = [UIColor grayColor];
        _reasonLbl.numberOfLines = 1;
        _reasonLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_reasonLbl];

        _snippetLbl = [UILabel new];
        _snippetLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        _snippetLbl.textColor = [WKApp shared].config.defaultTextColor;
        _snippetLbl.numberOfLines = kSnippetLines;
        _snippetLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_snippetLbl];

        [self setupForwardCard];

        _separator = [UIView new];
        _separator.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.12];
        [self.contentView addSubview:_separator];
    }
    return self;
}

- (void)setupForwardCard {
    _forwardCardBg = [UIView new];
    _forwardCardBg.layer.cornerRadius = kCardCorner;
    _forwardCardBg.layer.masksToBounds = YES;
    _forwardCardBg.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.06];
    _forwardCardBg.hidden = YES;
    [self.contentView addSubview:_forwardCardBg];

    _forwardCardBar = [UIView new];
    _forwardCardBar.backgroundColor = [WKApp shared].config.themeColor;
    [_forwardCardBg addSubview:_forwardCardBar];

    _forwardTitleLbl = [UILabel new];
    _forwardTitleLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
    _forwardTitleLbl.textColor = [WKApp shared].config.defaultTextColor;
    _forwardTitleLbl.numberOfLines = 1;
    _forwardTitleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    [_forwardCardBg addSubview:_forwardTitleLbl];

    _forwardInnerLbls = [NSMutableArray arrayWithCapacity:kForwardInnerLimit];
    for (NSInteger i = 0; i < kForwardInnerLimit; i++) {
        UILabel *l = [UILabel new];
        l.font = [[WKApp shared].config appFontOfSize:12.0f];
        l.textColor = [UIColor darkGrayColor];
        l.numberOfLines = 1;
        l.lineBreakMode = NSLineBreakByTruncatingTail;
        [_forwardCardBg addSubview:l];
        [_forwardInnerLbls addObject:l];
    }

    _forwardMoreLbl = [UILabel new];
    _forwardMoreLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    _forwardMoreLbl.textColor = [UIColor grayColor];
    [_forwardCardBg addSubview:_forwardMoreLbl];
}

#pragma mark - layout

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.lim_width;
    CGFloat h = self.contentView.lim_height;

    self.avatarView.frame = CGRectMake(kHPadding, kVPadding, kAvatarSize, kAvatarSize);
    CGFloat textX = CGRectGetMaxX(self.avatarView.frame) + kAvatarGap;
    CGFloat textW = w - textX - kHPadding;

    // time 按 applyItem 时预测的宽度定位, 保证 "yyyy-MM-dd HH:mm:ss" 完整可见。
    // 名称行至少给 60pt (太窄的话回退到用一半剩余空间给时间, 避免名字完全被吞)。
    CGFloat timeW = MIN(self.measuredTimeWidth, MAX(textW - 60.0f, 60.0f));
    self.timeLbl.frame = CGRectMake(w - kHPadding - timeW, kVPadding + 2.0f, timeW, 16.0f);
    self.nameLbl.frame = CGRectMake(textX, kVPadding, textW - timeW - 6.0f, 18.0f);

    CGFloat cursorY = CGRectGetMaxY(self.nameLbl.frame) + kSnippetGap;
    if (!self.reasonLbl.hidden) {
        self.reasonLbl.frame = CGRectMake(textX, cursorY, textW, 16.0f);
        cursorY = CGRectGetMaxY(self.reasonLbl.frame) + 2.0f;
    }

    if (!self.forwardCardBg.hidden) {
        CGFloat cardX = textX + kCardIndent;
        CGFloat cardW = w - cardX - kHPadding;
        CGFloat cardH = h - cursorY - kVPadding;
        self.forwardCardBg.frame = CGRectMake(cardX, cursorY + 4.0f, cardW, cardH - 4.0f);
        [self layoutForwardCardContent];
    } else {
        CGFloat snippetH = h - cursorY - kVPadding;
        if (snippetH < kSnippetLineH) snippetH = kSnippetLineH;
        self.snippetLbl.frame = CGRectMake(textX, cursorY, textW, snippetH);
    }

    self.separator.frame = CGRectMake(textX, h - 0.5f, w - textX, 0.5f);
}

- (void)layoutForwardCardContent {
    CGFloat w = self.forwardCardBg.lim_width;
    CGFloat innerX = 2.0f + kCardHPadding;
    CGFloat innerW = w - innerX - kCardHPadding;

    self.forwardCardBar.frame = CGRectMake(0, 0, 2.0f, self.forwardCardBg.lim_height);

    CGFloat y = kCardVPadding;
    self.forwardTitleLbl.frame = CGRectMake(innerX, y, innerW, kCardTitleH);
    y = CGRectGetMaxY(self.forwardTitleLbl.frame);

    for (UILabel *l in self.forwardInnerLbls) {
        if (l.hidden) continue;
        l.frame = CGRectMake(innerX, y, innerW, kCardInnerLineH);
        y = CGRectGetMaxY(l.frame);
    }
    if (!self.forwardMoreLbl.hidden) {
        self.forwardMoreLbl.frame = CGRectMake(innerX, y, innerW, kCardInnerLineH);
    }
}

#pragma mark - apply

- (void)applyItem:(WKChannelHistorySearchItem *)item keyword:(NSString *)keyword {
    UIColor *theme = [WKApp shared].config.themeColor;

    self.nameLbl.text = item.senderName.length > 0 ? item.senderName : @" ";
    NSString *timeStr = item.timestamp > 0
        ? [WKTimeTool searchResultTimeString:[NSDate dateWithTimeIntervalSince1970:item.timestamp]]
        : @"";
    self.timeLbl.text = timeStr;
    // 用实际字号预测时间宽度, 避免 "yyyy-MM-dd HH:mm:ss" (19 字) 被 72pt 硬截。
    // ceil + 2pt 抗抖动 (Retina 字宽偶尔小数变化)。
    CGSize tSize = [timeStr sizeWithAttributes:@{ NSFontAttributeName: self.timeLbl.font }];
    self.measuredTimeWidth = timeStr.length > 0 ? ceil(tSize.width) + 2.0f : 0;
    NSString *avatarUrl = nil;
    if (item.senderAvatarUrl.length > 0) {
        avatarUrl = [WKAvatarUtil getFullAvatarWIthPath:item.senderAvatarUrl];
    } else if (item.senderId.length > 0) {
        avatarUrl = [WKAvatarUtil getAvatar:item.senderId];
    }
    self.avatarView.url = avatarUrl;

    BOOL isForward = (item.messageKind == WKChannelHistorySearchMessageKindForward);

    // ----- reason 行 -----
    NSString *reasonText = item.matchReason;
    if (reasonText.length == 0 && isForward) {
        // 合并转发 + 服务端没给 matchReason: 生成「转发聊天记录含"xx"」风格提示。
        // 双引号在 Obj-C 字符串字面量里必须转义 (\"), 中文全角引号 "" 视觉上也可,
        // 但 .strings key 保持转义 ASCII " 与字符串字面量一致, 免得两处对不上。
        NSString *kw = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        reasonText = kw.length > 0
            ? [NSString stringWithFormat:LLang(@"转发聊天记录含\"%@\""), kw]
            : LLang(@"转发聊天记录");
    }
    if (reasonText.length > 0) {
        self.reasonLbl.hidden = NO;
        self.reasonLbl.attributedText = [WKChannelHistoryHighlighter attributedFromSnippet:reasonText
                                                                                       keyword:keyword
                                                                                          font:self.reasonLbl.font
                                                                                     textColor:[UIColor grayColor]
                                                                                highlightColor:theme];
    } else {
        self.reasonLbl.hidden = YES;
        self.reasonLbl.text = nil;
    }

    // ----- 内容区: forward 卡片 vs 普通 snippet -----
    if (isForward && item.innerMessages.count > 0) {
        [self applyForwardCard:item keyword:keyword theme:theme];
        self.snippetLbl.hidden = YES;
        self.snippetLbl.text = nil;
    } else {
        self.forwardCardBg.hidden = YES;
        self.snippetLbl.hidden = NO;
        [self applyPlainSnippet:item keyword:keyword theme:theme];
    }

    [self setNeedsLayout];
}

- (void)applyPlainSnippet:(WKChannelHistorySearchItem *)item keyword:(NSString *)keyword theme:(UIColor *)theme {
    NSString *snippetText = item.snippet ?: @"";
    NSString *plainText = item.richTextPlain ?: @"";

    // 命中源选择: 服务端有时会给两份文本 —
    //   * snippet 是一段"默认预览" (可能只是消息开头/摘要片段, 不含关键词也不含 <mark>)
    //   * rich_text.plain 是完整正文 (Markdown/富文本消息里带 <mark>关键词</mark> 的那份)
    // 只按"snippet 非空就用 snippet"会漏掉 rich_text.plain 里真正命中关键词的正文,
    // 导致 UI 里显示一段无关内容 (例如代码块开头) 而不是关键词附近。
    // 按覆盖度排优先级 (与 web hit.snippet || rich_text.plain 相比是移动端专属优化):
    //   1) snippet 含 <mark>          — 服务端已在 snippet 上明标, 最精准
    //   2) plain   含 <mark>          — snippet 没标但 plain 里标了, 用 plain
    //   3) snippet 含 keyword 文本    — 无 <mark> 但纯文本能匹配到关键词
    //   4) plain   含 keyword 文本    — snippet 里没关键词, plain 里有
    //   5) snippet 非空                — 都没匹配上, 显示 snippet 首段
    //   6) plain   非空                — snippet 都空, 用 plain
    NSString *kw = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL snippetHasMark = [snippetText rangeOfString:@"<mark>" options:NSCaseInsensitiveSearch].location != NSNotFound;
    BOOL plainHasMark = [plainText rangeOfString:@"<mark>" options:NSCaseInsensitiveSearch].location != NSNotFound;
    BOOL snippetHasKeyword = kw.length > 0 && !snippetHasMark
        && [snippetText rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound;
    BOOL plainHasKeyword = kw.length > 0 && !plainHasMark
        && [plainText rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound;

    NSString *snippet = nil;
    if (snippetHasMark) snippet = snippetText;
    else if (plainHasMark) snippet = plainText;
    else if (snippetHasKeyword) snippet = snippetText;
    else if (plainHasKeyword) snippet = plainText;
    else if (snippetText.length > 0) snippet = snippetText;
    else snippet = plainText;

    // 引用消息回退: "@发送人: 引用内容"
    if (snippet.length == 0
        && item.messageKind == WKChannelHistorySearchMessageKindQuote
        && item.quotedText.length > 0) {
        snippet = item.quotedSenderName.length > 0
            ? [NSString stringWithFormat:@"%@: %@", item.quotedSenderName, item.quotedText]
            : item.quotedText;
    }
    // 合并转发无 inner_messages 时的最小兜底 (不会命中此分支, 上层已 isForward 分流)
    if (snippet.length == 0 && item.messageKind == WKChannelHistorySearchMessageKindForward) {
        if (item.forwardChildCount > 0) {
            snippet = [NSString stringWithFormat:LLang(@"共 %ld 条记录"), (long)item.forwardChildCount];
        }
    }
    if (snippet.length > 0) {
        // 按 <mark> 位置 (或 keyword 位置) 做移动端友好的居中截 60 字, 之后交给高亮器渲染。
        snippet = [WKChannelHistoryHighlighter centerSnippetFromServerText:snippet
                                                                       keyword:keyword
                                                                     maxLength:kSnippetCenterMaxLen];
    }
    self.snippetLbl.attributedText = [WKChannelHistoryHighlighter attributedFromText:snippet
                                                                                keyword:keyword
                                                                                   font:self.snippetLbl.font
                                                                              textColor:[WKApp shared].config.defaultTextColor
                                                                         highlightColor:theme];
}

#pragma mark - forward card

- (void)applyForwardCard:(WKChannelHistorySearchItem *)item keyword:(NSString *)keyword theme:(UIColor *)theme {
    self.forwardCardBg.hidden = NO;

    // 标题: 服务端优先, 否则用子数量兜底
    NSString *title = item.forwardTitle;
    if (title.length == 0) {
        title = item.forwardChildCount > 0
            ? [NSString stringWithFormat:LLang(@"%ld条聊天记录"), (long)item.forwardChildCount]
            : LLang(@"聊天记录");
    }
    self.forwardTitleLbl.attributedText = [WKChannelHistoryHighlighter attributedFromSnippet:title
                                                                                         keyword:keyword
                                                                                            font:self.forwardTitleLbl.font
                                                                                       textColor:[WKApp shared].config.defaultTextColor
                                                                                  highlightColor:theme];

    NSInteger visible = [[self class] visibleInnerCountForItem:item];
    for (NSInteger i = 0; i < kForwardInnerLimit; i++) {
        UILabel *l = self.forwardInnerLbls[i];
        if (i < visible) {
            NSDictionary *msg = item.innerMessages[i];
            NSString *line = [self formatInnerMessage:msg];
            l.hidden = NO;
            l.attributedText = [WKChannelHistoryHighlighter attributedFromSnippet:line
                                                                              keyword:keyword
                                                                                 font:l.font
                                                                            textColor:[UIColor darkGrayColor]
                                                                       highlightColor:theme];
        } else {
            l.hidden = YES;
            l.attributedText = nil;
        }
    }

    NSInteger hidden = [[self class] hiddenInnerCountForItem:item visible:visible];
    if (hidden > 0) {
        self.forwardMoreLbl.hidden = NO;
        self.forwardMoreLbl.text = [NSString stringWithFormat:LLang(@"还有 %ld 条聊天记录"), (long)hidden];
    } else {
        self.forwardMoreLbl.hidden = YES;
        self.forwardMoreLbl.text = nil;
    }
}

/// 与 web forwardInnerMessage.formatForwardInnerMessage 同口径:
///   1) 取 message.text (服务端 snippet, 可能含 <mark>), 缺失时按 type 输出占位
///      (图片/视频/文件/普通消息)
///   2) 若已经"senderName："开头则不重复拼, 否则前缀发送人名
- (NSString *)formatInnerMessage:(NSDictionary *)msg {
    if (![msg isKindOfClass:[NSDictionary class]]) return @"";
    NSString *text = [self asString:msg[@"text"]];
    if (text.length == 0) text = [self asString:msg[@"content"]];
    if (text.length == 0) text = [self asString:msg[@"snippet"]];
    if (text.length == 0) {
        text = [self fallbackTextByType:msg];
    }
    NSString *senderName = [self asString:msg[@"sender_name"]];
    if (senderName.length == 0) senderName = [self asString:msg[@"senderName"]];
    if (senderName.length == 0) return text ?: @"";
    // 已有 "senderName:" / "senderName：" 前缀则不重复拼
    NSString *trimmedLead = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([trimmedLead hasPrefix:[NSString stringWithFormat:@"%@:", senderName]]
        || [trimmedLead hasPrefix:[NSString stringWithFormat:@"%@：", senderName]]) {
        return text;
    }
    return [NSString stringWithFormat:@"%@：%@", senderName, text];
}

- (NSString *)fallbackTextByType:(NSDictionary *)msg {
    id t = msg[@"type"];
    if (![t respondsToSelector:@selector(integerValue)]) t = msg[@"content_type"];
    NSInteger type = [t respondsToSelector:@selector(integerValue)] ? [t integerValue] : 0;
    // 与 WKConstant.h 保持: WK_IMAGE=2, WK_SMALLVIDEO=5, WK_FILE=6
    if (type == 2) return LLang(@"[图片]");
    if (type == 5) return LLang(@"[视频]");
    if (type == 6) return LLang(@"[文件]");
    return LLang(@"[聊天记录]");
}

- (NSString *)asString:(id)v {
    if ([v isKindOfClass:[NSString class]]) return (NSString *)v;
    return @"";
}

@end
