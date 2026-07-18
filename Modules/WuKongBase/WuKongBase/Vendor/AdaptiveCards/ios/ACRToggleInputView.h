//
//  ACRInputToggleView.h
//  AdaptiveCards
//
//  Copyright © 2020 Microsoft. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ACRToggleInputView : UIView

@property (nonatomic, strong) UIStackView *contentview;
@property (nonatomic, weak) UILabel *title;
@property (nonatomic, weak) UISwitch *toggle;
@property UIColor *switchOffStateColor;

@end
