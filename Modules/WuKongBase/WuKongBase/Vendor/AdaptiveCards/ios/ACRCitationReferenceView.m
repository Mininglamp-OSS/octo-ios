//
//  ACRCitationReferenceView.m
//  AdaptiveCards
//
//  Created by Gaurav Keshre on 31/10/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRCitationReferenceView.h"
#import "ACOReference.h"
#import "ACOCitation.h"
#import "ACOBundle.h"
#import "UIColor+GrayColor.h"

// Layout Constants (inherits kACRCitationViewSpacing from base class)
static const CGFloat kACRCitationViewSpacing = 8.0;

// Pill Constants
static const CGFloat kACRCitationPillFontSize = 12.0;
static const CGFloat kACRCitationPillBorderWidth = 1.0;
static const CGFloat kACRCitationPillCornerRadius = 4.0;
static const CGFloat kACRCitationPillMinSize = 17.0;
static const CGFloat kACRCitationPillMaxWidth = 50.0;
static const CGFloat kACRCitationPillTopBottomPadding = 1.0;
static const CGFloat kACRCitationPillLeftRightPadding = 2.0;

// Icon Constants
static const CGFloat kACRCitationIconSize = 32.0;

// Title Constants
static const CGFloat kACRCitationTitleFontSize = 16.0;

// Abstract Constants
static const CGFloat kACRCitationAbstractFontSize = 15.0;
static const NSInteger kACRCitationAbstractTextColor = 34;

// Keywords Constants
static const CGFloat kACRCitationKeywordsFontSize = 12.0;
static const CGFloat kACRCitationKeywordsMinHeight = 16.0;
static const NSInteger kACRCitationKeywordsTextColor = 110;
static const NSInteger kACRCitationMaxKeywords = 3;

// More Details Button Constants
static const CGFloat kACRCitationMoreDetailsButtonFontSize = 14.0;

// Layout Proportions
static const CGFloat kACRCitationLeftSideMaxWidthMultiplier = 0.5;

@interface ACRCitationReferenceView ()

// Main content horizontal stack view
@property (nonatomic, weak) UIStackView *mainContentStackView;

// Left side (pill + icon) horizontal stack view
@property (nonatomic, weak) UIStackView *leftSideStackView;
@property (nonatomic, weak) UIView *pillContainer;
@property (nonatomic, weak) UILabel *pillLabel;
@property (nonatomic, weak) UIImageView *iconImageView;

// Right side content vertical stack view
@property (nonatomic, weak) UIStackView *rightSideStackView;
@property (nonatomic, weak) UILabel *titleLabel;
@property (nonatomic, weak) UILabel *abstractLabel;

// Keywords label
@property (nonatomic, weak) UILabel *keywordsLabel;

// More details button
@property (nonatomic, weak) UIButton *moreDetailsButton;

@end

@implementation ACRCitationReferenceView

#pragma mark - Initialization

- (instancetype)initWithCitation:(ACOCitation *)citation reference:(ACOReference *)reference {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self setupUI];
        [self updateWithCitation:citation reference:reference];
    }
    return self;
}

#pragma mark - UI Setup

- (void)setupUI {
    self.backgroundColor = [UIColor systemBackgroundColor];
    
    // Create main content section
    UIStackView *mainContentStackView = [self setupMainContentSection];
    mainContentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:mainContentStackView];
    self.mainContentStackView = mainContentStackView;
    
    // Set up constraints
    [NSLayoutConstraint activateConstraints:@[
        [mainContentStackView.topAnchor constraintEqualToAnchor:self.topAnchor constant:kACRCitationViewSpacing],
        [mainContentStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kACRCitationViewSpacing],
        [mainContentStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-kACRCitationViewSpacing],
        [mainContentStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-kACRCitationViewSpacing]
    ]];
    
    [self setupContentConstraints];
}

// Main content horizontal stack view
- (UIStackView *)setupMainContentSection {
    UIStackView *mainContentStackView = [[UIStackView alloc] init];
    mainContentStackView.axis = UILayoutConstraintAxisHorizontal;
    mainContentStackView.spacing = kACRCitationViewSpacing;
    mainContentStackView.alignment = UIStackViewAlignmentTop;
    mainContentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Setup left side (pill + icon)
    UIStackView *leftSideStackView = [self setupLeftSideSection];
    [mainContentStackView addArrangedSubview:leftSideStackView];
    self.leftSideStackView = leftSideStackView;
    
    // Setup right side content
    UIStackView *rightSideStackView = [self setupRightSideSection];
    [mainContentStackView addArrangedSubview:rightSideStackView];
    self.rightSideStackView = rightSideStackView;
    
    return mainContentStackView;
}

