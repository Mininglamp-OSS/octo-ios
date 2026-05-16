// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMultipleSelectToHereButton.h
//  WuKongBase
//
//  多选模式下，当起始 anchor 已滚出屏幕时悬浮在顶部/底部的"选到这里"按钮。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKMultipleSelectToHerePosition) {
    WKMultipleSelectToHerePositionTop,
    WKMultipleSelectToHerePositionBottom,
};

@interface WKMultipleSelectToHereButton : UIControl

@property(nonatomic,assign,readonly) WKMultipleSelectToHerePosition position;

@property(nonatomic,assign,readonly,getter=isShowing) BOOL showing;

- (instancetype)initWithPosition:(WKMultipleSelectToHerePosition)position;

- (void)showAnimated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
