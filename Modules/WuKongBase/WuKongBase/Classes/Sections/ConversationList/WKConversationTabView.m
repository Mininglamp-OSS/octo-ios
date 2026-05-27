//
//  WKConversationTabView.m
//  WuKongBase
//

#import "WKConversationTabView.h"
#import "WKApp.h"
#import "WuKongBase.h"

static CGFloat const kTabHeight = 44.0f;
static CGFloat const kCapsuleHeight = 36.0f;
static CGFloat const kCapsuleHPadding = 16.0f;
static CGFloat const kBadgeSize = 16.0f;

@interface WKConversationTabView ()

@property (nonatomic, strong) UIView *capsuleContainer;
@property (nonatomic, strong) UIView *selectedCapsule;
@property (nonatomic, strong) UIButton *followBtn;
@property (nonatomic, strong) UIButton *recentBtn;
@property (nonatomic, strong) UILabel *followBadge;
@property (nonatomic, strong) UILabel *recentBadge;
@property (nonatomic, strong) UILabel *followMentionLbl;
@property (nonatomic, strong) UILabel *recentMentionLbl;

@end

@implementation WKConversationTabView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, kTabHeight)];
    if (self) {
        self.backgroundColor = [WKApp shared].config.backgroundColor;
        _selectedIndex = 0;
        [self setupUI];
        // 这是 UIView 不是 VC, 拿不到 viewConfigChange 链路, 必须自己监听 lang 通知
        // 否则 Follow / Recent 标题会停在 init 时的语言。
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onLangChange)
                                                     name:WKNOTIFY_LANG_CHANGE
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onLangChange {
    [_followBtn setTitle:LLang(@"关注") forState:UIControlStateNormal];
    [_recentBtn setTitle:LLang(@"最近") forState:UIControlStateNormal];
    _followMentionLbl.text = LLang(@"[有人@我]");
    _recentMentionLbl.text = LLang(@"[有人@我]");
    [self layoutBadges];
}

- (void)setupUI {
    _capsuleContainer = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        _capsuleContainer.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:0.18 alpha:1.0]
                : [UIColor colorWithWhite:0.93 alpha:1.0];
        }];
    } else {
        _capsuleContainer.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];
    }
    [self addSubview:_capsuleContainer];

    _selectedCapsule = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        _selectedCapsule.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        _selectedCapsule.backgroundColor = [UIColor whiteColor];
    }
    _selectedCapsule.layer.shadowColor = [UIColor blackColor].CGColor;
    _selectedCapsule.layer.shadowOpacity = 0.08;
    _selectedCapsule.layer.shadowOffset = CGSizeMake(0, 1);
    _selectedCapsule.layer.shadowRadius = 2;
    [_capsuleContainer addSubview:_selectedCapsule];

    UIColor *selectedColor = [WKApp shared].config.navBarTitleColor ?: [UIColor blackColor];
    UIColor *normalColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    UIFont *selectedFont = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];

    _followBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_followBtn setTitle:LLang(@"关注") forState:UIControlStateNormal];
    [_followBtn setTitleColor:selectedColor forState:UIControlStateNormal];
    _followBtn.titleLabel.font = selectedFont;
    [_followBtn addTarget:self action:@selector(onFollowTap) forControlEvents:UIControlEventTouchUpInside];
    [_capsuleContainer addSubview:_followBtn];

    _recentBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_recentBtn setTitle:LLang(@"最近") forState:UIControlStateNormal];
    [_recentBtn setTitleColor:normalColor forState:UIControlStateNormal];
    _recentBtn.titleLabel.font = selectedFont;
    [_recentBtn addTarget:self action:@selector(onRecentTap) forControlEvents:UIControlEventTouchUpInside];
    [_capsuleContainer addSubview:_recentBtn];

    _followBadge = [self createBadgeLabel];
    [_capsuleContainer addSubview:_followBadge];

    _recentBadge = [self createBadgeLabel];
    [_capsuleContainer addSubview:_recentBadge];

    _followMentionLbl = [self createMentionLabel];
    [_capsuleContainer addSubview:_followMentionLbl];

    _recentMentionLbl = [self createMentionLabel];
    [_capsuleContainer addSubview:_recentMentionLbl];
}

