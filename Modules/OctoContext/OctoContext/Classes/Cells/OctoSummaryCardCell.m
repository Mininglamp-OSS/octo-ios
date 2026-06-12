//
//  OctoSummaryCardCell.m
//  OctoContext
//

#import "OctoSummaryCardCell.h"
#import "OctoSummaryActionSheet.h"
#import "OctoSummaryDateFormat.h"
#import <WuKongBase/WuKongBase.h>

// 卡片几何常量集中。已完成 vs 未完成是两种视觉密度,主要差异在 body 行的存在
// 与否, 以及 body→footer 间距。所有数字都参与 +heightForItem:width: 与
// layoutSubviews 的对齐, 改其中一处必须同步另一处, 否则 cell 显高与实绘错位。
static const CGFloat kCardSidePadding   = 16;
static const CGFloat kCardInnerPadding  = 12;
static const CGFloat kCardTopPadding    = 12;
static const CGFloat kCardBottomPadding = 10;
static const CGFloat kRowGap            = 4;
static const CGFloat kBodyToFooterGap   = 4;
static const CGFloat kInitiatorH        = 18;
static const CGFloat kTitleH            = 22;
static const CGFloat kFooterH           = 20;
static const CGFloat kBetweenCards      = 8;
static const CGFloat kBodyLineSpacing   = 3;

@interface OctoSummaryCardCell ()
@property(nonatomic, strong) UIView *card;
@property(nonatomic, strong) UILabel *initiator;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *summaryText;
@property(nonatomic, strong) UILabel *footerTime;
@property(nonatomic, strong) UIButton *moreBtn;
@property(nonatomic, strong) UIView *statusBadge;
@property(nonatomic, strong) UILabel *statusBadgeLabel;
@property(nonatomic, strong) UIActivityIndicatorView *spinner;
@property(nonatomic, strong) OctoSummaryListItem *item;
@end

@implementation OctoSummaryCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _card = [UIView new];
        _card.layer.cornerRadius = 12;
        _card.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.85];
        [self.contentView addSubview:_card];

        _initiator = [UILabel new];
        _initiator.font = [UIFont systemFontOfSize:12];
        _initiator.textColor = [UIColor.labelColor colorWithAlphaComponent:0.4];
        [_card addSubview:_initiator];

        _statusBadge = [UIView new];
        _statusBadge.layer.cornerRadius = 10;
        _statusBadge.hidden = YES;
        [_card addSubview:_statusBadge];
        _statusBadgeLabel = [UILabel new];
        _statusBadgeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _statusBadgeLabel.textAlignment = NSTextAlignmentCenter;
        [_statusBadge addSubview:_statusBadgeLabel];

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _spinner.color = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
        _spinner.hidesWhenStopped = YES;
        [_card addSubview:_spinner];

        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _titleLabel.textColor = [UIColor labelColor];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_card addSubview:_titleLabel];

        _summaryText = [UILabel new];
        _summaryText.numberOfLines = 2;
        _summaryText.lineBreakMode = NSLineBreakByTruncatingTail;
        [_card addSubview:_summaryText];

        _footerTime = [UILabel new];
        _footerTime.font = [UIFont systemFontOfSize:12];
        _footerTime.textColor = [UIColor.labelColor colorWithAlphaComponent:0.4];
        [_card addSubview:_footerTime];

        _moreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
            [_moreBtn setImage:[UIImage systemImageNamed:@"ellipsis" withConfiguration:cfg] forState:UIControlStateNormal];
        }
        _moreBtn.tintColor = [UIColor.labelColor colorWithAlphaComponent:0.4];
        // 复用会话列表长按那套 WKFloatingMenu —— 风格 / 圆角 / 阴影与项目一致,
        // 比 iOS 原生 UIMenu 更贴气, 且 atPoint: 自带智能上下翻转。
        // 菜单内容在 onMore 时按 当前 item.status 即时计算, 这样 cell 状态一变,
        // 下一次点 ⋯ 立即拿到最新菜单(修 "刚点重新生成, ⋯ 还显示旧菜单" 的 bug)。
        [_moreBtn addTarget:self action:@selector(onMore:) forControlEvents:UIControlEventTouchUpInside];
        [_card addSubview:_moreBtn];
    }
    return self;
}

#pragma mark - Status badge

