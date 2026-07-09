//
//  WKChannelHistoryHighlighter.h
//  WuKongBase
//
//  搜索结果文本高亮工具。
//  - 优先解析服务端返回的 <mark>...</mark> 段落（与 web 同口径）
//  - 兜底：按关键词做大小写不敏感本地高亮
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistoryHighlighter : NSObject

/// 渲染 snippet（可能含 <mark>）为 NSAttributedString。
/// keyword: 兜底高亮关键词，当 snippet 不含 <mark> 时使用。
/// font: 基础字号；textColor: 基础颜色；highlightColor: 高亮色（一般主题紫色）。
+ (NSAttributedString *)attributedFromSnippet:(nullable NSString *)snippet
                                       keyword:(nullable NSString *)keyword
                                          font:(UIFont *)font
                                     textColor:(UIColor *)textColor
                                highlightColor:(UIColor *)highlightColor;

/// 渲染纯文本+关键词高亮（不解析 <mark>）。
+ (NSAttributedString *)attributedFromText:(nullable NSString *)text
                                    keyword:(nullable NSString *)keyword
                                       font:(UIFont *)font
                                  textColor:(UIColor *)textColor
                             highlightColor:(UIColor *)highlightColor;

/// 以关键词为中心截取上下文片段（与 WKGlobalSearchVM.snippetFromText 同口径）。
/// 关键词命中位置在中后部时, 居中截取并加 "..." 标识, 保证关键词附近内容可见。
/// 如果 snippet 已经包含服务端的 <mark> 高亮标签, 不应调用此方法 —— 直接走
/// attributedFromSnippet:keyword:font:textColor:highlightColor: 即可。
+ (NSString *)centerSnippet:(nullable NSString *)text
                     keyword:(nullable NSString *)keyword
                   maxLength:(NSInteger)maxLength;

/// 服务端 snippet 专用居中: 优先按第一个 <mark>...</mark> 的位置作为锚点(比按
/// 文本 keyword 搜索更准, 因为服务端可能做了词干/模糊匹配, 关键词字符串本身可能
/// 在 stripMark 后的纯文本里根本找不到)。找不到 <mark> 时降级为 keyword 文本搜索。
/// 返回值是已 stripMark 的纯文本, 前后按 maxLength 加 "..." 标识。
+ (NSString *)centerSnippetFromServerText:(nullable NSString *)serverText
                                    keyword:(nullable NSString *)keyword
                                  maxLength:(NSInteger)maxLength;

@end

NS_ASSUME_NONNULL_END