- (UILabel *)createMentionLabel {
    UILabel *lbl = [[UILabel alloc] init];
    // PR review #9 warning：走项目 LLang 取本地化，非中文 locale 才不会回退到硬编码中文
    lbl.text = LLang(@"[有人@我]");
    lbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor orangeColor];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.hidden = YES;
    return lbl;
}

- (UILabel *)createBadgeLabel {
    UILabel *badge = [[UILabel alloc] init];
    badge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    badge.textColor = [UIColor whiteColor];
    badge.backgroundColor = [UIColor redColor];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.layer.cornerRadius = kBadgeSize / 2.0f;
    badge.layer.masksToBounds = YES;
    badge.hidden = YES;
    return badge;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.bounds.size.width;
    CGFloat capsuleW = w - kCapsuleHPadding * 2;
    CGFloat capsuleY = (kTabHeight - kCapsuleHeight) / 2.0f;
    CGFloat capsuleRadius = kCapsuleHeight / 2.0f;
    CGFloat inset = 3.0f;

    _capsuleContainer.frame = CGRectMake(kCapsuleHPadding, capsuleY, capsuleW, kCapsuleHeight);
    _capsuleContainer.layer.cornerRadius = capsuleRadius;
    _capsuleContainer.layer.masksToBounds = YES;

    CGFloat halfW = capsuleW / 2.0f;
    _followBtn.frame = CGRectMake(0, 0, halfW, kCapsuleHeight);
    _recentBtn.frame = CGRectMake(halfW, 0, halfW, kCapsuleHeight);

    [self layoutSelectedCapsuleAnimated:NO];
    [self layoutBadges];
    [self layoutMentionLabel];
}

- (void)layoutSelectedCapsuleAnimated:(BOOL)animated {
    CGFloat capsuleW = _capsuleContainer.bounds.size.width;
    CGFloat halfW = capsuleW / 2.0f;
    CGFloat inset = 3.0f;
    CGFloat selectedW = halfW - inset * 2;
    CGFloat selectedH = kCapsuleHeight - inset * 2;
    CGFloat selectedX = (_selectedIndex == 0) ? inset : (halfW + inset);
    CGFloat selectedY = inset;
    CGFloat selectedRadius = selectedH / 2.0f;

    CGRect targetFrame = CGRectMake(selectedX, selectedY, selectedW, selectedH);

    void (^applyFrame)(void) = ^{
        self.selectedCapsule.frame = targetFrame;
        self.selectedCapsule.layer.cornerRadius = selectedRadius;
    };

    if (animated) {
        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:applyFrame
                         completion:nil];
    } else {
        applyFrame();
    }
}

- (void)layoutBadges {
    [self layoutFollowContent];
    [self layoutRecentContent];
}

- (CGFloat)extraWidthForFollow {
    return [self extraWidthForMention:_followMentionLbl badge:_followBadge];
}

- (CGFloat)extraWidthForRecent {
    return [self extraWidthForMention:_recentMentionLbl badge:_recentBadge];
}

/// 计算 button title 右侧附加内容（mention 标签 + 未读 badge）所需宽度,
/// 用于 titleEdgeInsets 把整体居中。
- (CGFloat)extraWidthForMention:(UILabel *)mention badge:(UILabel *)badge {
    CGFloat extra = 0;
    if (!mention.hidden) {
        [mention sizeToFit];
        extra += 2 + mention.bounds.size.width + 2;
    }
    if (!badge.hidden) {
        [badge sizeToFit];
        extra += 2 + MAX(badge.bounds.size.width + 6, kBadgeSize);
    }
    return extra;
}

- (void)layoutFollowContent {
    [self layoutTabButton:_followBtn mention:_followMentionLbl badge:_followBadge extra:[self extraWidthForFollow]];
}

