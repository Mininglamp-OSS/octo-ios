// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMessageTextView.h
//  WuKongBase
//
//  UITextView 替代 UILabel 作为消息文本显示组件，天然支持文字选择。
//  默认 display-only 模式（等同 UILabel），长按时切换为 selectable。
//  保留与 UILabel+WK 相同的 tokens/matchDidTap 接口，兼容现有点击检测逻辑。
//

#import <UIKit/UIKit.h>
#import "WKMatchToken.h"

NS_ASSUME_NONNULL_BEGIN

/// 参考 Android SelectTextHelper CursorHandle：拖动句柄时隐藏菜单，松手后重显
@protocol WKSelectionTVDelegate <NSObject>
- (void)selectionTVTouchBegan;
- (void)selectionTVTouchEnded;
@end

@interface WKMessageTextView : UITextView

/// touch delegate：用于拖动句柄期间的菜单隐显控制
@property(nonatomic, weak, nullable) id<WKSelectionTVDelegate> selDelegate;

/// 与 UILabel+WK 同名属性：链接/mention token 列表，用于点击命中检测
@property(nonatomic, strong, nullable) NSArray<id<WKMatchToken>> *tokens;

/// 与 UILabel+WK 同名方法：通过点坐标查找命中的 token
/// UITextView 直接用自身 layoutManager，比 UILabel 的共享 UITextView 更准确
- (nullable id<WKMatchToken>)matchDidTapAttributedTextInLabelWithPoint:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
