//
//  WKConversationTabView.m
//  WuKongBase
//

#import "WKConversationTabView.h"
#import "WKApp.h"
#import "WuKongBase.h"

static CGFloat const kTabHeight = 40.0f;
static CGFloat const kIndicatorHeight = 2.5f;
static CGFloat const kBadgeSize = 16.0f;
static CGFloat const kHorizontalPadding = 16.0f;

@interface WKConversationTabView ()

@property (nonatomic, strong) UIButton *groupBtn;
@property (nonatomic, strong) UIButton *privateBtn;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) UILabel *groupBadge;
@property (nonatomic, strong) UILabel *privateBadge;
@property (nonatomic, strong) UIView *bottomLine; // 底部分隔线
@property (nonatomic, strong) UILabel *mentionLbl; // @提醒标识

@end

@implementation WKConversationTabView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, kTabHeight)];
    if (self) {
        self.backgroundColor = [WKApp shared].config.backgroundColor;
        _selectedIndex = 0;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    UIColor *selectedColor = [WKApp shared].config.navBarTitleColor ?: [UIColor blackColor];
    UIColor *normalColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    UIFont *selectedFont = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    UIFont *normalFont = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];

    _groupBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_groupBtn setTitle:LLang(@"群组") forState:UIControlStateNormal];
    [_groupBtn setTitleColor:selectedColor forState:UIControlStateNormal];
    _groupBtn.titleLabel.font = selectedFont;
    [_groupBtn addTarget:self action:@selector(onGroupTap) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_groupBtn];

    _privateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_privateBtn setTitle:LLang(@"私聊") forState:UIControlStateNormal];
    [_privateBtn setTitleColor:normalColor forState:UIControlStateNormal];
    _privateBtn.titleLabel.font = normalFont;
    [_privateBtn addTarget:self action:@selector(onPrivateTap) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_privateBtn];

    _indicator = [[UIView alloc] init];
    _indicator.backgroundColor = [WKApp shared].config.themeColor;
    _indicator.layer.cornerRadius = kIndicatorHeight / 2.0f;
    [self addSubview:_indicator];

    _groupBadge = [self createBadgeLabel];
    [self addSubview:_groupBadge];

    _privateBadge = [self createBadgeLabel];
    [self addSubview:_privateBadge];

    _bottomLine = [[UIView alloc] init];
    if (@available(iOS 13.0, *)) {
        _bottomLine.backgroundColor = [UIColor separatorColor];
    } else {
        _bottomLine.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    }
    [self addSubview:_bottomLine];

    _mentionLbl = [[UILabel alloc] init];
    _mentionLbl.text = @"@";
    _mentionLbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    _mentionLbl.textColor = [UIColor whiteColor];
    _mentionLbl.backgroundColor = [UIColor orangeColor];
    _mentionLbl.textAlignment = NSTextAlignmentCenter;
    _mentionLbl.layer.cornerRadius = 7;
    _mentionLbl.layer.masksToBounds = YES;
    _mentionLbl.hidden = YES;
    [self addSubview:_mentionLbl];
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
    CGFloat h = self.bounds.size.height;
    CGFloat btnH = h - kIndicatorHeight;
    CGFloat tabGap = 24.0f;

    [_groupBtn sizeToFit];
    [_privateBtn sizeToFit];
    CGFloat groupW = _groupBtn.intrinsicContentSize.width + 4;
    CGFloat privateW = _privateBtn.intrinsicContentSize.width + 4;

    _groupBtn.frame = CGRectMake(kHorizontalPadding, 0, groupW, btnH);
    _privateBtn.frame = CGRectMake(_groupBtn.lim_right + tabGap, 0, privateW, btnH);

    [self layoutIndicatorAnimated:NO];
    [self layoutBadges];
    [self layoutMentionLabel];

    _bottomLine.frame = CGRectMake(kHorizontalPadding, h - 0.5, w - kHorizontalPadding * 2, 0.5);
}

