//
//  WKRichTextCell.h
//  WuKongBase
//
//  RichText(=14) 图文混排接收渲染 cell。文本走 appendText，图片走
//  appendRemoteImage（WKRemoteImageAttachment→NSTextAttachment），按 blocks
//  顺序内联穿插。Phase 1 只做接收渲染。
//

#import "WKMessageCell.h"

@class WKMessageModel;

NS_ASSUME_NONNULL_BEGIN

@interface WKRichTextCell : WKMessageCell

/// 把 RichText(=14) 的 blocks 构建成含内联图片（WKRemoteImageAttachment）的 attributed
/// string，供无气泡场景（如合并转发详情）复用同一份图文穿插逻辑。textColor/mentionColor
/// 由调用方指定（合并详情传 defaultTextColor/themeColor，避免复用聊天页 isSend 分支时
/// 发送方消息拿到白字在白底看不见）。truncated 可传 NULL。
+ (NSMutableAttributedString *)attributedStringForMessage:(WKMessageModel *)model
                                                textColor:(UIColor *)textColor
                                             mentionColor:(UIColor *)mentionColor
                                                truncated:(nullable BOOL *)truncated;

@end

NS_ASSUME_NONNULL_END
