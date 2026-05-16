// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
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
@property (nonatomic, strong) UIButton *groupBtn;
@property (nonatomic, strong) UIButton *privateBtn;
@property (nonatomic, strong) UILabel *groupBadge;
@property (nonatomic, strong) UILabel *privateBadge;
@property (nonatomic, strong) UILabel *mentionLbl;

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

    _groupBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_groupBtn setTitle:LLang(@"群聊") forState:UIControlStateNormal];
    [_groupBtn setTitleColor:selectedColor forState:UIControlStateNormal];
    _groupBtn.titleLabel.font = selectedFont;
    [_groupBtn addTarget:self action:@selector(onGroupTap) forControlEvents:UIControlEventTouchUpInside];
    [_capsuleContainer addSubview:_groupBtn];

    _privateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_privateBtn setTitle:LLang(@"私聊") forState:UIControlStateNormal];
    [_privateBtn setTitleColor:normalColor forState:UIControlStateNormal];
    _privateBtn.titleLabel.font = selectedFont;
    [_privateBtn addTarget:self action:@selector(onPrivateTap) forControlEvents:UIControlEventTouchUpInside];
    [_capsuleContainer addSubview:_privateBtn];

    _groupBadge = [self createBadgeLabel];
    [_capsuleContainer addSubview:_groupBadge];

    _privateBadge = [self createBadgeLabel];
    [_capsuleContainer addSubview:_privateBadge];

    _mentionLbl = [[UILabel alloc] init];
    _mentionLbl.text = @"[有人@我]";
    _mentionLbl.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    _mentionLbl.textColor = [UIColor orangeColor];
    _mentionLbl.textAlignment = NSTextAlignmentCenter;
    _mentionLbl.hidden = YES;
    [_capsuleContainer addSubview:_mentionLbl];
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
    _groupBtn.frame = CGRectMake(0, 0, halfW, kCapsuleHeight);
    _privateBtn.frame = CGRectMake(halfW, 0, halfW, kCapsuleHeight);

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
    [self layoutGroupContent];
    [self layoutPrivateContent];
}

- (CGFloat)extraWidthForGroup {
    CGFloat extra = 0;
    if (!_mentionLbl.hidden) {
        [_mentionLbl sizeToFit];
        extra += 2 + _mentionLbl.bounds.size.width + 2;
    }
    if (!_groupBadge.hidden) {
        [_groupBadge sizeToFit];
        extra += 2 + MAX(_groupBadge.bounds.size.width + 6, kBadgeSize);
    }
    return extra;
}

- (CGFloat)extraWidthForPrivate {
    if (_privateBadge.hidden) return 0;
    [_privateBadge sizeToFit];
    return 2 + MAX(_privateBadge.bounds.size.width + 6, kBadgeSize);
}

- (void)layoutGroupContent {
    CGFloat extra = [self extraWidthForGroup];
    CGFloat offset = -extra / 2.0f;
    _groupBtn.titleEdgeInsets = UIEdgeInsetsMake(0, offset, 0, -offset);
    [_groupBtn layoutIfNeeded];

    NSString *title = _groupBtn.titleLabel.text ?: @"";
    UIFont *font = _groupBtn.titleLabel.font;
    CGFloat textW = [title sizeWithAttributes:@{NSFontAttributeName: font}].width;
    CGFloat titleRight = CGRectGetMidX(_groupBtn.frame) + offset + textW / 2.0f;
    CGFloat btnCenterY = CGRectGetMidY(_groupBtn.frame);

    CGFloat x = titleRight;
    if (!_mentionLbl.hidden) {
        CGFloat lblW = _mentionLbl.bounds.size.width + 2;
        CGFloat lblH = _mentionLbl.bounds.size.height;
        _mentionLbl.frame = CGRectMake(x + 2, btnCenterY - lblH / 2.0f + 1, lblW, lblH);
        x += 2 + lblW;
    }
    if (!_groupBadge.hidden) {
        CGFloat badgeW = MAX(_groupBadge.bounds.size.width + 6, kBadgeSize);
        _groupBadge.frame = CGRectMake(x + 2, btnCenterY - kBadgeSize / 2.0f - 4, badgeW, kBadgeSize);
    }
}

- (void)layoutPrivateContent {
    CGFloat extra = [self extraWidthForPrivate];
    CGFloat offset = -extra / 2.0f;
    _privateBtn.titleEdgeInsets = UIEdgeInsetsMake(0, offset, 0, -offset);
    [_privateBtn layoutIfNeeded];

    if (_privateBadge.hidden) return;

    NSString *title = _privateBtn.titleLabel.text ?: @"";
    UIFont *font = _privateBtn.titleLabel.font;
    CGFloat textW = [title sizeWithAttributes:@{NSFontAttributeName: font}].width;
    CGFloat titleRight = CGRectGetMidX(_privateBtn.frame) + offset + textW / 2.0f;
    CGFloat btnCenterY = CGRectGetMidY(_privateBtn.frame);

    CGFloat badgeW = MAX(_privateBadge.bounds.size.width + 6, kBadgeSize);
    _privateBadge.frame = CGRectMake(titleRight + 2, btnCenterY - kBadgeSize / 2.0f - 4, badgeW, kBadgeSize);
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
        [_groupBtn setTitleColor:selectedColor forState:UIControlStateNormal];
        [_privateBtn setTitleColor:normalColor forState:UIControlStateNormal];
    } else {
        [_groupBtn setTitleColor:normalColor forState:UIControlStateNormal];
        [_privateBtn setTitleColor:selectedColor forState:UIControlStateNormal];
    }
}

#pragma mark - Badge

- (void)layoutMentionLabel {
    [self layoutGroupContent];
}

- (void)setGroupHasMention:(BOOL)hasMention {
    _mentionLbl.hidden = !hasMention;
    [self layoutMentionLabel];
}

- (void)setGroupUnreadCount:(NSInteger)count {
    // 不再显示未读红点
}

- (void)setPrivateUnreadCount:(NSInteger)count {
    [self updateBadge:_privateBadge count:count];
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