- (void)configureStatusBadgeForStatus:(OctoTaskStatus)status {
    NSString *text = nil;
    UIColor *bg = nil, *fg = nil;
    switch (status) {
        case OctoTaskStatusWaitingConfirm:
            text = LLang(@"等待中");
            fg   = [UIColor colorWithRed:0xFF/255.0 green:0x9F/255.0 blue:0x1A/255.0 alpha:1.0];
            bg   = [fg colorWithAlphaComponent:0.10];
            break;
        case OctoTaskStatusCancelled:
            text = LLang(@"已取消");
            fg   = [UIColor.labelColor colorWithAlphaComponent:0.5];
            bg   = [UIColor.labelColor colorWithAlphaComponent:0.06];
            break;
        case OctoTaskStatusFailed:
            text = LLang(@"失败");
            fg   = [UIColor systemRedColor];
            bg   = [fg colorWithAlphaComponent:0.10];
            break;
        default:
            self.statusBadge.hidden = YES;
            return;
    }
    self.statusBadge.hidden = NO;
    self.statusBadge.backgroundColor = bg;
    self.statusBadgeLabel.text = text;
    self.statusBadgeLabel.textColor = fg;
}

#pragma mark - Bind

- (NSString *)initiatorTextForItem:(OctoSummaryListItem *)item {
    NSString *prefix;
    NSString *name = item.creatorName;
    if (name.length == 0) {
        prefix = LLang(@"你发起");
    } else if (self.currentUserName.length > 0 && [name isEqualToString:self.currentUserName]) {
        prefix = LLang(@"你发起");
    } else {
        prefix = [NSString stringWithFormat:LLang(@"%@发起"), name];
    }
    NSString *suffix = [self sourceSuffixForItem:item];
    if (suffix.length == 0) return prefix;
    return [NSString stringWithFormat:@"%@ · %@", prefix, suffix];
}

/// 来源信息: 0 个空字串, 1 个 → "来自 XX", >1 个 → "来自 XX 等 N 个群聊/私聊/聊天"。
/// 类型词按 sources 主体类型决定: 全群/子区→ "群聊", 全私聊→ "私聊", 混合→ "聊天"。
- (NSString *)sourceSuffixForItem:(OctoSummaryListItem *)item {
    NSArray<OctoSourceItem *> *srcs = item.sources;
    if (srcs.count == 0) return @"";
    OctoSourceItem *first = srcs.firstObject;
    NSString *firstName = first.sourceName.length > 0 ? first.sourceName : first.sourceId;
    if (srcs.count == 1) {
        return [NSString stringWithFormat:LLang(@"来自 %@"), firstName];
    }
    BOOL allGroup = YES, allDM = YES;
    for (OctoSourceItem *s in srcs) {
        if (s.sourceType != OctoSourceDirectMessage) allDM = NO;
        if (s.sourceType == OctoSourceDirectMessage) allGroup = NO;
    }
    NSString *typeWord = allGroup ? LLang(@"群聊") : (allDM ? LLang(@"私聊") : LLang(@"聊天"));
    return [NSString stringWithFormat:LLang(@"来自 %@ 等 %lu 个 %@"),
            firstName, (unsigned long)srcs.count, typeWord];
}

- (void)bindItem:(OctoSummaryListItem *)item {
    self.item = item;
    BOOL isProcessing = (item.status == OctoTaskStatusProcessing || item.status == OctoTaskStatusPending);
    BOOL isCompleted  = (item.status == OctoTaskStatusCompleted);

    if (isProcessing) {
        self.card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.95]
                : [UIColor colorWithRed:0xFC/255.0 green:0xF3/255.0 blue:0xFF/255.0 alpha:0.95];
        }];
        self.card.layer.borderWidth = 2;
        self.card.layer.borderColor = [UIColor whiteColor].CGColor;
        [self.spinner startAnimating];
    } else {
        self.card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.9]
                : [UIColor.whiteColor colorWithAlphaComponent:0.85];
        }];
        self.card.layer.borderWidth = 0;
        [self.spinner stopAnimating];
    }

    self.initiator.text = [self initiatorTextForItem:item];
    self.titleLabel.text = item.title.length > 0 ? item.title : LLang(@"(无标题)");
    [self configureStatusBadgeForStatus:item.status];

    BOOL hasPreview = isCompleted && item.summaryPreview.length > 0;
    if (hasPreview) {
        self.summaryText.attributedText = [OctoSummaryCardCell attributedBodyText:item.summaryPreview
                                                                            color:[UIColor.labelColor colorWithAlphaComponent:0.8]];
        self.summaryText.numberOfLines = 2;     // 防御: 复用 cell 时其他状态可能被改过, 重置回 2
        self.summaryText.hidden = NO;
    } else if (isProcessing) {
        self.summaryText.attributedText = [OctoSummaryCardCell attributedBodyText:LLang(@"AI正在分析聊天记录...")
                                                                            color:[UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0]];
        self.summaryText.numberOfLines = 1;
        self.summaryText.hidden = NO;
    } else {
        self.summaryText.attributedText = nil;
        self.summaryText.hidden = YES;
    }

    if (isProcessing) {
        self.footerTime.text = nil;
        self.footerTime.hidden = YES;
    } else {
        NSString *t = isCompleted ? (item.completedAt ?: item.createdAt) : item.createdAt;
        self.footerTime.text = [OctoSummaryDateFormat relativeFromISO:t];
        self.footerTime.hidden = NO;
    }

    [self setNeedsLayout];
}

