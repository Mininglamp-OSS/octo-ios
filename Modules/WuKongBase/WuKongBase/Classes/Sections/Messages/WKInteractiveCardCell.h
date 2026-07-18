//
//  WKInteractiveCardCell.h
//  WuKongBase
//
//  互动卡片（Adaptive Cards）消息 Cell。ContentType = 17。
//
#import "WKMessageCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKInteractiveCardCell : WKMessageCell

/// 卡片内是否有正在编辑(第一响应者)的文本/日期/时间输入框。
/// 供聊天列表判断：点击时若卡片输入框在编辑，则不因触摸而收起键盘。
- (BOOL)wk_hasFocusedCardInput;

@end

NS_ASSUME_NONNULL_END
