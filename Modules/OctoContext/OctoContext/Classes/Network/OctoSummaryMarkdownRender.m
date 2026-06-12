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
    NSArray<NSTextCheckingResult *> *matches = [[re matchesInString:str.string options:0 range:NSMakeRange(0, str.length)] reverseObjectEnumerator].allObjects;
    for (NSTextCheckingResult *m in matches) {
        NSRange num = [m rangeAtIndex:1];
        if (num.location == NSNotFound) continue;
        NSInteger idx = [[str.string substringWithRange:num] integerValue];
        UIImage *badge = [OctoCitationBadgeView imageForBadgeText:[NSString stringWithFormat:@"%ld", (long)idx]
                                                            height:fontSize + 4];
        NSTextAttachment *att = [NSTextAttachment new];
        att.image = badge;
        att.bounds = CGRectMake(0, -2, badge.size.width, badge.size.height);
        NSAttributedString *attStr = [NSAttributedString attributedStringWithAttachment:att];
        NSMutableAttributedString *wrap = [attStr mutableCopy];
        [wrap addAttribute:OctoCitationIndexAttrKey value:@(idx) range:NSMakeRange(0, wrap.length)];
        [str replaceCharactersInRange:m.range withAttributedString:wrap];
    }
}

@end