+ (NSAttributedString *)attributedBodyText:(NSString *)text color:(UIColor *)color {
    NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
    para.lineSpacing = kBodyLineSpacing;
    para.lineBreakMode = NSLineBreakByTruncatingTail;
    return [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:12],
        NSParagraphStyleAttributeName: para,
        NSForegroundColorAttributeName: color,
    }];
}

#pragma mark - Per-status menu (WKFloatingMenu, 与会话列表长按菜单同款)

/// ⋯ 按钮点击 → 弹 WKFloatingMenu, 锚点取按钮中心(window 坐标)。
/// 菜单内容在 onMore 时按 *当前* item.status 即时计算, cell status 变更后下一次
/// 点 ⋯ 立刻拿到最新菜单(修 "刚点重新生成, 立即再点 ⋯ 还显示旧菜单" 的 bug)。
- (void)onMore:(UIButton *)btn {
    if (!self.item) return;
    NSArray<NSDictionary *> *items = [self menuItemsForItem:self.item];
    CGPoint anchor = [btn.superview convertPoint:btn.center toView:nil];
    [WKFloatingMenu showItems:items atPoint:anchor];
}

/// 状态 → 菜单动作映射 (对齐设计稿"操作内容枚举"):
///   生成中 / 等待 / 等待参与 → 取消任务 + 删除
///   已完成 → 重新生成 + 删除
///   已取消 → 重新生成 + 编辑 + 删除
///   失败 → 重试 + 编辑 + 删除
- (NSArray<NSDictionary *> *)menuItemsForItem:(OctoSummaryListItem *)item {
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    __weak typeof(self) ws = self;
    void (^add)(NSString *, OctoSummaryActionType, BOOL) =
    ^(NSString *title, OctoSummaryActionType type, BOOL destructive) {
        NSDictionary *d = @{
            @"title": title,
            @"isDestructive": @(destructive),
            @"action": ^{ if (ws.onAction && ws.item) ws.onAction(type, ws.item); },
        };
        [items addObject:d];
    };
    switch (item.status) {
        case OctoTaskStatusProcessing:
        case OctoTaskStatusPending:
        case OctoTaskStatusWaitingConfirm:
            add(LLang(@"取消任务"), OctoSummaryActionCancel, NO);
            break;
        case OctoTaskStatusCompleted:
            add(LLang(@"重新生成"), OctoSummaryActionRegenerate, NO);
            break;
        case OctoTaskStatusCancelled:
            add(LLang(@"重新生成"), OctoSummaryActionRegenerate, NO);
            add(LLang(@"编辑"),    OctoSummaryActionEditTopic,  NO);
            break;
        case OctoTaskStatusFailed:
            add(LLang(@"重试"),    OctoSummaryActionRetry,      NO);
            add(LLang(@"编辑"),    OctoSummaryActionEditTopic,  NO);
            break;
        default: break;
    }
    add(LLang(@"删除"), OctoSummaryActionDelete, YES);
    return items;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat cardW = self.contentView.bounds.size.width - kCardSidePadding * 2;
    CGFloat cardH = self.contentView.bounds.size.height - kBetweenCards;
    self.card.frame = CGRectMake(kCardSidePadding, 0, cardW, cardH);

    CGFloat innerW = cardW - kCardInnerPadding * 2;
    CGFloat y = kCardTopPadding;

    [self.initiator sizeToFit];
    // 不再硬卡 innerW * 0.6 —— 上限太紧, "你发起·来自xxx等N个群聊" 这种长文会提前 …,
    // 而右侧大片空白没用上。按右侧实际控件 (badge / spinner) 占用宽度反算可用宽度。
    CGFloat reservedRight = 0;
    if (!self.statusBadge.hidden) {
        [self.statusBadgeLabel sizeToFit];
        reservedRight = self.statusBadgeLabel.frame.size.width + 16 + 8;   // badge padding + 与 initiator 间距
    } else if (self.spinner.isAnimating) {
        reservedRight = 18 + 8;
    }
    CGFloat initiatorAvail = MAX(60, innerW - reservedRight);
    CGFloat initiatorW = MIN(self.initiator.frame.size.width, initiatorAvail);
    self.initiator.frame = CGRectMake(kCardInnerPadding, y, initiatorW, kInitiatorH);

    if (!self.statusBadge.hidden) {
        [self.statusBadgeLabel sizeToFit];
        CGFloat bw = self.statusBadgeLabel.frame.size.width + 16;
        CGFloat bh = 20;
        self.statusBadge.frame = CGRectMake(cardW - kCardInnerPadding - bw, y - 1, bw, bh);
        self.statusBadgeLabel.frame = self.statusBadge.bounds;
    }
    self.spinner.frame = CGRectMake(cardW - kCardInnerPadding - 18, y - 1, 18, 18);

    y += kInitiatorH + kRowGap;
    self.titleLabel.frame = CGRectMake(kCardInnerPadding, y, innerW, kTitleH);
    y += kTitleH + kRowGap;

    if (!self.summaryText.hidden) {
        CGFloat bodyH = [OctoSummaryCardCell bodyHeightForItem:self.item width:innerW];
        self.summaryText.frame = CGRectMake(kCardInnerPadding, y, innerW, bodyH);
        y += bodyH + kBodyToFooterGap;
    }

    CGFloat footerY = cardH - kFooterH - kCardBottomPadding + 4;
    if (!self.footerTime.hidden) {
        self.footerTime.frame = CGRectMake(kCardInnerPadding, footerY, innerW - 30, kFooterH);
    }
    self.moreBtn.frame = CGRectMake(cardW - kCardInnerPadding - 24, footerY - 2, 28, 28);
}

