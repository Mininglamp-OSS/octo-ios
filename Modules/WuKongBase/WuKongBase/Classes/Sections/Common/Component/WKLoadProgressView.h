// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
#pragma mark - LoadProgressView
@interface WKLoadProgressView : UIView {
    UIImageView *_maskView;
    UILabel *_progressLabel;
    UIActivityIndicatorView *_activity;
}
@property(nonatomic, assign) CGFloat maxProgress;
- (void)setProgress:(CGFloat)progress;
- (void)hiddenLabel:(BOOL)hidden;
- (void)stopAnimating;
@end
