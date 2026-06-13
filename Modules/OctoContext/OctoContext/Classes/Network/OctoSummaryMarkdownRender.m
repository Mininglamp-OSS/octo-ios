//
//  OctoSummaryMarkdownRender.m
//  OctoContext
//

#import "OctoSummaryMarkdownRender.h"
#import "OctoCitationBadgeView.h"
#import <WuKongBase/WuKongBase.h>
#import <WuKongBase/WuKongBase-Swift.h>

@implementation OctoSummaryMarkdownRender

+ (NSAttributedString *)attributedFromContent:(NSString *)content
                                    citations:(NSArray<OctoCitationItem *> *)citations
                                     fontSize:(CGFloat)fontSize {
    if (content.length == 0) return [[NSAttributedString alloc] initWithString:@""];
    // LaTeX 预处理: 复用 WKLaTeXPreprocessor 把 $...$ / \(...\) / $$...$$ / \[...\]
    // 抽成占位符 + segments list, 与 message cell (WKTextMessageCell.m:687) 同口径。
    // 命中后用 pp.markdown (含占位符) 走下面的行内 markdown 渲染, 渲完再用
    // replaceMathPlaceholdersIn: 把占位符换成 WKMathImageRenderer 出的图片附件。
    // preprocess 抛异常时静默回退, 把原文当普通文本走, 不要让数学渲染把整段总结打废。
    NSString *workingContent = content;
    NSArray<WKLaTeXMathSegment *> *mathSegments = nil;
    if ([WKLaTeXPreprocessor containsLaTeX:content]) {
        @try {
            WKLaTeXPreprocessResult *pp = [WKLaTeXPreprocessor preprocess:content];
            if (pp.markdown.length > 0) {
                workingContent = pp.markdown;
                mathSegments = pp.mathSegments;
            }
        } @catch (NSException *e) {
            NSLog(@"[OctoSummaryMarkdownRender] LaTeX preprocess exception, fallback to raw: %@", e);
        }
    }

    NSMutableAttributedString *out = [NSMutableAttributedString new];
    NSArray<NSString *> *lines = [workingContent componentsSeparatedByString:@"\n"];
    UIColor *body = [UIColor labelColor];
    UIColor *muted = [UIColor.labelColor colorWithAlphaComponent:0.85];
    for (NSString *raw in lines) {
        NSString *line = raw;
        UIFont *font = [UIFont systemFontOfSize:fontSize];
        UIColor *color = body;
        BOOL bullet = NO;
        // 横线匹配 (commonmark spec): 整行只允许 -/*/_ 三种之一 + 可选空白, ≥3 个符号。
        // 之前用了 NSRegularExpression `^[-*_\s]*(?:[-*_]\s*){3,}$`, 字符类重叠会触发
        // 灾难性回溯; 服务端 AI 内容里偶发的 16k 字符 "- "*n 会让主线程冻结。改成线性扫
        // 一遍同时校验 "纯字符" 和 "≥3 个", 没有正则就没有 ReDoS 风险。
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        BOOL isHr = NO;
        if (trimmed.length >= 3) {
            unichar c0 = [trimmed characterAtIndex:0];
            if (c0 == '-' || c0 == '*' || c0 == '_') {
                BOOL pure = YES;
                NSUInteger symCount = 0;
                for (NSUInteger i = 0; i < trimmed.length; i++) {
                    unichar ci = [trimmed characterAtIndex:i];
                    if (ci == c0) { symCount++; }
                    else if (ci != ' ' && ci != '\t') { pure = NO; break; }
                }
                isHr = pure && symCount >= 3;
            }
        }
        if (isHr) {
            [out appendAttributedString:[self horizontalRuleAttributedString]];
            [out appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
            continue;
        }
        if ([line hasPrefix:@"### "]) {
            line = [line substringFromIndex:4];
            font = [UIFont systemFontOfSize:fontSize + 1 weight:UIFontWeightSemibold];
        } else if ([line hasPrefix:@"## "]) {
            line = [line substringFromIndex:3];
            font = [UIFont systemFontOfSize:fontSize + 3 weight:UIFontWeightSemibold];
        } else if ([line hasPrefix:@"# "]) {
            line = [line substringFromIndex:2];
            font = [UIFont systemFontOfSize:fontSize + 5 weight:UIFontWeightSemibold];
        } else if ([line hasPrefix:@"- "] || [line hasPrefix:@"* "]) {
            line = [@"• " stringByAppendingString:[line substringFromIndex:2]];
            color = muted;
            bullet = YES;
        } else {
            color = muted;
        }

        NSMutableAttributedString *lineAttr = [[NSMutableAttributedString alloc] initWithString:line attributes:@{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: color,
        }];
        // **bold**
        [self applyBoldRunsTo:lineAttr font:font];
        // [N] citation
        [self applyCitationsTo:lineAttr citations:citations fontSize:fontSize];

        [out appendAttributedString:lineAttr];
        [out appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        (void)bullet;
    }
    // 数学占位符 → 图片附件: 行内 markdown / 加粗 / citation 全跑完之后再做,
    // 这样占位符身上不会被 applyBoldRunsTo / applyCitationsTo 误命中 (它们的正则都是
    // 标点驱动的, 占位符是 PUA 私用区码点, 安全)。WKApp.config.style 决定深浅版字色。
    if (mathSegments.count > 0) {
        BOOL isDark = ([WKApp shared].config.style == WKSystemStyleDark);
        @try {
            [WKLaTeXPreprocessor replaceMathPlaceholdersIn:out
                                                  segments:mathSegments
                                                  fontSize:fontSize
                                                    isDark:isDark];
        } @catch (NSException *e) {
            NSLog(@"[OctoSummaryMarkdownRender] LaTeX replace exception, leaving placeholders: %@", e);
        }
    }
    NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
    para.lineSpacing = 4;
    para.paragraphSpacing = 4;
    [out addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, out.length)];
    return out;
}

/// 把 markdown 的 `---` / `***` / `___` 渲染成一条横线。
/// 实现: 1pt 高 / 屏幕宽减 32pt 边距的 UIImage 包进 NSTextAttachment;
///   - 颜色用 labelColor.alpha=0.18, 浅深色都自动适配 (虽然 UIImage 一次性 capture
///     时 trait 已经 resolve, 但总结正文不会在阅读过程中频繁切主题, 静态色可以接受;
///     若日后要双 trait 实时切, 可改用 UIImageAsset + dynamic provider)。
///   - bounds 留 -2 偏移让线高度居中, 视觉与上下文字行接近。
///   - 给 attachment 包一段 paragraphSpacing, 与上下行多撑 4pt 喘息。
+ (NSAttributedString *)horizontalRuleAttributedString {
    static NSAttributedString *cached;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGFloat w = MAX(120, UIScreen.mainScreen.bounds.size.width - 64);
        CGFloat h = 1.0;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(w, h)];
        UIImage *img = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
            [[[UIColor labelColor] colorWithAlphaComponent:0.18] setFill];
            CGContextFillRect(ctx.CGContext, CGRectMake(0, 0, w, h));
        }];
        NSTextAttachment *att = [NSTextAttachment new];
        att.image = img;
        // -6 让线整体往下蹭一点, 视觉上跟段落基线齐平; 上下还会有 paragraphSpacing 撑空。
        att.bounds = CGRectMake(0, -6, w, h);
        NSMutableAttributedString *attr = [[NSAttributedString attributedStringWithAttachment:att] mutableCopy];
        NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
        p.paragraphSpacingBefore = 6;
        p.paragraphSpacing = 6;
        [attr addAttribute:NSParagraphStyleAttributeName value:p range:NSMakeRange(0, attr.length)];
        cached = [attr copy];
    });
    return cached;
}

