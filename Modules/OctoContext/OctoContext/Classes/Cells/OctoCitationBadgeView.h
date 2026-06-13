//
//  OctoCitationBadgeView.h
//  OctoContext
//
//  正文中的紫色 [N] 引用徽章。在 UITextView 里通过 NSTextAttachment 嵌入
//  一个尺寸固定的方形/圆形 view, 用户点击时由 OctoSummaryDetailVC 拦截手势
//  调起关联聊天记录 sheet。
//
//  约定: NSAttributedString 的 OctoCitationIndexAttrKey 属性记录被点击的
//  citation.index (NSNumber), OctoCitationGroupAttrKey 记录连续聚合的索引数组
//  (NSArray<NSNumber*>) —— 完全对齐 web 端 CitationContext / CitationBadge 的数据流。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSAttributedStringKey const OctoCitationIndexAttrKey;
extern NSAttributedStringKey const OctoCitationGroupAttrKey;

@interface OctoCitationBadgeView : UIView

/// 渲染单条 citation index 的文本徽章 (如 "1" / "2,3")。文字会自动撑出尺寸。
+ (UIImage *)imageForBadgeText:(NSString *)text height:(CGFloat)h;

@end

NS_ASSUME_NONNULL_END
