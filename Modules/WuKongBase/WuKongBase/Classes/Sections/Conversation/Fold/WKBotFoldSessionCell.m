//
//  WKBotFoldSessionCell.m
//  WuKongBase
//
//  AI 折叠会话卡 cell。视觉对齐：单卡片，包含：
//    - 标题行：bot 头像 + 名字 + AI 标签 + "展开/收起 N 条讨论"
//    - 紫色淡底摘要框：💡 + 最后一条消息内容（markdown 渲染，含表格）
//    - 展开时：底部"讨论记录"分隔 + 每条子消息（avatar + name + time + 内容）
//

#import "WKBotFoldSessionCell.h"
#import "WKAITagView.h"
#import "WuKongBase.h" // LLang
#import "WKMessageModel.h"
#import "WKAvatarUtil.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <SDWebImage/SDWebImage.h>
#import <WebKit/WebKit.h>
#import <WuKongBase/WuKongBase-Swift.h> // WKMarkdownRenderer

NSString * const kWKBotFoldSessionCellReuseId = @"WKBotFoldSessionCell";

static const CGFloat kCardVerticalInset    = 6;   // cell 上下边距
static const CGFloat kCardHorizontalInset  = 12;  // unused (历史保留)
static const CGFloat kCardCornerRadius     = 14;
static const CGFloat kCardInnerPadding     = 14;  // 卡内 padding
static const CGFloat kHeaderAvatarSize     = 28;
static const CGFloat kHeaderAvatarOverlap  = 8;   // 多 bot 头像重叠量
static const NSInteger kHeaderMaxAvatars   = 3;   // 标题行最多平铺几个头像，超出走 "+N" 圆
static const CGFloat kEntryAvatarSize      = 22;  // 讨论记录条目头像
static const CGFloat kStackSpacing         = 12;
static const CGFloat kCardExtraWidth       = 20;  // 折叠卡比普通气泡 messageContentMaxWidth 再宽这么多
static const CGFloat kSummarySegmentSpacing = 6; // summary 内段间距（text/table 交替时）
static const CGFloat kSummaryTablePaddingV  = 6; // summary 内表格容器上下内边距
static const CGFloat kSummaryTableRowExtra  = 2; // 每行表格额外补的间隙（CSS line-height 误差兜底）

// forward 声明：discussion 条目视图需要调用 cell 的类方法提取文本，但 cell 的
// @implementation 在它之后；声明一个 internal 接口让编译器知道这个 selector 存在。
@interface WKBotFoldSessionCell (Internal)
+ (NSString *)extractPreviewSourceFromMessage:(WKMessageModel *)m;
@end

#pragma mark - 私有 helper：单条讨论条目视图

@interface WKBotFoldDiscussionEntryView : UIView
@property(nonatomic, strong) UIImageView *avatarView;
@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, strong) UILabel *timeLabel;
/// 内容承载：可能是单段 text label，也可能是 text/table 混合 segments。统一用
/// stackView 装载，table 段走 WKWebView，与 summary 内 segment 处理一致。
@property(nonatomic, strong) UIStackView *contentStack;
@property(nonatomic, strong) NSMutableArray<UILabel *> *contentTextLabels;
@property(nonatomic, strong) NSMutableArray<WKWebView *> *contentTableWebViews;
/// 兼容旧字段：仍暴露给 cell.applyColors 用，等价于 contentTextLabels.firstObject 或为 nil。
/// 老代码 `v.contentLabel.textColor = ...` 现在会刷不到所有 segment label，cell 已改成
/// 直接遍历 contentTextLabels；保留属性以免破坏外部 ABI。
@property(nonatomic, readonly, nullable) UILabel *contentLabel;
- (void)configureWithMessage:(WKMessageModel *)m;
+ (CGFloat)heightForMessage:(WKMessageModel *)m contentWidth:(CGFloat)contentWidth;
@end

@implementation WKBotFoldDiscussionEntryView {
    UILabel *_legacyContentLabelStub; // 不实际显示，仅给老的 contentLabel getter 兜底
}

