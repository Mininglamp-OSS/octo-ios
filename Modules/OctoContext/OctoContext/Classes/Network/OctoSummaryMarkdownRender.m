//
//  OctoSummaryMarkdownRender.m
//  OctoContext
//

#import "OctoSummaryMarkdownRender.h"
#import "OctoCitationBadgeView.h"

@implementation OctoSummaryMarkdownRender

+ (NSAttributedString *)attributedFromContent:(NSString *)content
                                    citations:(NSArray<OctoCitationItem *> *)citations
                                     fontSize:(CGFloat)fontSize {
    if (content.length == 0) return [[NSAttributedString alloc] initWithString:@""];
    NSMutableAttributedString *out = [NSMutableAttributedString new];
    NSArray<NSString *> *lines = [content componentsSeparatedByString:@"\n"];
    UIColor *body = [UIColor labelColor];
    UIColor *muted = [UIColor.labelColor colorWithAlphaComponent:0.85];
    for (NSString *raw in lines) {
        NSString *line = raw;
        UIFont *font = [UIFont systemFontOfSize:fontSize];
        UIColor *color = body;
        BOOL bullet = NO;
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
    NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
    para.lineSpacing = 4;
    para.paragraphSpacing = 4;
    [out addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, out.length)];
    return out;
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
