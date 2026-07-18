//
//  ACRBottomSheetViewController.mm
//  AdaptiveCards
//
//  Created by Jitisha Azad on 24/06/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACOHostConfigPrivate.h"
#import "ACRBottomSheetViewController.h"
#import "ACRBottomSheetPresentationController.h"
#import "ACRBottomSheetConfiguration.h"
#import "UtiliOS.h"
#import "UIColor+GrayColor.h"

@interface ACRBottomSheetViewController ()

@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, weak) UIButton *dismissButton;
@property (nonatomic, weak) UIView *dragIndicator;
@property (nonatomic, weak) UIView *headerSection;
@property (nonatomic, weak) UILabel *headerTitleLabel;
@property (nonatomic, weak) UIView *separatorView;
@property (nonatomic) UIView *contentView;
@property (nonatomic) ACRBottomSheetConfiguration *config;

@end

@implementation ACRBottomSheetViewController

- (instancetype)initWithContent:(UIView *)content
                  configuration:(ACRBottomSheetConfiguration *)config;

{
    if (self = [super init])
    {
        _contentView = content;
        _config = config;
        
        self.modalPresentationStyle = UIModalPresentationCustom;
        self.transitioningDelegate  = self;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [self.config.hostConfig getPopoverBackgroundColor];
    
    // Setup unified header view if we have header text OR dismiss button (excluding drag indicator)
    BOOL hasHeaderText = (self.config.headerText && self.config.headerText.length > 0);
    
    if (hasHeaderText || (self.config.dismissButtonType != ACRBottomSheetDismissButtonTypeNone)) {
        [self setupUnifiedHeaderView];
    }
    
    [self setupScrollView];
    [self setupConstraints];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (self.onDismissBlock)
    {
        self.onDismissBlock();
    }
}

- (void)setupUnifiedHeaderView
{
    // Header Constants
    static const CGFloat kACRCitationHeaderHeight = 50.0;
    static const CGFloat kACRCitationHeaderFontSize = 17.0;
    static const NSInteger kACRCitationHeaderTextColor = 32;
    static const CGFloat kACRCitationSeparatorHeight = 1.0;
    static const NSInteger kACRCitationSeparatorColor = 224;
    
    // Header section container
    UIView *headerSection = [[UIView alloc] init];
    headerSection.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:headerSection];
    self.headerSection = headerSection;
    
    // Setup header title if provided
    if (self.config.headerText && self.config.headerText.length > 0) {
        UILabel *headerTitleLabel = [[UILabel alloc] init];
        headerTitleLabel.text = self.config.headerText;
        headerTitleLabel.textAlignment = NSTextAlignmentCenter;
        headerTitleLabel.font = [UIFont systemFontOfSize:kACRCitationHeaderFontSize weight:UIFontWeightSemibold];
        
        // Gray color helper
        headerTitleLabel.textColor = [UIColor grayColorWithValue:kACRCitationHeaderTextColor];
        
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [headerSection addSubview:headerTitleLabel];
        self.headerTitleLabel = headerTitleLabel;
        
        // Center in the remaining space, accounting for button
        [NSLayoutConstraint activateConstraints:@[
            [headerTitleLabel.leadingAnchor constraintEqualToAnchor:headerSection.leadingAnchor],
            [headerTitleLabel.trailingAnchor constraintEqualToAnchor:headerSection.trailingAnchor],
            [headerTitleLabel.topAnchor constraintEqualToAnchor:headerSection.topAnchor],
            [headerTitleLabel.bottomAnchor constraintEqualToAnchor:headerSection.bottomAnchor],
        ]];
    }
    
    // Setup dismiss button if needed
    if ([self.config hasDismissButton]) {
        [self setupDismissButton];
    } else if (self.config.dismissButtonType == ACRBottomSheetDismissButtonTypeDragIndicator) {
        [self setupDragIndicator];
    }
    
    // Separator
    UIView *separatorView = [[UIView alloc] init];
    separatorView.backgroundColor = [UIColor grayColorWithValue:kACRCitationSeparatorColor];;
    separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:separatorView];
    
    // Header and separator constraints
    [NSLayoutConstraint activateConstraints:@[
        [headerSection.heightAnchor constraintEqualToConstant:kACRCitationHeaderHeight],
        [headerSection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [headerSection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        
        [separatorView.topAnchor constraintEqualToAnchor:headerSection.bottomAnchor constant: -1 * kACRCitationSeparatorHeight],
        [separatorView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [separatorView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [separatorView.heightAnchor constraintEqualToConstant:kACRCitationSeparatorHeight]
    ]];
}


- (void)setupDismissButton
{
    CGFloat buttonWidth = 16.0;
    NSString *systemIconName = (self.config.dismissButtonType == ACRBottomSheetDismissButtonTypeCross) ? @"xmark" : @"chevron.left";
    NSString *buttonIconA11yName = (self.config.dismissButtonType == ACRBottomSheetDismissButtonTypeCross) ? @"Dismiss" : @"Back";

    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    dismissButton.accessibilityLabel = NSLocalizedString(buttonIconA11yName, nil);
    
    // Use system image with configuration
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:buttonWidth weight:UIImageSymbolWeightRegular];
    UIImage *buttonIcon = [UIImage systemImageNamed:systemIconName withConfiguration:configuration];
    [dismissButton setImage:buttonIcon forState:UIControlStateNormal];
    
    // Set tint color from host config
    UIColor *tintColor = [self.config.hostConfig getPopoverTintColor];
    dismissButton.tintColor = tintColor;
    
    [dismissButton addTarget:self
                      action:@selector(closeAction)
            forControlEvents:UIControlEventTouchUpInside];
    dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.headerSection addSubview:dismissButton];
    self.dismissButton = dismissButton;
    
    [NSLayoutConstraint activateConstraints:@[
        [dismissButton.widthAnchor constraintEqualToConstant:32],
        [dismissButton.heightAnchor constraintEqualToConstant:32],
        [dismissButton.leadingAnchor constraintEqualToAnchor:self.headerSection.leadingAnchor constant:16.0],
        [dismissButton.centerYAnchor constraintEqualToAnchor:self.headerSection.centerYAnchor],
    ]];
}

- (void)setupDragIndicator
{
    UIView *dragIndicator = [[UIView alloc] init];
    dragIndicator.backgroundColor = [UIColor tertiaryLabelColor];
    dragIndicator.layer.cornerRadius = 2.0;
    dragIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:dragIndicator];
    self.dragIndicator = dragIndicator;
    
    // Only drag indicator is present
    [NSLayoutConstraint activateConstraints:@[
        [self.dragIndicator.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [self.dragIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dragIndicator.widthAnchor constraintEqualToConstant:36],
        [self.dragIndicator.heightAnchor constraintEqualToConstant:4],
    ]];
}

- (void)setupScrollView
{
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView = scrollView;
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    [self.contentView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
}

- (void)setupConstraints
{
    CGFloat contentPad = self.config.contentPadding;
    
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    
    // Determine the top anchor for scroll view based on what UI elements are present
    NSLayoutYAxisAnchor *scrollViewTopAnchor = self.view.topAnchor;;
    CGFloat scrollViewTopConstant = 0;
    
    if (self.headerSection) {
        // Unified header view is present (contains button and/or title)
        [constraints addObjectsFromArray:@[
            [self.headerSection.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8]
        ]];
        scrollViewTopAnchor = self.headerSection.bottomAnchor;
        scrollViewTopConstant = 0;
    } else if (self.config.dismissButtonType == ACRBottomSheetDismissButtonTypeDragIndicator) {
        scrollViewTopConstant = 20;
    } else {
        // No header or drag indicator - scroll view starts at top with padding
        scrollViewTopConstant = 8;
    }
    
    [constraints addObjectsFromArray:@[
        /* scroll container */
        [self.scrollView.topAnchor constraintEqualToAnchor:scrollViewTopAnchor constant:scrollViewTopConstant],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        
        /* content inside scroll */
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:contentPad],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:(-contentPad)],
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:(-2 * contentPad)],
    ]];
    
    // Common scroll view and content constraints
    [NSLayoutConstraint activateConstraints:constraints];
}

