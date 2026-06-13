//
//  OctoDetailSourcesView.m
//  OctoContext
//

#import "OctoDetailSourcesView.h"
#import <WuKongBase/WuKongBase.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

static const CGFloat kPillH       = 24;
static const CGFloat kPillHGap    = 6;
static const CGFloat kPillVGap    = 6;
static const CGFloat kPillSidePad = 10;
static const CGFloat kToggleW     = 28;
static const CGFloat kToggleGap   = 4;
static const CGFloat kEtcW        = 24;     // "等" 提示宽度

@interface OctoDetailSourcesView ()
@property(nonatomic, strong) NSMutableArray<UILabel *> *pills;
@property(nonatomic, strong) UIButton *toggleBtn;
@property(nonatomic, strong) UILabel *etcLabel;        // 折叠态有溢出时显示 "等"
@end

@implementation OctoDetailSourcesView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _pills = [NSMutableArray array];
        _toggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium];
            [_toggleBtn setImage:[UIImage systemImageNamed:@"chevron.down" withConfiguration:cfg] forState:UIControlStateNormal];
        }
        _toggleBtn.tintColor = [UIColor.labelColor colorWithAlphaComponent:0.5];
        _toggleBtn.hidden = YES;
        [_toggleBtn addTarget:self action:@selector(onToggleTap) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_toggleBtn];

        _etcLabel = [UILabel new];
        _etcLabel.text = LLang(@"等");
        _etcLabel.font = [UIFont systemFontOfSize:12];
        _etcLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.5];
        _etcLabel.textAlignment = NSTextAlignmentCenter;
        _etcLabel.hidden = YES;
        [self addSubview:_etcLabel];
    }
    return self;
}

- (void)setItems:(NSArray<OctoSourceItem *> *)items {
    _items = [items copy] ?: @[];
    [self rebuildPills];
    [self setNeedsLayout];
}

- (void)setExpanded:(BOOL)expanded {
    if (_expanded == expanded) return;
    _expanded = expanded;
    [self setNeedsLayout];
}

#pragma mark - Source display name (子区 拼上父群名)

/// 子区显示 "# 子区名 · 父群名"; 取不到父群时降级为 "# 子区名"。
/// 群聊 / 私聊直接用 sourceName。
- (NSString *)displayNameFor:(OctoSourceItem *)s {
    NSString *base = s.sourceName.length > 0 ? s.sourceName : s.sourceId;
    if (s.sourceType == OctoSourceThread) {
        // SDK 用 WK_GROUP 类型同时承载群和子区, 子区的 channelInfo 有 parentChannel。
        WKChannel *ch = [WKChannel channelID:s.sourceId channelType:WK_GROUP];
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:ch];
        WKChannel *parent = info.parentChannel;
        if (parent.channelId.length > 0) {
            WKChannelInfo *pinfo = [[WKSDK shared].channelManager getChannelInfo:parent];
            if (pinfo.name.length > 0) {
                return [NSString stringWithFormat:@"# %@ · %@", base, pinfo.name];
            }
        }
        return [NSString stringWithFormat:@"# %@", base];
    }
    return base;
}

- (void)rebuildPills {
    for (UILabel *p in self.pills) [p removeFromSuperview];
    [self.pills removeAllObjects];
    for (OctoSourceItem *it in self.items) {
        UILabel *l = [UILabel new];
        l.text = [self displayNameFor:it];
        l.font = [UIFont systemFontOfSize:12];
        l.textColor = [self chipFgFor:it.sourceType];
        l.backgroundColor = [self chipBgFor:it.sourceType];
        l.textAlignment = NSTextAlignmentCenter;
        l.layer.cornerRadius = kPillH / 2.0;
        l.layer.masksToBounds = YES;
        l.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:l];
        [self.pills addObject:l];
    }
}

/// 三种 source 三种色:
///   群聊  → 紫色淡底 + 紫文字
///   子区  → 蓝绿淡底 + 蓝绿文字 (与群聊明确区分)
///   私聊  → 灰底 + 标准文字色
- (UIColor *)chipBgFor:(OctoSourceType)t {
    UIColor *purple = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
    UIColor *teal   = [UIColor colorWithRed:0x14/255.0 green:0xB8/255.0 blue:0xA6/255.0 alpha:1.0];
    UIColor *mute   = [UIColor.labelColor colorWithAlphaComponent:0.06];
    if (t == OctoSourceGroupChat) return [purple colorWithAlphaComponent:0.10];
    if (t == OctoSourceThread)    return [teal   colorWithAlphaComponent:0.10];
    return mute;
}