+ (void)applyBoldRunsTo:(NSMutableAttributedString *)str font:(UIFont *)baseFont {
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*([^*]+)\\*\\*" options:0 error:&err];
    if (!re) return;
    UIFont *boldFont = [UIFont systemFontOfSize:baseFont.pointSize weight:UIFontWeightSemibold];
    NSArray<NSTextCheckingResult *> *matches = [[re matchesInString:str.string options:0 range:NSMakeRange(0, str.length)] reverseObjectEnumerator].allObjects;
    for (NSTextCheckingResult *m in matches) {
        NSRange inner = [m rangeAtIndex:1];
        if (inner.location == NSNotFound) continue;
        NSString *boldText = [str.string substringWithRange:inner];
        NSMutableAttributedString *rep = [[NSMutableAttributedString alloc] initWithString:boldText attributes:@{
            NSFontAttributeName: boldFont,
            NSForegroundColorAttributeName: [UIColor labelColor],
        }];
        [str replaceCharactersInRange:m.range withAttributedString:rep];
    }
}

+ (void)applyCitationsTo:(NSMutableAttributedString *)str
               citations:(NSArray<OctoCitationItem *> *)citations
                fontSize:(CGFloat)fontSize {
    if (citations.count == 0) return;
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d+)\\]" options:0 error:&err];
    if (!re) return;
    NSArray<NSTextCheckingResult *> *matches = [re matchesInString:str.string options:0 range:NSMakeRange(0, str.length)];
    if (matches.count == 0) return;

    // 把"紧贴在一起"的 [N][M][...] 合成一组(中间无任何字符) —— 与 web CitationText.tsx
    // 的 isAdjacent 判断同源思路。每组只渲染一颗徽章, 文字按 count == 1 / 连续区间 / 离散
    // 三种格式: "1" / "1-3" / "1,3,5"。点击时把整组 indices 一并下放, sheet 一次性展示。
    NSMutableArray<NSDictionary *> *groups = [NSMutableArray array];
    NSRange curRange = NSMakeRange(NSNotFound, 0);
    NSMutableArray<NSNumber *> *curIdx = [NSMutableArray array];
    NSString *string = str.string;
    for (NSTextCheckingResult *m in matches) {
        NSRange numR = [m rangeAtIndex:1];
        if (numR.location == NSNotFound) continue;
        NSInteger n = [[string substringWithRange:numR] integerValue];
        if (curRange.location == NSNotFound) {
            curRange = m.range;
            [curIdx addObject:@(n)];
            continue;
        }
        NSUInteger prevEnd = curRange.location + curRange.length;
        if (m.range.location == prevEnd) {
            curRange.length = (m.range.location + m.range.length) - curRange.location;
            [curIdx addObject:@(n)];
        } else {
            [groups addObject:@{@"range": [NSValue valueWithRange:curRange], @"idx": [curIdx copy]}];
            curRange = m.range;
            curIdx = [@[@(n)] mutableCopy];
        }
    }
    if (curRange.location != NSNotFound) {
        [groups addObject:@{@"range": [NSValue valueWithRange:curRange], @"idx": [curIdx copy]}];
    }

    // 反向替换, 不破坏前面 group 的 range
    for (NSDictionary *g in [groups reverseObjectEnumerator]) {
        NSRange r = [g[@"range"] rangeValue];
        NSArray<NSNumber *> *indices = g[@"idx"];
        NSString *badgeText = [self badgeTextFromIndices:indices];
        UIImage *badge = [OctoCitationBadgeView imageForBadgeText:badgeText height:fontSize + 4];
        NSTextAttachment *att = [NSTextAttachment new];
        att.image = badge;
        att.bounds = CGRectMake(0, -2, badge.size.width, badge.size.height);
        NSAttributedString *attStr = [NSAttributedString attributedStringWithAttachment:att];
        NSMutableAttributedString *wrap = [attStr mutableCopy];
        // 单 idx 兼容老 key (legacy 路径仍能拿到首个 index); 新路径读 group key 拿全数组
        [wrap addAttribute:OctoCitationIndexAttrKey value:indices.firstObject range:NSMakeRange(0, wrap.length)];
        [wrap addAttribute:OctoCitationGroupAttrKey value:indices range:NSMakeRange(0, wrap.length)];
        [str replaceCharactersInRange:r withAttributedString:wrap];
    }
}

/// indices → 徽章文字: 1 个 "N"; 严格连续 "首-尾"; 否则逗号拼。
+ (NSString *)badgeTextFromIndices:(NSArray<NSNumber *> *)indices {
    if (indices.count == 0) return @"";
    if (indices.count == 1) return [indices.firstObject stringValue];
    BOOL consecutive = YES;
    for (NSInteger i = 1; i < indices.count; i++) {
        if (indices[i].integerValue != indices[i-1].integerValue + 1) {
            consecutive = NO; break;
        }
    }
    if (consecutive) {
        return [NSString stringWithFormat:@"%@-%@", indices.firstObject, indices.lastObject];
    }
    NSMutableArray *out = [NSMutableArray array];
    for (NSNumber *n in indices) [out addObject:[n stringValue]];
    return [out componentsJoinedByString:@","];
}

@end
