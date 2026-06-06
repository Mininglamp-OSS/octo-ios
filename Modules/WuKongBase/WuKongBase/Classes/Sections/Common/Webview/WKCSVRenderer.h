//
//  WKCSVRenderer.h
//  WuKongBase
//
//  把 RFC4180 兼容的 CSV 文本渲染成一段可塞进 WKWebView 的 HTML 表格：
//  首行作表头并 sticky，行内容支持横向 + 纵向滚动，深色 / 浅色主题自适应。
//  从 WKWebViewVC 抽出，给文件预览（WKSafeFilePreviewVC）和网页预览共用。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKCSVRenderer : NSObject

/// 把 CSV 全文渲染成完整 HTML 文档。空内容会退化为占位空表（与 WKWebViewVC 老路径行为一致）。
+ (NSString *)htmlFromCSVText:(NSString *)csvText darkMode:(BOOL)isDark;

/// RFC4180-兼容的 CSV 解析。支持：引号包围字段（含字段内逗号/换行）、""转义引号、CRLF/LF 行尾。
/// 不处理 TSV / 分号分隔符等变种，保持职责单一。
+ (NSArray<NSArray<NSString *> *> *)parseCSV:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
