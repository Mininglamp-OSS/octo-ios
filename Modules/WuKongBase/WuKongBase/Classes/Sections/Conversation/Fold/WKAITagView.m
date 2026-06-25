//
//  WKAITagView.m
//  WuKongBase
//

#import "WKAITagView.h"
#import "WuKongBase.h" // LLang

@interface WKAITagView ()
@property(nonatomic, strong) UIView *dotView;
@property(nonatomic, strong) UILabel *titleLabel;
@end

@implementation WKAITagView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupViews];
        [self applyStyle:WKAITagStyleAssistant];
    }
    return self;
}

- (void)setupViews {
    self.layer.cornerRadius = 10; // pill：高度 20pt，half = 10
    self.layer.masksToBounds = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    self.dotView = [[UIView alloc] init];
    self.dotView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dotView.layer.cornerRadius = 3;
    self.dotView.layer.masksToBounds = YES;
    [self addSubview:self.dotView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.titleLabel.adjustsFontForContentSizeCategory = NO; // pill 不跟随动态字号防止溢出
    [self addSubview:self.titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintEqualToConstant:20],
        [self.dotView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
        [self.dotView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.dotView.widthAnchor constraintEqualToConstant:6],
        [self.dotView.heightAnchor constraintEqualToConstant:6],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.dotView.trailingAnchor constant:5],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
    ]];

    [self applyTintForCurrentTraitCollection];
}

- (void)applyStyle:(WKAITagStyle)style {
    _style = style;
    if (style == WKAITagStyleCollaboration) {
        self.titleLabel.text = LLang(@"AI 协作");
    } else {
        self.titleLabel.text = LLang(@"AI 助手");
    }
    [self applyTintForCurrentTraitCollection];
}

- (void)setStyle:(WKAITagStyle)style {
    [self applyStyle:style];
}

- (void)applyTintForCurrentTraitCollection {
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }
    if (self.style == WKAITagStyleCollaboration) {
        // 协作：偏紫，强调多 bot 协同
        self.backgroundColor = dark ? [UIColor colorWithRed:0.30 green:0.20 blue:0.55 alpha:0.40]
                                    : [UIColor colorWithRed:0.94 green:0.92 blue:1.00 alpha:1.00];
        self.titleLabel.textColor = dark ? [UIColor colorWithRed:0.85 green:0.78 blue:1.00 alpha:1.00]
                                         : [UIColor colorWithRed:0.36 green:0.22 blue:0.78 alpha:1.00];
        self.dotView.backgroundColor = self.titleLabel.textColor;
    } else {
        // 助手：偏蓝，单 bot
        self.backgroundColor = dark ? [UIColor colorWithRed:0.18 green:0.30 blue:0.55 alpha:0.40]
                                    : [UIColor colorWithRed:0.91 green:0.95 blue:1.00 alpha:1.00];
        self.titleLabel.textColor = dark ? [UIColor colorWithRed:0.65 green:0.84 blue:1.00 alpha:1.00]
                                         : [UIColor colorWithRed:0.10 green:0.42 blue:0.85 alpha:1.00];
        self.dotView.backgroundColor = self.titleLabel.textColor;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self applyTintForCurrentTraitCollection];
        }
    }
}

@end