- (void)layoutIndicatorAnimated:(BOOL)animated {
    UIButton *btn = (_selectedIndex == 0) ? _groupBtn : _privateBtn;

    NSString *title = btn.titleLabel.text ?: @"";
    UIFont *font = btn.titleLabel.font;
    CGFloat textW = [title sizeWithAttributes:@{NSFontAttributeName: font}].width;
    CGFloat indicatorW = textW + 4;
    CGFloat indicatorX = CGRectGetMidX(btn.frame) - indicatorW / 2.0f;
    CGFloat indicatorY = self.bounds.size.height - kIndicatorHeight;

    CGRect targetFrame = CGRectMake(indicatorX, indicatorY, indicatorW, kIndicatorHeight);

    if (animated) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.indicator.frame = targetFrame;
        } completion:nil];
    } else {
        self.indicator.frame = targetFrame;
    }
}

- (void)layoutBadges {
    [self layoutBadge:_groupBadge forButton:_groupBtn];
    [self layoutBadge:_privateBadge forButton:_privateBtn];
}

- (void)layoutBadge:(UILabel *)badge forButton:(UIButton *)btn {
    if (badge.hidden) return;
    [badge sizeToFit];

    // 算出文字右边缘，角标紧贴文字后面
    NSString *title = btn.titleLabel.text ?: @"";
    UIFont *font = btn.titleLabel.font;
    CGFloat textW = [title sizeWithAttributes:@{NSFontAttributeName: font}].width;
    CGFloat textRight = CGRectGetMidX(btn.frame) + textW / 2.0f;
    CGFloat btnCenterY = CGRectGetMidY(btn.frame);

    CGFloat badgeW = MAX(badge.bounds.size.width + 6, kBadgeSize);
    badge.frame = CGRectMake(textRight + 2, btnCenterY - kBadgeSize / 2.0f - 4, badgeW, kBadgeSize);
}

#pragma mark - Actions

- (void)onGroupTap {
    [self setSelectedIndex:0 animated:YES];
}

- (void)onPrivateTap {
    [self setSelectedIndex:1 animated:YES];
}

- (void)setSelectedIndex:(NSInteger)index animated:(BOOL)animated {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    [self updateButtonStyles];
    [self layoutIndicatorAnimated:animated];
    [self layoutBadges];
    if (self.onTabChanged) {
        self.onTabChanged(index);
    }
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    if (_selectedIndex == selectedIndex) return;
    _selectedIndex = selectedIndex;
    [self updateButtonStyles];
    [self layoutIndicatorAnimated:NO];
    [self layoutBadges];
}

- (void)updateButtonStyles {
    UIColor *selectedColor = [WKApp shared].config.navBarTitleColor ?: [UIColor blackColor];
    UIColor *normalColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    UIFont *selectedFont = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    UIFont *normalFont = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];

    _indicator.backgroundColor = [WKApp shared].config.themeColor;

    if (_selectedIndex == 0) {
        [_groupBtn setTitleColor:selectedColor forState:UIControlStateNormal];
        _groupBtn.titleLabel.font = selectedFont;
        [_privateBtn setTitleColor:normalColor forState:UIControlStateNormal];
        _privateBtn.titleLabel.font = normalFont;
    } else {
        [_groupBtn setTitleColor:normalColor forState:UIControlStateNormal];
        _groupBtn.titleLabel.font = normalFont;
        [_privateBtn setTitleColor:selectedColor forState:UIControlStateNormal];
        _privateBtn.titleLabel.font = selectedFont;
    }
}

#pragma mark - Badge

- (void)layoutMentionLabel {
    if (_mentionLbl.hidden) return;
    CGFloat lblSize = 14;
    CGFloat btnTop = CGRectGetMinY(_groupBtn.frame);
    _mentionLbl.frame = CGRectMake(_groupBtn.lim_right + 2, btnTop + 4, lblSize, lblSize);
}

- (void)setGroupHasMention:(BOOL)hasMention {
    _mentionLbl.hidden = !hasMention;
    [self layoutMentionLabel];
}

- (void)setGroupUnreadCount:(NSInteger)count {
    // 不再显示未读红点
}

- (void)setPrivateUnreadCount:(NSInteger)count {
    // 不再显示未读红点
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
