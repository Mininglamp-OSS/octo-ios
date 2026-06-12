//
//  OctoSummaryMarkdownRender.h
//  OctoContext
//
//  极简 markdown → NSAttributedString 渲染。对齐 web 端 CitationText 的输出形态:
//   - `[N]` / `[N][M]…` 连续相邻 → 紫色 badge (附 OctoCitationIndexAttrKey)
//   - 行首 `### / ## / #` → 加粗放大
//   - 行首 `- ` / `* ` → 圆点
//   - `**text**` → 加粗
//
//  不实现完整 markdown (代码块 / 表格 / 链接), 总结正文里基本只有标题 + 列表 + 引用,
//  这套规则覆盖度足够。PR8 视觉走查若发现不够, 可换 cmark 渲染再插 citation 替换。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryMarkdownRender : NSObject

+ (NSAttributedString *)attributedFromContent:(NSString *)content
                                    citations:(NSArray<OctoCitationItem *> *)citations
                                     fontSize:(CGFloat)fontSize;

@end

NS_ASSUME_NONNULL_END