// Left side horizontal stack view (pill + icon)
- (UIStackView *)setupLeftSideSection {
    UIStackView *leftSideStackView = [[UIStackView alloc] init];
    leftSideStackView.axis = UILayoutConstraintAxisHorizontal;
    leftSideStackView.spacing = kACRCitationViewSpacing;
    leftSideStackView.alignment = UIStackViewAlignmentCenter;
    
    // Pill label with border and padding
    UILabel *pillLabel = [[UILabel alloc] init];
    pillLabel.textAlignment = NSTextAlignmentCenter;
    pillLabel.font = [UIFont systemFontOfSize:kACRCitationPillFontSize weight:UIFontWeightMedium];
    pillLabel.textColor = [UIColor labelColor];
    pillLabel.numberOfLines = 0;
    pillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create a container view for the pill label to handle padding
    UIView *pillContainer = [[UIView alloc] init];
    pillContainer.translatesAutoresizingMaskIntoConstraints = NO;
    pillContainer.layer.borderColor = [UIColor separatorColor].CGColor;
    pillContainer.layer.borderWidth = kACRCitationPillBorderWidth;
    pillContainer.layer.cornerRadius = kACRCitationPillCornerRadius;
    pillContainer.layer.masksToBounds = YES;

    [pillContainer addSubview:pillLabel];
    
    [leftSideStackView addArrangedSubview:pillContainer];
    self.pillContainer = pillContainer;
    self.pillLabel = pillLabel;
    
    // Icon image view
    UIImageView *iconImageView = [[UIImageView alloc] init];
    iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [leftSideStackView addArrangedSubview:iconImageView];
    self.iconImageView = iconImageView;
    
    return leftSideStackView;
}

// Right side vertical stack view (title, keywords, abstract)
- (UIStackView *)setupRightSideSection {
    UIStackView *rightSideStackView = [[UIStackView alloc] init];
    rightSideStackView.axis = UILayoutConstraintAxisVertical;
    rightSideStackView.spacing = kACRCitationViewSpacing;
    rightSideStackView.alignment = UIStackViewAlignmentLeading;
    
    // Title label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [UIFont systemFontOfSize:kACRCitationTitleFontSize weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.numberOfLines = 0;
    [rightSideStackView addArrangedSubview:titleLabel];
    self.titleLabel = titleLabel;
    
    // Keywords label
    UILabel *keywordsLabel = [self setupKeywordsSection];
    [rightSideStackView addArrangedSubview:keywordsLabel];
    self.keywordsLabel = keywordsLabel;
    
    // Abstract label
    UILabel *abstractLabel = [[UILabel alloc] init];
    abstractLabel.font = [UIFont systemFontOfSize:kACRCitationAbstractFontSize weight:UIFontWeightRegular];
    abstractLabel.textColor = [UIColor grayColorWithValue:kACRCitationAbstractTextColor];
    abstractLabel.numberOfLines = 0;
    [rightSideStackView addArrangedSubview:abstractLabel];
    self.abstractLabel = abstractLabel;
    
    // More details button
    UIButton *moreDetailsButton = [self setupMoreDetailsButton];
    [rightSideStackView addArrangedSubview:moreDetailsButton];
    self.moreDetailsButton = moreDetailsButton;
    
    // Set content priorities
    [titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [abstractLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    return rightSideStackView;
}

// Keywords label with attributed string
- (UILabel *)setupKeywordsSection {
    UILabel *keywordsLabel = [[UILabel alloc] init];
    keywordsLabel.font = [UIFont systemFontOfSize:kACRCitationKeywordsFontSize weight:UIFontWeightRegular];
    keywordsLabel.textColor = [UIColor grayColorWithValue:kACRCitationKeywordsTextColor];
    keywordsLabel.numberOfLines = 0;
    return keywordsLabel;
}

// More details button setup
- (UIButton *)setupMoreDetailsButton {
    UIButton *moreDetailsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    
    // Create attributed string with "More details" text and chevron
    NSMutableAttributedString *buttonText = [[NSMutableAttributedString alloc] init];
    
    // "More details" text
    NSAttributedString *detailsText = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"More details ", nil)
                                                                      attributes:@{
        NSForegroundColorAttributeName: [UIColor systemBlueColor],
        NSFontAttributeName: [UIFont systemFontOfSize:kACRCitationMoreDetailsButtonFontSize weight:UIFontWeightRegular]
    }];
    [buttonText appendAttributedString:detailsText];
    
    // Chevron symbol
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:kACRCitationMoreDetailsButtonFontSize weight:UIFontWeightRegular];
    UIImage *chevronImage = [UIImage systemImageNamed:@"chevron.right" withConfiguration:config];
    chevronImage = [chevronImage imageWithTintColor:[UIColor systemBlueColor] renderingMode:UIImageRenderingModeAlwaysOriginal];

    NSTextAttachment *chevronAttachment = [[NSTextAttachment alloc] init];
    chevronAttachment.image = chevronImage;

    CGFloat offsetY = -2.0;
    chevronAttachment.bounds = CGRectMake(0, offsetY, chevronImage.size.width, chevronImage.size.height);

    NSAttributedString *chevron = [NSAttributedString attributedStringWithAttachment:chevronAttachment];

    [buttonText appendAttributedString:chevron];
    
    [moreDetailsButton setAttributedTitle:buttonText forState:UIControlStateNormal];
    moreDetailsButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    moreDetailsButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add target for button tap
    [moreDetailsButton addTarget:self 
                          action:@selector(moreDetailsButtonTapped:) 
                forControlEvents:UIControlEventTouchUpInside];
    
    return moreDetailsButton;
}