- (UILabel *)contentLabel {
    return self.contentTextLabels.firstObject ?: _legacyContentLabelStub;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        self.avatarView = [UIImageView new];
        self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        self.avatarView.layer.cornerRadius = kEntryAvatarSize / 2;
        self.avatarView.layer.masksToBounds = YES;
        self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.avatarView.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1];
        [self addSubview:self.avatarView];

        self.nameLabel = [UILabel new];
        self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.nameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [self addSubview:self.nameLabel];

        self.timeLabel = [UILabel new];
        self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.timeLabel.font = [UIFont systemFontOfSize:11];
        self.timeLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1];
        [self addSubview:self.timeLabel];

        self.contentTextLabels = [NSMutableArray array];
        self.contentTableWebViews = [NSMutableArray array];
        self.contentStack = [[UIStackView alloc] init];
        self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
        self.contentStack.axis = UILayoutConstraintAxisVertical;
        self.contentStack.alignment = UIStackViewAlignmentFill;
        self.contentStack.spacing = kSummarySegmentSpacing;
        [self addSubview:self.contentStack];

        [NSLayoutConstraint activateConstraints:@[
            [self.avatarView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.avatarView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.avatarView.widthAnchor constraintEqualToConstant:kEntryAvatarSize],
            [self.avatarView.heightAnchor constraintEqualToConstant:kEntryAvatarSize],

            [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:8],
            [self.nameLabel.centerYAnchor constraintEqualToAnchor:self.avatarView.centerYAnchor],
            [self.timeLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor constant:8],
            [self.timeLabel.centerYAnchor constraintEqualToAnchor:self.avatarView.centerYAnchor],
            [self.timeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],

            [self.contentStack.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
            [self.contentStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.contentStack.topAnchor constraintEqualToAnchor:self.avatarView.bottomAnchor constant:4],
            [self.contentStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)resetContentSegments {
    for (UIView *v in self.contentStack.arrangedSubviews) {
        [self.contentStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    for (WKWebView *wv in self.contentTableWebViews) {
        wv.navigationDelegate = nil;
        [wv stopLoading];
    }
    [self.contentTextLabels removeAllObjects];
    [self.contentTableWebViews removeAllObjects];
}

- (void)appendEntryTextSegment:(NSString *)text {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    if ([WKMarkdownRenderer containsMarkdown:text]) {
        NSAttributedString *attr = [WKMarkdownRenderer render:text
                                                     fontSize:[WKApp shared].config.messageTextFontSize
                                                 textColorHex:@"#222222"
                                             dynamicTextColor:nil];
        if (attr) label.attributedText = attr; else label.text = text;
    } else {
        label.text = text;
    }
    [self.contentStack addArrangedSubview:label];
    [self.contentTextLabels addObject:label];
}

- (void)appendEntryTableSegment:(NSString *)tableMarkdown {
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = 8;
    container.clipsToBounds = YES;
    BOOL dark = [WKApp shared].config.style == WKSystemStyleDark;
    container.backgroundColor = dark ? [UIColor colorWithWhite:0.18 alpha:1]
                                     : [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF6/255.0 alpha:1.0];

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];
    wv.translatesAutoresizingMaskIntoConstraints = NO;
    wv.backgroundColor = [UIColor clearColor];
    wv.opaque = NO;
    wv.scrollView.bounces = NO;
    wv.scrollView.showsHorizontalScrollIndicator = NO;
    wv.scrollView.showsVerticalScrollIndicator = NO;

    NSString *textColorHex = dark ? @"#E5E5E5" : @"#222222";
    NSString *html = [WKMarkdownRenderer extractTableHTML:tableMarkdown
                                                  fontSize:[WKApp shared].config.messageTextFontSize
                                              textColorHex:textColorHex];
    if (html) [wv loadHTMLString:html baseURL:nil];

    [container addSubview:wv];

    NSInteger rowCount = MAX(1, [WKMarkdownRenderer tableRowCount:tableMarkdown]);
    CGFloat rowH = ceil([WKApp shared].config.messageTextFontSize * 1.2 + 22.0) + kSummaryTableRowExtra;
    CGFloat webviewH = rowH * rowCount;
    CGFloat containerH = webviewH + kSummaryTablePaddingV * 2;

    [NSLayoutConstraint activateConstraints:@[
        [wv.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [wv.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [wv.topAnchor constraintEqualToAnchor:container.topAnchor constant:kSummaryTablePaddingV],
        [wv.heightAnchor constraintEqualToConstant:webviewH],
        [container.heightAnchor constraintEqualToConstant:containerH],
    ]];

    [self.contentStack addArrangedSubview:container];
    [self.contentTableWebViews addObject:wv];
}

- (void)configureWithMessage:(WKMessageModel *)m {
    self.nameLabel.text = m.from.displayName ?: (m.from.name ?: @"");
    self.timeLabel.text = m.timeStr ?: @"";
    // 头像
    if (m.from.logo.length > 0) {
        NSString *url = [WKAvatarUtil getFullAvatarWIthPath:m.from.logo];
        if (m.from.avatarCacheKey.length > 0 && url) {
            NSString *sep = [url containsString:@"?"] ? @"&" : @"?";
            url = [NSString stringWithFormat:@"%@%@v=%@", url, sep, m.from.avatarCacheKey];
        }
        [self.avatarView sd_setImageWithURL:[NSURL URLWithString:url] placeholderImage:nil];
    } else {
        self.avatarView.image = nil;
    }
    // 内容：按 segment 拆 text/table，table 段走 webview，跟 summary 一致
    [self resetContentSegments];
    NSString *raw = [WKBotFoldSessionCell extractPreviewSourceFromMessage:m];
    if (raw.length == 0) {
        [self appendEntryTextSegment:@""];
        return;
    }
    NSArray *segments = [WKMarkdownRenderer splitContentSegments:raw];
    if (segments.count == 0) {
        [self appendEntryTextSegment:raw];
    } else {
        for (NSDictionary *seg in segments) {
            NSString *type = seg[@"type"];
            NSString *content = seg[@"content"] ?: @"";
            if ([type isEqualToString:@"table"]) {
                [self appendEntryTableSegment:content];
            } else {
                [self appendEntryTextSegment:content];
            }
        }
    }
}

+ (CGFloat)heightForMessage:(WKMessageModel *)m contentWidth:(CGFloat)contentWidth {
    // header(avatar 22) + 4 + content（按 segment 累加，跟 summary 一致）
    CGFloat headerH = kEntryAvatarSize;
    NSString *raw = [WKBotFoldSessionCell extractPreviewSourceFromMessage:m];
    if (raw.length == 0) return headerH;

    CGFloat fs = [WKApp shared].config.messageTextFontSize;
    UIFont *font = [UIFont systemFontOfSize:fs];
    CGFloat contentTextW = MAX(0, contentWidth - kEntryAvatarSize - 8);

    NSArray *segments = [WKMarkdownRenderer splitContentSegments:raw];
    CGFloat contentH = 0;
    NSInteger renderedCount = 0;
    if (segments.count == 0) {
        CGRect r = [raw boundingRectWithSize:CGSizeMake(contentTextW, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:@{ NSFontAttributeName: font } context:nil];
        contentH = ceil(r.size.height);
        renderedCount = 1;
    } else {
        for (NSDictionary *seg in segments) {
            NSString *type = seg[@"type"];
            NSString *content = seg[@"content"] ?: @"";
            if (content.length == 0) continue;
            CGFloat segH = 0;
            if ([type isEqualToString:@"table"]) {
                NSInteger rowCount = MAX(1, [WKMarkdownRenderer tableRowCount:content]);
                CGFloat rowH = ceil(fs * 1.2 + 22.0) + kSummaryTableRowExtra;
                segH = rowH * rowCount + kSummaryTablePaddingV * 2;
            } else {
                NSAttributedString *attr = [WKMarkdownRenderer containsMarkdown:content]
                    ? [WKMarkdownRenderer render:content fontSize:fs textColorHex:@"#222222" dynamicTextColor:nil]
                    : nil;
                CGRect rect;
                if (attr) {
                    rect = [attr boundingRectWithSize:CGSizeMake(contentTextW, CGFLOAT_MAX)
                                              options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                              context:nil];
                } else {
                    rect = [content boundingRectWithSize:CGSizeMake(contentTextW, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                              attributes:@{ NSFontAttributeName: font } context:nil];
                }
                segH = ceil(rect.size.height);
            }
            contentH += segH;
            renderedCount += 1;
        }
        if (renderedCount > 1) contentH += kSummarySegmentSpacing * (renderedCount - 1);
    }
    return headerH + 4 + contentH;
}

@end

#pragma mark - WKBotFoldSessionCell

@interface WKBotFoldSessionCell ()
@property(nonatomic, strong) WKBotFoldSession *session;
@property(nonatomic, assign) BOOL expanded;

@property(nonatomic, strong) UIView *card;
@property(nonatomic, strong) UIStackView *cardStack;

// 标题行
@property(nonatomic, strong) UIView *titleRow;
@property(nonatomic, strong) UIView *headerAvatarStack;          // 头像容器（替代单 avatar + 名字）
@property(nonatomic, strong) NSMutableArray<UIImageView *> *headerAvatarViews;
@property(nonatomic, strong) UILabel *headerAvatarOverflowLabel;  // 超过 max 时的 "+N" 圆
@property(nonatomic, strong) WKAITagView *aiTagView;
@property(nonatomic, strong) UILabel *toggleLabel; // "展开 N 条讨论" / "收起 N 条讨论"

// 摘要框（紫色淡底）
@property(nonatomic, strong) UIView *summaryBox;
@property(nonatomic, strong) UILabel *summaryEmojiLabel;
@property(nonatomic, strong) UIStackView *summarySegmentStack; // text / table 段垂直排列
@property(nonatomic, strong) NSMutableArray<UILabel *> *summaryTextLabels; // 文本段 label，applyColors 刷颜色用
@property(nonatomic, strong) NSMutableArray<WKWebView *> *summaryTableWebViews; // 表格段 webview，reuse 清理用

// 讨论区（展开时）
@property(nonatomic, strong) UIView *discussionSection;
@property(nonatomic, strong) UIView *discussionDivider;
@property(nonatomic, strong) UILabel *discussionHeader;
@property(nonatomic, strong) UIStackView *discussionEntriesStack;
@property(nonatomic, strong) NSMutableArray<WKBotFoldDiscussionEntryView *> *entryViews;
@end

@implementation WKBotFoldSessionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.entryViews = [NSMutableArray array];
        self.headerAvatarViews = [NSMutableArray array];
        self.summaryTextLabels = [NSMutableArray array];
        self.summaryTableWebViews = [NSMutableArray array];
        [self buildHierarchy];
        [self applyColors];
    }
    return self;
}

#pragma mark 构建层级

- (void)buildHierarchy {
    // card
    self.card = [[UIView alloc] init];
    self.card.translatesAutoresizingMaskIntoConstraints = NO;
    self.card.layer.cornerRadius = kCardCornerRadius;
    self.card.layer.masksToBounds = YES;
    [self.contentView addSubview:self.card];

    // cardStack
    self.cardStack = [[UIStackView alloc] init];
    self.cardStack.axis = UILayoutConstraintAxisVertical;
    self.cardStack.alignment = UIStackViewAlignmentFill;
    self.cardStack.spacing = kStackSpacing;
    self.cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.card addSubview:self.cardStack];

    // ─── titleRow ─────────────────────────────────────
    self.titleRow = [UIView new];
    self.titleRow.translatesAutoresizingMaskIntoConstraints = NO;

    // 头像堆叠容器：单 bot = 1 个，多 bot 重叠铺开。不再放名字（节省右侧空间给 toggle）。
    self.headerAvatarStack = [UIView new];
    self.headerAvatarStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.titleRow addSubview:self.headerAvatarStack];

    self.headerAvatarOverflowLabel = [UILabel new];
    self.headerAvatarOverflowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerAvatarOverflowLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.headerAvatarOverflowLabel.textAlignment = NSTextAlignmentCenter;
    self.headerAvatarOverflowLabel.layer.cornerRadius = kHeaderAvatarSize / 2;
    self.headerAvatarOverflowLabel.layer.masksToBounds = YES;
    self.headerAvatarOverflowLabel.hidden = YES;
    [self.headerAvatarStack addSubview:self.headerAvatarOverflowLabel];

    self.aiTagView = [[WKAITagView alloc] init];
    [self.titleRow addSubview:self.aiTagView];

    self.toggleLabel = [UILabel new];
    self.toggleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.toggleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.toggleLabel.textAlignment = NSTextAlignmentRight;
    [self.titleRow addSubview:self.toggleLabel];

    // ─── summaryBox (紫色淡底摘要) ────────────────────
    self.summaryBox = [UIView new];
    self.summaryBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.summaryBox.layer.cornerRadius = 10;
    self.summaryBox.layer.masksToBounds = YES;

    self.summaryEmojiLabel = [UILabel new];
    self.summaryEmojiLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.summaryEmojiLabel.text = @"💡";
    self.summaryEmojiLabel.font = [UIFont systemFontOfSize:16];
    [self.summaryBox addSubview:self.summaryEmojiLabel];

    // segmentStack：text 段（UILabel）和 table 段（WKWebView 容器）混排。
    // 用 UIStackView 自动布局，避免 manual frame；WebView 高度通过 constraint 锁定。
    self.summarySegmentStack = [[UIStackView alloc] init];
    self.summarySegmentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.summarySegmentStack.axis = UILayoutConstraintAxisVertical;
    self.summarySegmentStack.alignment = UIStackViewAlignmentFill;
    self.summarySegmentStack.spacing = kSummarySegmentSpacing;
    [self.summaryBox addSubview:self.summarySegmentStack];

    // ─── discussionSection ────────────────────────────
    self.discussionSection = [UIView new];
    self.discussionSection.translatesAutoresizingMaskIntoConstraints = NO;

    self.discussionDivider = [UIView new];
    self.discussionDivider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.discussionSection addSubview:self.discussionDivider];

    self.discussionHeader = [UILabel new];
    self.discussionHeader.translatesAutoresizingMaskIntoConstraints = NO;
    self.discussionHeader.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.discussionHeader.textAlignment = NSTextAlignmentCenter;
    self.discussionHeader.text = LLang(@"讨论记录");
    [self.discussionSection addSubview:self.discussionHeader];

    self.discussionEntriesStack = [[UIStackView alloc] init];
    self.discussionEntriesStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.discussionEntriesStack.axis = UILayoutConstraintAxisVertical;
    self.discussionEntriesStack.alignment = UIStackViewAlignmentFill;
    self.discussionEntriesStack.spacing = 14;
    [self.discussionSection addSubview:self.discussionEntriesStack];

    // 加入 cardStack
    [self.cardStack addArrangedSubview:self.titleRow];
    [self.cardStack addArrangedSubview:self.summaryBox];
    [self.cardStack addArrangedSubview:self.discussionSection];

    [self pinConstraints];

    // 点击 toggle：只在标题行响应（用户期望只有标题栏触发展开/收起，
    // 摘要区 / 讨论记录区域不触发，避免误操作 + 杜绝双触发）。
    UITapGestureRecognizer *titleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTitleRowTap)];
    self.titleRow.userInteractionEnabled = YES;
    [self.titleRow addGestureRecognizer:titleTap];
}

- (void)handleTitleRowTap {
    if (self.onToggleExpand && self.session) {
        self.onToggleExpand(self.session);
    }
}

- (void)pinConstraints {
    UIView *content = self.contentView;
    // card 宽度：leading 对齐普通 bot 气泡 leading；width = messageContentMaxWidth + 额外补宽，
    // 让 fold 卡视觉略宽于普通气泡（内含 summary / 讨论记录，更需空间）
    CGFloat leftGutter = 10 + [WKApp shared].config.messageAvatarSize.width + 10;
    CGFloat maxW = [WKApp shared].config.messageContentMaxWidth + kCardExtraWidth;
    [NSLayoutConstraint activateConstraints:@[
        [self.card.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:leftGutter],
        [self.card.widthAnchor constraintEqualToConstant:maxW],
        [self.card.topAnchor constraintEqualToAnchor:content.topAnchor constant:kCardVerticalInset],
        [self.card.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-kCardVerticalInset],

        [self.cardStack.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:kCardInnerPadding],
        [self.cardStack.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-kCardInnerPadding],
        [self.cardStack.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:kCardInnerPadding],
        [self.cardStack.bottomAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:-kCardInnerPadding],

        // titleRow 内部：avatar stack 在左，AI tag 紧跟，toggle 右对齐
        [self.titleRow.heightAnchor constraintEqualToConstant:kHeaderAvatarSize],
        [self.headerAvatarStack.leadingAnchor constraintEqualToAnchor:self.titleRow.leadingAnchor],
        [self.headerAvatarStack.centerYAnchor constraintEqualToAnchor:self.titleRow.centerYAnchor],
        [self.headerAvatarStack.heightAnchor constraintEqualToConstant:kHeaderAvatarSize],
        // headerAvatarStack 的宽度由 rebuildHeaderAvatarStack: 动态设置

        [self.aiTagView.leadingAnchor constraintEqualToAnchor:self.headerAvatarStack.trailingAnchor constant:8],
        [self.aiTagView.centerYAnchor constraintEqualToAnchor:self.titleRow.centerYAnchor],

        [self.toggleLabel.trailingAnchor constraintEqualToAnchor:self.titleRow.trailingAnchor],
        [self.toggleLabel.centerYAnchor constraintEqualToAnchor:self.titleRow.centerYAnchor],
        [self.toggleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.aiTagView.trailingAnchor constant:8],

        // summaryBox 内部：emoji 顶部固定 + segmentStack 在右侧自适应高度
        [self.summaryEmojiLabel.leadingAnchor constraintEqualToAnchor:self.summaryBox.leadingAnchor constant:12],
        [self.summaryEmojiLabel.topAnchor constraintEqualToAnchor:self.summaryBox.topAnchor constant:10],
        [self.summaryEmojiLabel.widthAnchor constraintEqualToConstant:20],
        [self.summarySegmentStack.leadingAnchor constraintEqualToAnchor:self.summaryEmojiLabel.trailingAnchor constant:6],
        [self.summarySegmentStack.trailingAnchor constraintEqualToAnchor:self.summaryBox.trailingAnchor constant:-12],
        [self.summarySegmentStack.topAnchor constraintEqualToAnchor:self.summaryBox.topAnchor constant:10],
        [self.summarySegmentStack.bottomAnchor constraintEqualToAnchor:self.summaryBox.bottomAnchor constant:-10],

        // discussionSection 内部
        [self.discussionDivider.leadingAnchor constraintEqualToAnchor:self.discussionSection.leadingAnchor],
        [self.discussionDivider.trailingAnchor constraintEqualToAnchor:self.discussionSection.trailingAnchor],
        [self.discussionDivider.topAnchor constraintEqualToAnchor:self.discussionSection.topAnchor constant:4],
        [self.discussionDivider.heightAnchor constraintEqualToConstant:0.5],
        [self.discussionHeader.centerXAnchor constraintEqualToAnchor:self.discussionSection.centerXAnchor],
        [self.discussionHeader.topAnchor constraintEqualToAnchor:self.discussionDivider.topAnchor constant:-9], // 浮在 divider 上
        [self.discussionHeader.widthAnchor constraintLessThanOrEqualToConstant:120],
        [self.discussionEntriesStack.leadingAnchor constraintEqualToAnchor:self.discussionSection.leadingAnchor],
        [self.discussionEntriesStack.trailingAnchor constraintEqualToAnchor:self.discussionSection.trailingAnchor],
        [self.discussionEntriesStack.topAnchor constraintEqualToAnchor:self.discussionDivider.bottomAnchor constant:14],
        [self.discussionEntriesStack.bottomAnchor constraintEqualToAnchor:self.discussionSection.bottomAnchor],
    ]];
}

#pragma mark 配置

- (void)configureWithSession:(WKBotFoldSession *)session expanded:(BOOL)expanded {
    self.session = session;
    self.expanded = expanded;

    // 标题行：头像堆叠（不显示名字了，节省右侧空间给 toggle）
    [self rebuildHeaderAvatarStackWithParticipants:session.participants];
    [self.aiTagView applyStyle:(session.participants.count > 1 ? WKAITagStyleCollaboration : WKAITagStyleAssistant)];

    NSInteger count = session.messages.count;
    if (expanded) {
        self.toggleLabel.text = [NSString stringWithFormat:LLang(@"收起 %ld 条讨论"), (long)count];
    } else {
        self.toggleLabel.text = [NSString stringWithFormat:LLang(@"展开 %ld 条讨论"), (long)count];
    }

    // 摘要框
    WKMessageModel *last = session.messages.lastObject;
    [self renderSummaryForMessage:last];

    // 讨论区：展开才显示
    if (expanded) {
        self.discussionSection.hidden = NO;
        [self rebuildDiscussionEntriesForSession:session];
    } else {
        self.discussionSection.hidden = YES;
    }

    [self applyColors];
}

#pragma mark 标题行头像堆叠

- (void)rebuildHeaderAvatarStackWithParticipants:(NSArray<WKChannelInfo *> *)participants {
    // 清掉旧头像
    for (UIImageView *v in self.headerAvatarViews) [v removeFromSuperview];
    [self.headerAvatarViews removeAllObjects];

    NSInteger shown = MIN((NSInteger)participants.count, kHeaderMaxAvatars);
    BOOL hasOverflow = participants.count > kHeaderMaxAvatars;
    CGFloat singleW = kHeaderAvatarSize;
    CGFloat stepW = kHeaderAvatarSize - kHeaderAvatarOverlap;
    CGFloat width = singleW + MAX(0, shown - 1) * stepW + (hasOverflow ? stepW : 0);
    if (shown <= 0) width = 0;

    // 移除旧宽度约束
    for (NSLayoutConstraint *c in self.headerAvatarStack.constraints.copy) {
        if (c.firstAttribute == NSLayoutAttributeWidth) [self.headerAvatarStack removeConstraint:c];
    }
    [self.headerAvatarStack.widthAnchor constraintEqualToConstant:width].active = YES;

    for (NSInteger i = 0; i < shown; i++) {
        UIImageView *iv = [UIImageView new];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.layer.cornerRadius = kHeaderAvatarSize / 2;
        iv.layer.masksToBounds = YES;
        iv.layer.borderWidth = 1.5;
        iv.layer.borderColor = self.card.backgroundColor.CGColor;
        iv.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        [self.headerAvatarStack addSubview:iv];
        [self.headerAvatarViews addObject:iv];

        [NSLayoutConstraint activateConstraints:@[
            [iv.widthAnchor constraintEqualToConstant:kHeaderAvatarSize],
            [iv.heightAnchor constraintEqualToConstant:kHeaderAvatarSize],
            [iv.topAnchor constraintEqualToAnchor:self.headerAvatarStack.topAnchor],
            [iv.leadingAnchor constraintEqualToAnchor:self.headerAvatarStack.leadingAnchor constant:i * stepW],
        ]];
        [self loadAvatarInto:iv fromChannelInfo:participants[i]];
    }

    if (hasOverflow) {
        self.headerAvatarOverflowLabel.hidden = NO;
        self.headerAvatarOverflowLabel.text = [NSString stringWithFormat:@"+%ld", (long)(participants.count - kHeaderMaxAvatars)];
        [NSLayoutConstraint activateConstraints:@[
            [self.headerAvatarOverflowLabel.widthAnchor constraintEqualToConstant:kHeaderAvatarSize],
            [self.headerAvatarOverflowLabel.heightAnchor constraintEqualToConstant:kHeaderAvatarSize],
            [self.headerAvatarOverflowLabel.topAnchor constraintEqualToAnchor:self.headerAvatarStack.topAnchor],
            [self.headerAvatarOverflowLabel.leadingAnchor constraintEqualToAnchor:self.headerAvatarStack.leadingAnchor
                                                                          constant:shown * stepW],
        ]];
    } else {
        self.headerAvatarOverflowLabel.hidden = YES;
    }
}

- (void)renderSummaryForMessage:(WKMessageModel *)last {
    // 清掉旧 segment 视图 + webview 引用（reuse 防泄漏）
    for (UIView *v in self.summarySegmentStack.arrangedSubviews) {
        [self.summarySegmentStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    for (WKWebView *wv in self.summaryTableWebViews) {
        wv.navigationDelegate = nil;
        [wv stopLoading];
    }
    [self.summaryTextLabels removeAllObjects];
    [self.summaryTableWebViews removeAllObjects];

    NSString *raw = [[self class] extractPreviewSourceFromMessage:last];
    if (raw.length == 0) {
        // 占位空 label 维持 box 最小高度
        [self appendTextSegment:@""];
        [self applyColors];
        return;
    }

    // 按 splitContentSegments 把 raw 拆成 text/table 段交替；text 段走 markdown 富文本
    // UILabel，table 段走 WKWebView（无 toolbar，仅展示）。高度由 stackView 自动算（webview
    // 通过固定 height constraint 锁定，避免异步加载导致 self-sizing 漂移）。
    NSArray *segments = [WKMarkdownRenderer splitContentSegments:raw];
    if (segments.count == 0) {
        [self appendTextSegment:raw];
    } else {
        for (NSDictionary *seg in segments) {
            NSString *type = seg[@"type"];
            NSString *content = seg[@"content"] ?: @"";
            if ([type isEqualToString:@"table"]) {
                [self appendTableSegment:content];
            } else {
                [self appendTextSegment:content];
            }
        }
    }
    [self applyColors];
}

- (void)appendTextSegment:(NSString *)text {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:[WKApp shared].config.messageTextFontSize];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    if ([WKMarkdownRenderer containsMarkdown:text]) {
        NSAttributedString *attr = [WKMarkdownRenderer render:text
                                                     fontSize:[WKApp shared].config.messageTextFontSize
                                                 textColorHex:@"#222222"
                                             dynamicTextColor:nil];
        if (attr) label.attributedText = attr; else label.text = text;
    } else {
        label.text = text;
    }
    [self.summarySegmentStack addArrangedSubview:label];
    [self.summaryTextLabels addObject:label];
}

- (void)appendTableSegment:(NSString *)tableMarkdown {
    // 表格容器：白底圆角（深色模式下走 applyColors 切换），里面只放 webview，无 toolbar。
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = 8;
    container.clipsToBounds = YES;

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.suppressesIncrementalRendering = NO;
    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];
    wv.translatesAutoresizingMaskIntoConstraints = NO;
    wv.backgroundColor = [UIColor clearColor];
    wv.opaque = NO;
    wv.scrollView.bounces = NO;
    wv.scrollView.showsHorizontalScrollIndicator = NO;
    wv.scrollView.showsVerticalScrollIndicator = NO;

    BOOL dark = [WKApp shared].config.style == WKSystemStyleDark;
    NSString *textColorHex = dark ? @"#E5E5E5" : @"#222222";
    NSString *html = [WKMarkdownRenderer extractTableHTML:tableMarkdown
                                                  fontSize:[WKApp shared].config.messageTextFontSize
                                              textColorHex:textColorHex];
    if (html) [wv loadHTMLString:html baseURL:nil];

    [container addSubview:wv];

    NSInteger rowCount = MAX(1, [WKMarkdownRenderer tableRowCount:tableMarkdown]);
    CGFloat rowH = ceil([WKApp shared].config.messageTextFontSize * 1.2 + 22.0) + kSummaryTableRowExtra;
    CGFloat webviewH = rowH * rowCount;
    CGFloat containerH = webviewH + kSummaryTablePaddingV * 2;

    [NSLayoutConstraint activateConstraints:@[
        [wv.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [wv.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [wv.topAnchor constraintEqualToAnchor:container.topAnchor constant:kSummaryTablePaddingV],
        [wv.heightAnchor constraintEqualToConstant:webviewH],
        [container.heightAnchor constraintEqualToConstant:containerH],
    ]];

    [self.summarySegmentStack addArrangedSubview:container];
    [self.summaryTableWebViews addObject:wv];
}

- (void)rebuildDiscussionEntriesForSession:(WKBotFoldSession *)session {
    // 复用现有 entryView，多了创建，少了 hidden
    NSArray<WKMessageModel *> *msgs = session.messages;
    while (self.entryViews.count < msgs.count) {
        WKBotFoldDiscussionEntryView *v = [[WKBotFoldDiscussionEntryView alloc] initWithFrame:CGRectZero];
        [self.discussionEntriesStack addArrangedSubview:v];
        [self.entryViews addObject:v];
    }
    for (NSInteger i = 0; i < (NSInteger)self.entryViews.count; i++) {
        WKBotFoldDiscussionEntryView *v = self.entryViews[i];
        if (i < (NSInteger)msgs.count) {
            v.hidden = NO;
            [v configureWithMessage:msgs[i]];
        } else {
            v.hidden = YES;
        }
    }
}

#pragma mark 头像加载

- (void)loadAvatarInto:(UIImageView *)imageView fromChannelInfo:(WKChannelInfo *)info {
    if (!imageView) return;
    if (!info || info.logo.length == 0) {
        imageView.image = nil;
        return;
    }
    NSString *url = [WKAvatarUtil getFullAvatarWIthPath:info.logo];
    if (url.length == 0) {
        imageView.image = nil;
        return;
    }
    if (info.avatarCacheKey.length > 0) {
        NSString *sep = [url containsString:@"?"] ? @"&" : @"?";
        url = [NSString stringWithFormat:@"%@%@v=%@", url, sep, info.avatarCacheKey];
    }
    [imageView sd_setImageWithURL:[NSURL URLWithString:url] placeholderImage:nil];
}

#pragma mark 颜色

- (BOOL)isDark {
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

- (void)applyColors {
    BOOL dark = [self isDark];
    self.card.backgroundColor = dark ? [UIColor colorWithWhite:0.16 alpha:1] : [UIColor whiteColor];
    self.card.layer.borderColor = dark ? [UIColor colorWithWhite:0.30 alpha:1].CGColor
                                       : [UIColor colorWithWhite:0.90 alpha:1].CGColor;
    self.card.layer.borderWidth = 0.5;

    UIColor *primaryText = dark ? [UIColor whiteColor] : [UIColor blackColor];
    // toggleLabel 紫色：与 AI tag 同主题
    UIColor *accent = dark ? [UIColor colorWithRed:0.78 green:0.69 blue:1.00 alpha:1]
                           : [UIColor colorWithRed:0.42 green:0.30 blue:0.85 alpha:1];
    self.toggleLabel.textColor = accent;

    // 头像堆叠的描边色 = 卡背景色，让重叠位置有视觉分隔
    for (UIImageView *iv in self.headerAvatarViews) {
        iv.layer.borderColor = self.card.backgroundColor.CGColor;
    }
    self.headerAvatarOverflowLabel.backgroundColor = dark ? [UIColor colorWithWhite:0.30 alpha:1] : [UIColor colorWithWhite:0.88 alpha:1];
    self.headerAvatarOverflowLabel.textColor = dark ? [UIColor whiteColor] : [UIColor colorWithWhite:0.30 alpha:1];
    self.headerAvatarOverflowLabel.layer.borderColor = self.card.backgroundColor.CGColor;
    self.headerAvatarOverflowLabel.layer.borderWidth = 1.5;

    // 紫色淡底摘要框
    // 浅色：用户指定 UIColor(red:0.5,green:0.23,blue:0.96,alpha:0.07)；深色：同色相但提高
    // alpha 让深色卡背景下仍可见（卡底已经偏深，0.07 alpha 几乎不可视）。
    self.summaryBox.backgroundColor = dark
        ? [UIColor colorWithRed:0.65 green:0.45 blue:1.00 alpha:0.18]
        : [UIColor colorWithRed:0.50 green:0.23 blue:0.96 alpha:0.07];
    UIColor *summaryTextColor = dark ? [UIColor colorWithWhite:0.93 alpha:1]
                                     : [UIColor colorWithWhite:0.13 alpha:1];
    for (UILabel *label in self.summaryTextLabels) {
        label.textColor = summaryTextColor;
    }
    // 表格容器底色：浅色给 #F5F5F6 灰，深色给暗灰；webview 自身透明，HTML 颜色由
    // extractTableHTML 内部根据 isDark 切换 buildTableWebViewCSS 解决，cell 这边无须刷。
    UIColor *tableContainerBg = dark ? [UIColor colorWithWhite:0.18 alpha:1]
                                     : [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF6/255.0 alpha:1.0];
    for (WKWebView *wv in self.summaryTableWebViews) {
        wv.superview.backgroundColor = tableContainerBg;
    }

    // discussion 分隔
    self.discussionDivider.backgroundColor = dark ? [UIColor colorWithWhite:0.30 alpha:1]
                                                  : [UIColor colorWithWhite:0.88 alpha:1];
    self.discussionHeader.backgroundColor = self.card.backgroundColor;
    self.discussionHeader.textColor = dark ? [UIColor colorWithWhite:0.65 alpha:1]
                                           : [UIColor colorWithWhite:0.50 alpha:1];

    for (WKBotFoldDiscussionEntryView *v in self.entryViews) {
        v.nameLabel.textColor = primaryText;
        // entry 内可能有多个 text segment label（含 table 段时被表格容器分割成多个 label）；
        // 老代码 `v.contentLabel.textColor = ...` 只刷得到第一个，遗漏后面的段，深色模式下
        // 第二段开始全是白底黑字看不清。统一遍历全量段刷。
        for (UILabel *l in v.contentTextLabels) {
            l.textColor = summaryTextColor;
        }
        // table 容器底色（深色 / 浅色）跟着 cell 主题刷
        for (WKWebView *wv in v.contentTableWebViews) {
            wv.superview.backgroundColor = tableContainerBg;
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self applyColors];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onToggleExpand = nil; // 复用前清掉旧 block，避免老 cell 持着上一会话的 session
    // 同步释放 webview 进程：WKWebView 是 heavyweight，留在 stack 上等下次 configure
    // 才清会让闲置 cell 一直挂着 webContent process。这里立即拆，下一次 configure 才会
    // 按新内容重建。
    for (UIView *v in self.summarySegmentStack.arrangedSubviews) {
        [self.summarySegmentStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    for (WKWebView *wv in self.summaryTableWebViews) {
        wv.navigationDelegate = nil;
        [wv stopLoading];
    }
    [self.summaryTextLabels removeAllObjects];
    [self.summaryTableWebViews removeAllObjects];
}

#pragma mark - 工具：提取消息文本

+ (NSString *)extractPreviewSourceFromMessage:(WKMessageModel *)m {
    if (!m) return @"";
    WKMessageContent *c = m.content;
    if (!c) return @"";
    if (m.contentType == WK_TEXT && [c respondsToSelector:@selector(content)]) {
        id val = [(id)c content];
        if ([val isKindOfClass:[NSString class]] && [val length] > 0) {
            return val;
        }
    }
    NSString *d = [c conversationDigest];
    return d ?: @"";
}

#pragma mark - 高度估算

+ (CGFloat)heightForSession:(WKBotFoldSession *)session
              tableViewWidth:(CGFloat)tableWidth
                    expanded:(BOOL)expanded {
    if (!session) return 0.1;

    CGFloat cellVPad = kCardVerticalInset * 2;
    CGFloat cardWidth = [WKApp shared].config.messageContentMaxWidth + kCardExtraWidth;
    CGFloat innerContentW = MAX(0, cardWidth - kCardInnerPadding * 2);

    CGFloat titleH = kHeaderAvatarSize;
    CGFloat summaryH = [self summaryBoxHeightForSession:session contentWidth:innerContentW];

    CGFloat total = cellVPad + kCardInnerPadding * 2 + titleH + kStackSpacing + summaryH;
    if (expanded) {
        // discussion divider(0.5) + 14 + entries 高度 (相加 + 14 spacing)
        CGFloat dividerArea = 0.5 + 14;
        CGFloat entriesH = 0;
        NSArray<WKMessageModel *> *msgs = session.messages;
        CGFloat entrySpacing = 14;
        for (NSInteger i = 0; i < (NSInteger)msgs.count; i++) {
            entriesH += [WKBotFoldDiscussionEntryView heightForMessage:msgs[i] contentWidth:innerContentW];
            if (i < (NSInteger)msgs.count - 1) entriesH += entrySpacing;
        }
        total += kStackSpacing + dividerArea + entriesH;
    }
    return total;
}

+ (CGFloat)summaryBoxHeightForSession:(WKBotFoldSession *)session contentWidth:(CGFloat)contentWidth {
    WKMessageModel *last = session.messages.lastObject;
    NSString *raw = [self extractPreviewSourceFromMessage:last];
    if (raw.length == 0) return 40;

    CGFloat fs = [WKApp shared].config.messageTextFontSize;
    UIFont *font = [UIFont systemFontOfSize:fs];
    // segmentStack 在 emoji 右侧；可用宽度 = box 宽 - 左 padding(12) - emoji(20) - 间距(6) - 右 padding(12)
    CGFloat textW = MAX(0, contentWidth - 12 - 20 - 6 - 12);

    NSArray *segments = [WKMarkdownRenderer splitContentSegments:raw];
    if (segments.count == 0) {
        // 整段全是 plain text（无 table 也无 markdown 分段）
        CGRect r = [raw boundingRectWithSize:CGSizeMake(textW, CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:@{ NSFontAttributeName: font } context:nil];
        return 10 + ceil(r.size.height) + 10;
    }

    // 按 segment 累加：text → label boundingRect；table → rowCount * rowHeight + 容器 padding。
    // 段间用 kSummarySegmentSpacing 分隔；首尾各 10pt 内 padding。
    CGFloat total = 10 + 10;
    NSInteger renderedCount = 0;
    for (NSDictionary *seg in segments) {
        NSString *type = seg[@"type"];
        NSString *content = seg[@"content"] ?: @"";
        if (content.length == 0) continue;
        CGFloat segH = 0;
        if ([type isEqualToString:@"table"]) {
            NSInteger rowCount = MAX(1, [WKMarkdownRenderer tableRowCount:content]);
            CGFloat rowH = ceil(fs * 1.2 + 22.0) + kSummaryTableRowExtra;
            segH = rowH * rowCount + kSummaryTablePaddingV * 2;
        } else {
            NSAttributedString *attr = [WKMarkdownRenderer containsMarkdown:content]
                ? [WKMarkdownRenderer render:content fontSize:fs textColorHex:@"#222222" dynamicTextColor:nil]
                : nil;
            CGRect rect;
            if (attr) {
                rect = [attr boundingRectWithSize:CGSizeMake(textW, CGFLOAT_MAX)
                                          options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                          context:nil];
            } else {
                rect = [content boundingRectWithSize:CGSizeMake(textW, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                          attributes:@{ NSFontAttributeName: font } context:nil];
            }
            segH = ceil(rect.size.height);
        }
        total += segH;
        renderedCount += 1;
    }
    if (renderedCount > 1) total += kSummarySegmentSpacing * (renderedCount - 1);
    if (renderedCount == 0) return 40;
    return total;
}

@end
