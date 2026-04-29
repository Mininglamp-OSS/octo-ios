//
//  WKContactsHeaderItemCell.m
//  WuKongContacts
//
//  Created by tt on 2020/1/4.
//

#import "WKContactsHeaderItemCell.h"
#import "WKContactsSVGIcons.h"
#import "WKBadgeView.h"

@interface WKContactsHeaderItemCell ()

@property(nonatomic,strong) UIView *iconContainer;
@property(nonatomic,strong) CAGradientLayer *iconGradient;
@property(nonatomic,strong) UIImageView *svgIconView;
@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) WKBadgeView *badgeView;
@property(nonatomic,strong) UILabel *countLbl;
@property(nonatomic,strong) UIImageView *chevronView;
@property(nonatomic,strong) UIView *dividerLine;

@end

@implementation WKContactsHeaderItemCell

-(void) setupUI {
    CGFloat iconSize = 36.0f;
    CGFloat iconRadius = 10.0f;

    _iconContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, iconSize, iconSize)];
    _iconContainer.layer.cornerRadius = iconRadius;
    _iconContainer.layer.masksToBounds = YES;

    _iconGradient = [CAGradientLayer layer];
    _iconGradient.frame = _iconContainer.bounds;
    _iconGradient.startPoint = CGPointMake(0, 0);
    _iconGradient.endPoint = CGPointMake(1, 1);
    _iconGradient.cornerRadius = iconRadius;
    [_iconContainer.layer insertSublayer:_iconGradient atIndex:0];

    _svgIconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 18, 18)];
    _svgIconView.contentMode = UIViewContentModeScaleAspectFit;
    [_iconContainer addSubview:_svgIconView];

    [self.contentView addSubview:_iconContainer];

    _titleLbl = [[UILabel alloc] init];
    [_titleLbl setFont:[[WKApp shared].config appFontOfSizeMedium:15.0f]];
    [self.contentView addSubview:_titleLbl];

    _badgeView = [WKBadgeView viewWithoutBadgeTip];
    [self.contentView addSubview:_badgeView];

    _countLbl = [[UILabel alloc] init];
    _countLbl.font = [UIFont systemFontOfSize:14.0f];
    _countLbl.textColor = [UIColor grayColor];
    [self.contentView addSubview:_countLbl];

    _chevronView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 14, 14)];
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:_chevronView];

    _dividerLine = [[UIView alloc] init];
    [self.contentView addSubview:_dividerLine];
}

-(void)refresh:(WKContactsHeaderItem*)model {
    [super refresh:model];

    [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    [self.titleLbl setTextColor:[WKApp shared].config.defaultTextColor];

    // Gradient colors based on kind
    NSArray *gradientColors = [self gradientColorsForKind:model.gradientKind];
    _iconGradient.colors = gradientColors;

    // SVG icon
    if (model.svgIconName && model.svgIconName.length > 0) {
        _svgIconView.image = [WKContactsSVGIcons iconNamed:model.svgIconName size:18 color:[UIColor whiteColor] strokeWidth:1.8f];
        _iconContainer.hidden = NO;
    } else {
        _iconContainer.hidden = YES;
    }

    self.titleLbl.text = model.title;
    [self.titleLbl sizeToFit];

    // Badge
    self.badgeView.badgeValue = @"";
    if (model.badgeValue && ![model.badgeValue isEqualToString:@""]) {
        self.badgeView.badgeValue = model.badgeValue;
        self.badgeView.hidden = NO;
    } else {
        self.badgeView.hidden = YES;
    }

    // Count
    self.countLbl.text = model.countValue ?: @"";
    [self.countLbl sizeToFit];
    self.countLbl.hidden = (!model.countValue || model.countValue.length == 0);

    // Chevron
    UIColor *chevronColor = WKApp.shared.config.tipColor;
    _chevronView.image = [WKContactsSVGIcons iconNamed:@"chevron-right" size:14 color:chevronColor strokeWidth:2.0f];

    // Divider
    _dividerLine.backgroundColor = WKApp.shared.config.lineColor;
}

-(NSArray*) gradientColorsForKind:(NSString*)kind {
    if ([kind isEqualToString:@"friend"]) {
        return @[
            (id)[UIColor colorWithRed:124/255.0f green:141/255.0f blue:255/255.0f alpha:1.0f].CGColor,
            (id)[UIColor colorWithRed:106/255.0f green:92/255.0f blue:251/255.0f alpha:1.0f].CGColor
        ];
    } else if ([kind isEqualToString:@"group"]) {
        return @[
            (id)[UIColor colorWithRed:155/255.0f green:127/255.0f blue:255/255.0f alpha:1.0f].CGColor,
            (id)[UIColor colorWithRed:106/255.0f green:92/255.0f blue:251/255.0f alpha:1.0f].CGColor
        ];
    } else if ([kind isEqualToString:@"ai"]) {
        return @[
            (id)[UIColor colorWithRed:185/255.0f green:123/255.0f blue:255/255.0f alpha:1.0f].CGColor,
            (id)[UIColor colorWithRed:122/255.0f green:92/255.0f blue:251/255.0f alpha:1.0f].CGColor
        ];
    }
    return @[
        (id)WKApp.shared.config.themeColor.CGColor,
        (id)WKApp.shared.config.themeColor.CGColor
    ];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat leftPad = 14.0f;
    CGFloat rightPad = 14.0f;
    CGFloat iconToTitle = 12.0f;

    // Icon container
    _iconContainer.lim_left = leftPad;
    _iconContainer.lim_top = self.lim_height / 2.0f - _iconContainer.lim_height / 2.0f;

    // SVG icon centered in container
    _svgIconView.center = CGPointMake(_iconContainer.lim_width / 2.0f, _iconContainer.lim_height / 2.0f);

    // Title
    _titleLbl.lim_left = _iconContainer.lim_right + iconToTitle;
    _titleLbl.lim_top = self.lim_height / 2.0f - _titleLbl.lim_height / 2.0f;

    // Chevron on right
    _chevronView.lim_left = self.contentView.lim_width - rightPad - _chevronView.lim_width;
    _chevronView.lim_top = self.lim_height / 2.0f - _chevronView.lim_height / 2.0f;

    // Badge / count between title and chevron
    CGFloat rightEdge = _chevronView.lim_left - 8.0f;
    if (!_badgeView.hidden) {
        _badgeView.lim_left = rightEdge - _badgeView.lim_width;
        _badgeView.lim_top = self.lim_height / 2.0f - _badgeView.lim_height / 2.0f;
    }
    if (!_countLbl.hidden) {
        _countLbl.lim_left = _titleLbl.lim_right + 4.0f;
        _countLbl.lim_top = self.lim_height / 2.0f - _countLbl.lim_height / 2.0f;
    }

    // Divider line
    _dividerLine.frame = CGRectMake(_titleLbl.lim_left, self.lim_height - 0.5f, self.contentView.lim_width - _titleLbl.lim_left, 0.5f);
}

+ (NSString *)cellId {
    return @"WKContactsHeaderItemCell";
}

@end