- (void)setupContentConstraints {
    // Content-specific constraints
    // Left side stack view width constraint
    [NSLayoutConstraint activateConstraints:@[
        [self.leftSideStackView.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor multiplier:kACRCitationLeftSideMaxWidthMultiplier]
    ]];
    
    // Pill container and label constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.pillContainer.widthAnchor constraintGreaterThanOrEqualToConstant:kACRCitationPillMinSize],
        [self.pillContainer.heightAnchor constraintGreaterThanOrEqualToConstant:kACRCitationPillMinSize],
        [self.pillContainer.widthAnchor constraintLessThanOrEqualToConstant:kACRCitationPillMaxWidth],
        [self.pillLabel.topAnchor constraintEqualToAnchor:self.pillContainer.topAnchor constant:kACRCitationPillTopBottomPadding],
        [self.pillLabel.bottomAnchor constraintEqualToAnchor:self.pillContainer.bottomAnchor constant:-kACRCitationPillTopBottomPadding],
        [self.pillLabel.leadingAnchor constraintEqualToAnchor:self.pillContainer.leadingAnchor constant:kACRCitationPillLeftRightPadding],
        [self.pillLabel.trailingAnchor constraintEqualToAnchor:self.pillContainer.trailingAnchor constant:-kACRCitationPillLeftRightPadding],
    ]];
    
    [self.pillLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    // Icon image view constraints with 1:1 aspect ratio
    [NSLayoutConstraint activateConstraints:@[
        [self.iconImageView.widthAnchor constraintEqualToConstant:kACRCitationIconSize],
        [self.iconImageView.heightAnchor constraintEqualToConstant:kACRCitationIconSize],
        [self.iconImageView.widthAnchor constraintEqualToAnchor:self.iconImageView.heightAnchor]
    ]];
    
    // Keywords label minimum height constraint
    [NSLayoutConstraint activateConstraints:@[
        [self.keywordsLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],
        [self.keywordsLabel.heightAnchor constraintGreaterThanOrEqualToConstant:kACRCitationKeywordsMinHeight]
    ]];
}

#pragma mark - Button Actions

- (void)moreDetailsButtonTapped:(UIButton *)sender {
    // Notify delegate about the more details button tap
    if (self.delegate && [self.delegate respondsToSelector:@selector(citationReferenceView:didTapMoreDetailsForCitation:reference:)]) {
        [self.delegate citationReferenceView:self 
                  didTapMoreDetailsForCitation:self.citation 
                                     reference:self.reference];
    }
}

#pragma mark - Public Methods

- (void)updateWithCitation:(ACOCitation *)citation reference:(ACOReference *)reference {
    self.citation = citation;
    self.reference = reference;
    
    // Update pill label with citation display text
    self.pillLabel.text = citation.displayText ?: @"";
    
    // Update title
    self.titleLabel.text = reference.title ?: @"";
    
    // Update keywords with separators
    [self updateKeywordsDisplay:reference.keywords];
    
    // Update abstract
    if (reference.abstract && reference.abstract.length > 0) {
        self.abstractLabel.text = reference.abstract;
        self.abstractLabel.hidden = NO;
    } else {
        self.abstractLabel.hidden = YES;
    }
    
    // Update icon
    [self updateIconForReference:reference];
    
    // Show/hide more details button based on URL availability or content availability
    self.moreDetailsButton.hidden = reference.content == nil;
}

- (void)updateKeywordsDisplay:(NSArray<NSString *> *)keywords {
    if (keywords && keywords.count > 0) {
        // Limit to max keywords as per spec
        NSInteger maxKeywords = MIN(keywords.count, kACRCitationMaxKeywords);
        NSArray *displayKeywords = [keywords subarrayWithRange:NSMakeRange(0, maxKeywords)];
        
        // Create attributed string with keywords separated by "|"
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
        
        for (NSInteger i = 0; i < displayKeywords.count; i++) {
            // Add separator if not first keyword
            if (i > 0) {
                // Setting hexcode: #E0E0E0 for separator
                NSAttributedString *separator = [[NSAttributedString alloc] initWithString:@"  |  "
                                                                                 attributes:@{
                    NSForegroundColorAttributeName: [UIColor grayColor],
                    NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
                }];
                [attributedString appendAttributedString:separator];
            }
            
            // Add keyword
            NSAttributedString *keyword = [[NSAttributedString alloc] initWithString:displayKeywords[i]
                                                                          attributes:@{
                NSForegroundColorAttributeName: [UIColor secondaryLabelColor],
                NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
            }];
            [attributedString appendAttributedString:keyword];
        }
        
        self.keywordsLabel.attributedText = attributedString;
        self.keywordsLabel.hidden = NO;
    } else {
        self.keywordsLabel.attributedText = nil;
        self.keywordsLabel.hidden = YES;
    }
}

- (void)updateIconForReference:(ACOReference *)reference
{
    self.iconImageView.image = [[reference iconForTheme:_citation.theme] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

@end