- (void)layoutRecentContent {
    [self layoutTabButton:_recentBtn mention:_recentMentionLbl badge:_recentBadge extra:[self extraWidthForRecent]];
}

- (void)layoutTabButton:(UIButton *)btn
                mention:(UILabel *)mention
                  badge:(UILabel *)badge
                  extra:(CGFloat)extra {
    CGFloat offset = -extra / 2.0f;
    btn.titleEdgeInsets = UIEdgeInsetsMake(0, offset, 0, -offset);
    [btn layoutIfNeeded];

    NSString *title = btn.titleLabel.text ?: @"";
    UIFont *font = btn.titleLabel.font;
    CGFloat textW = [title sizeWithAttributes:@{NSFontAttributeName: font}].width;
    CGFloat titleRight = CGRectGetMidX(btn.frame) + offset + textW / 2.0f;
    CGFloat btnCenterY = CGRectGetMidY(btn.frame);

    CGFloat x = titleRight;
    if (!mention.hidden) {
        CGFloat lblW = mention.bounds.size.width + 2;
        CGFloat lblH = mention.bounds.size.height;
        mention.frame = CGRectMake(x + 2, btnCenterY - lblH / 2.0f + 1, lblW, lblH);
        x += 2 + lblW;
    }
    if (!badge.hidden) {
        CGFloat badgeW = MAX(badge.bounds.size.width + 6, kBadgeSize);
        badge.frame = CGRectMake(x + 2, btnCenterY - kBadgeSize / 2.0f - 4, badgeW, kBadgeSize);
    }
}

#pragma mark - Actions

- (void)onFollowTap {
    [self setSelectedIndex:0 animated:YES];
}

- (void)onRecentTap {
    [self setSelectedIndex:1 animated:YES];
}

- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    [self updateButtonStyles];
    [self layoutSelectedCapsuleAnimated:animated];
    [self layoutBadges];
    [self layoutMentionLabel];
    if (self.onTabChanged) {
        self.onTabChanged(index);
    }
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    if (_selectedIndex == selectedIndex) return;
    _selectedIndex = selectedIndex;
    [self updateButtonStyles];
    [self layoutSelectedCapsuleAnimated:NO];
    [self layoutBadges];
    [self layoutMentionLabel];
}

- (void)updateButtonStyles {
    UIColor *selectedColor = [WKApp shared].config.navBarTitleColor ?: [UIColor blackColor];
    UIColor *normalColor = [UIColor colorWithWhite:0.5 alpha:1.0];

    if (_selectedIndex == 0) {
        [_followBtn setTitleColor:selectedColor forState:UIControlStateNormal];
        [_recentBtn setTitleColor:normalColor forState:UIControlStateNormal];
    } else {
        [_followBtn setTitleColor:normalColor forState:UIControlStateNormal];
        [_recentBtn setTitleColor:selectedColor forState:UIControlStateNormal];
    }
}

#pragma mark - Badge

- (void)layoutMentionLabel {
    // mention 与 badge 共享同一份布局函数（layoutFollowContent / layoutRecentContent），
    // 这里直接整体重排两边即可。
    [self layoutBadges];
}

- (void)setFollowHasMention:(BOOL)hasMention {
    _followMentionLbl.hidden = !hasMention;
    [self layoutMentionLabel];
}

- (void)setRecentHasMention:(BOOL)hasMention {
    _recentMentionLbl.hidden = !hasMention;
    [self layoutMentionLabel];
}

- (void)setFollowUnreadCount:(NSInteger)count {
    [self updateBadge:_followBadge count:count];
    [self layoutBadges];
}

- (void)setRecentUnreadCount:(NSInteger)count {
    [self updateBadge:_recentBadge count:count];
    [self layoutBadges];
}

- (void)updateBadge:(UILabel *)badge count:(NSInteger)count {
    if (count <= 0) {
        badge.hidden = YES;
        return;
    }
    badge.hidden = NO;
    if (count > 99) {
        badge.text = @"99+";
    } else {
        badge.text = [NSString stringWithFormat:@"%ld", (long)count];
    }
}

@end