- (UIColor *)chipFgFor:(OctoSourceType)t {
    UIColor *purple = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
    UIColor *teal   = [UIColor colorWithRed:0x0E/255.0 green:0x9B/255.0 blue:0x8C/255.0 alpha:1.0];
    if (t == OctoSourceGroupChat) return purple;
    if (t == OctoSourceThread)    return teal;
    return [UIColor labelColor];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    [self flowLayoutInWidth:self.bounds.size.width applyFrames:YES];
}

/// 单次流式布局, apply=YES 时落帧, 同时根据是否溢出/是否展开决定:
///   - toggleBtn 是否可见 (溢出才出)
///   - etcLabel  是否可见 (折叠态 + 有溢出时出, 落在第 0 行末尾告诉用户"还有更多")
- (void)flowLayoutInWidth:(CGFloat)width applyFrames:(BOOL)apply {
    // 折叠态第 0 行右侧需要给 toggle + etc 留位置
    CGFloat reservedRight = kToggleW + kToggleGap + kEtcW + kPillHGap;
    CGFloat row0Avail = MAX(0, width - reservedRight);

    CGFloat x = 0, y = 0;
    NSInteger row = 0;
    BOOL multiRow = NO;
    for (UILabel *p in self.pills) {
        CGFloat textW = ceilf([p.text sizeWithAttributes:@{NSFontAttributeName: p.font}].width);
        CGFloat pw = MIN(textW + kPillSidePad * 2, MAX(60, width));
        CGFloat avail = (row == 0) ? row0Avail : width;
        if (x + pw > avail && x > 0) {
            x = 0; y += kPillH + kPillVGap;
            row++; multiRow = YES;
        }
        if (apply) {
            BOOL visible = (self.expanded || row == 0);
            p.frame = CGRectMake(x, y, pw, kPillH);
            p.alpha = visible ? 1.0 : 0.0;
            p.userInteractionEnabled = visible;
        }
        x += pw + kPillHGap;
    }
    if (!apply) return;

    self.toggleBtn.hidden = !multiRow;
    if (multiRow) {
        self.toggleBtn.frame = CGRectMake(width - kToggleW, 0, kToggleW, kPillH);
        self.toggleBtn.transform = self.expanded
            ? CGAffineTransformMakeRotation((CGFloat)M_PI)
            : CGAffineTransformIdentity;
    }
    // "等": 折叠态 + 多行时展示, 紧接最后一个第 0 行 chip 的右边
    BOOL showEtc = (multiRow && !self.expanded);
    self.etcLabel.hidden = !showEtc;
    if (showEtc) {
        // 重新算第 0 行末尾位置 —— x 已经走过了所有 pill, 但 row > 0 的 pill 不在第 0 行,
        // 改用最后一个第 0 行 pill 的右边缘。
        CGFloat lastRow0Right = 0;
        for (UILabel *p in self.pills) {
            if (CGRectGetMinY(p.frame) > 0) break;        // row > 0 的退出
            lastRow0Right = CGRectGetMaxX(p.frame);
        }
        CGFloat etcX = lastRow0Right + kPillHGap;
        self.etcLabel.frame = CGRectMake(etcX, 0, kEtcW, kPillH);
    }
}

- (CGFloat)heightForWidth:(CGFloat)width {
    if (self.items.count == 0) return 0;
    if (!self.expanded) return kPillH;
    CGFloat reservedRight = kToggleW + kToggleGap + kEtcW + kPillHGap;
    CGFloat row0Avail = MAX(0, width - reservedRight);
    CGFloat x = 0, rows = 1;
    for (OctoSourceItem *it in self.items) {
        NSString *txt = [self displayNameFor:it];
        CGFloat textW = ceilf([txt sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12]}].width);
        CGFloat pw = MIN(textW + kPillSidePad * 2, MAX(60, width));
        CGFloat avail = (rows == 1) ? row0Avail : width;
        if (x + pw > avail && x > 0) { x = 0; rows++; }
        x += pw + kPillHGap;
    }
    return kPillH * rows + kPillVGap * (rows - 1);
}

#pragma mark - Toggle

- (void)onToggleTap {
    self.expanded = !self.expanded;
    if (self.onToggle) self.onToggle(self.expanded);
    [UIView animateWithDuration:0.22 delay:0
                        options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    } completion:nil];
}

@end