#pragma mark - Height

/// body 区高度: completed + 有 preview → **始终预留 2 行高度**(对齐设计稿"已完成 cell
/// 双行内容"), processing → 1 行 "AI 正在分析…", 其他 → 0。
///
/// 之前用 boundingRect 按真实文字测高 + 上限 42, 短内容 (1 行就够) 会被算成一行高度,
/// frame 跟着只给一行 → UILabel 渲染就只有一行。改成 "已完成有 preview 就固定 2 行 slot"
/// 既符合设计稿一致性, 也让长 / 短 preview 都能稳定显示 2 行 (短的就空一半第二行)。
+ (CGFloat)bodyHeightForItem:(OctoSummaryListItem *)item width:(CGFloat)width {
    if (!item) return 0;
    BOOL isProcessing = (item.status == OctoTaskStatusProcessing || item.status == OctoTaskStatusPending);
    BOOL hasPreview = (item.status == OctoTaskStatusCompleted && item.summaryPreview.length > 0);
    if (!isProcessing && !hasPreview) return 0;
    UIFont *f = [UIFont systemFontOfSize:12];
    CGFloat oneLineH = ceilf(f.lineHeight);
    if (hasPreview) return oneLineH * 2 + kBodyLineSpacing;     // 2 行 ≈ 32pt
    return oneLineH;                                             // processing 1 行
}

+ (CGFloat)heightForItem:(OctoSummaryListItem *)item width:(CGFloat)width {
    CGFloat innerW = width - kCardSidePadding * 2 - kCardInnerPadding * 2;
    CGFloat bodyH = [self bodyHeightForItem:item width:innerW];
    CGFloat innerH = kCardTopPadding
                   + kInitiatorH + kRowGap
                   + kTitleH + kRowGap
                   + (bodyH > 0 ? (bodyH + kBodyToFooterGap) : 0)
                   + kFooterH + kCardBottomPadding;
    return innerH + kBetweenCards;
}

@end
