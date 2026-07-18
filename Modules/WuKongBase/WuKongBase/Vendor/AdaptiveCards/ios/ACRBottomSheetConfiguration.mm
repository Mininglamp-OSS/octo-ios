//
//  ACRBottomSheetConfiguration.mm
//  AdaptiveCards
//
//  Created by Jitisha Azad on 24/06/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRBottomSheetConfiguration.h"

#pragma mark - Constants

/// Default minimum height multiplier for bottom sheet
static const CGFloat kDefaultMinHeightMultiplier = 0.2f;

/// Default maximum height multiplier for bottom sheet
static const CGFloat kDefaultMaxHeightMultiplier = 0.66f;

/// Default border height for the top indicator
static const CGFloat kDefaultBorderHeight = 0.5f;

/// Default insets for the close button (top, left, bottom=gap to content, right)
static const UIEdgeInsets kDefaultCloseButtonInsets = {16.0f, 12.0f, 20.0f, 12.0f};

/// Default content padding
static const CGFloat kDefaultContentPadding = 16.0f;

/// Default close button size
static const CGFloat kDefaultCloseButtonSize = 28.0f;

@implementation ACRBottomSheetConfiguration

#pragma mark - Initialization

- (instancetype)initWithHostConfig:(ACOHostConfig *)hostConfig
{
    NSParameterAssert(hostConfig != nil);
    
    self = [super init];
    if (self) {
        _hostConfig = hostConfig;
        _minHeightMultiplier = kDefaultMinHeightMultiplier;
        _maxHeightMultiplier = kDefaultMaxHeightMultiplier;
        _borderHeight = kDefaultBorderHeight;
        _contentPadding = kDefaultContentPadding;
        _closeButtonSize = kDefaultCloseButtonSize;
        _dismissButtonType = ACRBottomSheetDismissButtonTypeCross; // Default to cross button
        _closeButtonInsets = kDefaultCloseButtonInsets; // Default insets
        _headerText = nil; // No header by default
        _referenceWindowSize = CGSizeZero;
        _minHeight = NSNotFound; // Default to using multiplier-based height
    }
    return self;
}
#pragma mark - computed props

- (BOOL) hasDismissButton
{
    return self.dismissButtonType == ACRBottomSheetDismissButtonTypeCross ||
    self.dismissButtonType == ACRBottomSheetDismissButtonTypeBack;
}
#pragma mark - Property Validation

- (void)setMinHeightMultiplier:(CGFloat)minHeightMultiplier
{
    // Clamp value between 0.0 and 1.0
    CGFloat clampedValue = MAX(0.0f, MIN(1.0f, minHeightMultiplier));
    
    // Ensure it doesn't exceed maxHeightMultiplier
    _minHeightMultiplier = MIN(clampedValue, self.maxHeightMultiplier);
}

- (void)setMaxHeightMultiplier:(CGFloat)maxHeightMultiplier
{
    // Clamp value between 0.0 and 1.0
    CGFloat clampedValue = MAX(0.0f, MIN(1.0f, maxHeightMultiplier));
    
    // Ensure it's at least as large as minHeightMultiplier
    _maxHeightMultiplier = MAX(clampedValue, self.minHeightMultiplier);
}

- (void)setBorderHeight:(CGFloat)borderHeight
{
    // Clamp to non-negative value
    _borderHeight = MAX(0.0f, borderHeight);
}

- (void)setContentPadding:(CGFloat)contentPadding
{
    // Clamp to non-negative value
    _contentPadding = MAX(0.0f, contentPadding);
}

- (void)setCloseButtonSize:(CGFloat)closeButtonSize
{
    // Clamp to minimum size of 1.0 (must be positive)
    _closeButtonSize = MAX(17.0f, closeButtonSize);
}

#pragma mark - Description

- (NSString *)description
{
    NSString *dismissButtonTypeString = @"Unknown";
    switch (self.dismissButtonType) {
        case ACRBottomSheetDismissButtonTypeNone:
            dismissButtonTypeString = @"None";
            break;
        case ACRBottomSheetDismissButtonTypeCross:
            dismissButtonTypeString = @"Cross";
            break;
        case ACRBottomSheetDismissButtonTypeDragIndicator:
            dismissButtonTypeString = @"DragIndicator";
            break;
        case ACRBottomSheetDismissButtonTypeBack:
            dismissButtonTypeString = @"Back button";
            break;
    }
    
    return [NSString stringWithFormat:@"<%@: %p; minHeight: %.2f; maxHeight: %.2f; closeButtonInsets: {%.1f,%.1f,%.1f,%.1f}; dismissButtonType: %@>",
            NSStringFromClass([self class]), self, 
            self.minHeightMultiplier, self.maxHeightMultiplier,
            self.closeButtonInsets.top, self.closeButtonInsets.left, 
            self.closeButtonInsets.bottom, self.closeButtonInsets.right,
            dismissButtonTypeString];
}

@end