- (CGSize)preferredContentSize
{
    [self.view layoutIfNeeded];
    CGFloat header = CGRectGetMinY(self.scrollView.frame) + self.view.safeAreaInsets.bottom;
    CGFloat naturalHeight =  header + self.scrollView.contentSize.height;
    
    CGSize referenceWindowSize = self.config.referenceWindowSize;
    if (CGSizeEqualToSize(referenceWindowSize, CGSizeZero)) {
        referenceWindowSize = self.presentingViewController.view.bounds.size;
    }
    
    CGFloat maxH = self.config.maxHeightMultiplier * referenceWindowSize.height;
    CGFloat min = self.config.minHeight;
    
    if (min == NSNotFound) {
        min = self.config.minHeightMultiplier * referenceWindowSize.height;
    }
    
    CGFloat sheetH = MAX(min, MIN(naturalHeight, maxH));
    self.scrollView.scrollEnabled = naturalHeight > sheetH;
    self.scrollView.alwaysBounceVertical = self.scrollView.scrollEnabled;
    return CGSizeMake(referenceWindowSize.width, sheetH);
}

- (void)closeAction
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: Transition Delegate
- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented
                                                      presentingViewController:(UIViewController *)presenting
                                                          sourceViewController:(UIViewController *)source
{
    return [[ACRBottomSheetPresentationController alloc] initWithPresentedViewController:presented
                                                                presentingViewController:presenting];
}

@end
