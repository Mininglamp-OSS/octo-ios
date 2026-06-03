//
//  WKRichTextCell.h
//  WuKongBase
//
//  RichText(=14) 图文混排接收渲染 cell。文本走 appendText，图片走
//  appendRemoteImage（WKRemoteImageAttachment→NSTextAttachment），按 blocks
//  顺序内联穿插。Phase 1 只做接收渲染。
//

#import "WKMessageCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKRichTextCell : WKMessageCell

@end

NS_ASSUME_NONNULL_END
