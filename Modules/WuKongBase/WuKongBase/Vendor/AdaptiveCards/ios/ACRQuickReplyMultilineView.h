//
//  ACRQuickReplyMultilineView
//  ACRQuickReplyMultilineView.h
//
//  Copyright © 2018 Microsoft. All rights reserved.
//

#import "ACRButton.h"
#import "ACRTextView.h"
#import <UIKit/UIKit.h>
@protocol ACRIQuickReply
- (ACRButton *)getButton;
@end

@interface ACRQuickReplyMultilineView : UIView <ACRIQuickReply>
@property (strong, nonatomic) UIView *contentView;
@property (weak, nonatomic) ACRTextView *textView;
@property (weak, nonatomic) UIView *spacing;
@property (weak, nonatomic) ACRButton *button;

@end
