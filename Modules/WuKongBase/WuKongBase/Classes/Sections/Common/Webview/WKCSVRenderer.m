//
//  WKCSVRenderer.m
//  WuKongBase
//

#import "WKCSVRenderer.h"

@implementation WKCSVRenderer

+ (NSString *)htmlFromCSVText:(NSString *)csvText darkMode:(BOOL)isDark {
    NSArray<NSArray<NSString *> *> *rows = [self parseCSV:csvText];

    NSString *bg = isDark ? @"#1c1c1e" : @"#fff";
    NSString *fg = isDark ? @"#e5e5e7" : @"#333";
    NSString *border = isDark ? @"#3a3a3c" : @"#e5e5e7";
    NSString *headerBg = isDark ? @"#2c2c2e" : @"#f5f5f7";
    NSString *altBg = isDark ? @"#242426" : @"#fafafa";
    NSString *muted = isDark ? @"#7a7a80" : @"#a0a0a8";
    NSString *activeBg = isDark ? @"rgba(255,255,255,0.06)" : @"rgba(0,0,0,0.04)";

    NSUInteger maxCols = 0;
    for (NSArray *r in rows) if (r.count > maxCols) maxCols = r.count;

    // 行号列宽度按总行数位数选档, tabular-nums 下 14px 字号每数字约 8px
    NSUInteger dataRowCount = rows.count > 0 ? rows.count - 1 : 0;
    NSUInteger digits = 1;
    NSUInteger n = dataRowCount; while (n >= 10) { n /= 10; digits++; }
    NSUInteger rnWidth = MAX((NSUInteger)40, 16 + digits * 9); // 内边距 16 + 数字宽

    NSMutableString *html = [NSMutableString stringWithCapacity:MAX(rows.count, (NSUInteger)1) * 64];
    [html appendFormat:
        @"<html><head><meta charset='utf-8'>"
        @"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<style>"
        // 关回弹: 内外两层都关 overscroll, body 不滚动只让 .wrap 滚 (iOS 16+ 生效)
        @"html,body{margin:0;padding:0;height:100%%;overflow:hidden;overscroll-behavior:none;"
        @"background:%@;color:%@;font-family:-apple-system,system-ui;font-size:14px;"
        @"-webkit-font-smoothing:antialiased}"
        @".wrap{height:100%%;overflow:auto;-webkit-overflow-scrolling:touch;"
        @"overscroll-behavior:none;touch-action:pan-x pan-y}"
        // border-collapse:separate 才能让 sticky 列的背景盖住相邻边线
        @"table{border-collapse:separate;border-spacing:0;width:max-content;min-width:100%%;line-height:1.4}"
        @"th,td{padding:10px 14px;border-right:1px solid %@;border-bottom:1px solid %@;"
        @"white-space:nowrap;vertical-align:top;text-align:left;max-width:480px;"
        @"overflow:hidden;text-overflow:ellipsis;background:%@}"
        @"th{background:%@;font-weight:600;position:sticky;top:0;z-index:2}"
        @"tbody tr:nth-child(even) td{background:%@}"
        @"td{user-select:text;-webkit-user-select:text}"
        // 行号列 (sticky 在左, 不参与斑马, 字色弱化)
        // z-index:1 让 sticky 列盖住同行后续普通 td (普通 td z-index:auto=0)
        @"th.rn,td.rn{position:sticky;left:0;z-index:1;width:%lupx;min-width:%lupx;max-width:%lupx;"
        @"text-align:right;color:%@;font-variant-numeric:tabular-nums;"
        @"user-select:none;-webkit-user-select:none;background:%@}"
        @"thead th.rn{z-index:3}" // sticky 行(z:2) + sticky 列(z:1) 交叉处必须最上
        @"tbody tr:nth-child(even) td.rn{background:%@}" // 覆盖斑马底色
        // 移动端用 :active 代替 hover, 点行短促高亮以辅助阅读
        @"tbody tr:active td{background:%@}"
        @"tbody tr:active td.rn{background:%@}"
        @"</style></head><body><div class='wrap'><table>",
        bg, fg,
        border, border, bg,
        headerBg,
        altBg,
        (unsigned long)rnWidth, (unsigned long)rnWidth, (unsigned long)rnWidth, muted, headerBg,
        headerBg,
        activeBg, activeBg];

    if (rows.count == 0) {
        [html appendString:@"</table></div></body></html>"];
        return html;
    }

    NSArray<NSString *> *header = rows.firstObject;
    [html appendString:@"<thead><tr><th class='rn'>#</th>"];
    for (NSUInteger i = 0; i < maxCols; i++) {
        NSString *cell = i < header.count ? header[i] : @"";
        [html appendFormat:@"<th>%@</th>", [self escapeHTML:cell]];
    }
    [html appendString:@"</tr></thead><tbody>"];

    for (NSUInteger r = 1; r < rows.count; r++) {
        NSArray<NSString *> *row = rows[r];
        [html appendFormat:@"<tr><td class='rn'>%lu</td>", (unsigned long)r];
        for (NSUInteger i = 0; i < maxCols; i++) {
            NSString *cell = i < row.count ? row[i] : @"";
            [html appendFormat:@"<td>%@</td>", [self escapeHTML:cell]];
        }
        [html appendString:@"</tr>"];
    }
    [html appendString:@"</tbody></table></div></body></html>"];
    return html;
}

+ (NSArray<NSArray<NSString *> *> *)parseCSV:(NSString *)text {
    if (text.length == 0) return @[];
    NSMutableArray<NSArray<NSString *> *> *rows = [NSMutableArray array];
    NSMutableArray<NSString *> *row = [NSMutableArray array];
    NSMutableString *field = [NSMutableString string];
    BOOL inQuotes = NO;
    NSUInteger len = text.length;

    // 一次性把 UTF-16 unit 拷到 buffer，避免逐字符 characterAtIndex: 的开销
    unichar *buf = (unichar *)malloc(sizeof(unichar) * len);
    if (!buf) return @[];
    [text getCharacters:buf range:NSMakeRange(0, len)];

    void (^commitField)(void) = ^{
        [row addObject:[field copy]];
        [field setString:@""];
    };
    void (^commitRow)(void) = ^{
        // 跳过完全空白行（只有一个空 field 的情况）
        if (!(row.count == 1 && [row[0] length] == 0)) {
            [rows addObject:[row copy]];
        }
        [row removeAllObjects];
    };

    for (NSUInteger i = 0; i < len; i++) {
        unichar c = buf[i];
        if (inQuotes) {
            if (c == '"') {
                if (i + 1 < len && buf[i + 1] == '"') {
                    [field appendString:@"\""];
                    i++;
                } else {
                    inQuotes = NO;
                }
            } else {
                [field appendFormat:@"%C", c];
            }
        } else {
            if (c == '"') {
                inQuotes = YES;
            } else if (c == ',') {
                commitField();
            } else if (c == '\r' || c == '\n') {
                if (c == '\r' && i + 1 < len && buf[i + 1] == '\n') i++;
                commitField();
                commitRow();
            } else {
                [field appendFormat:@"%C", c];
            }
        }
    }
    // 最后没有换行结尾时收尾
    if (field.length > 0 || row.count > 0) {
        commitField();
        commitRow();
    }
    free(buf);
    return rows;
}

+ (NSString *)escapeHTML:(NSString *)s {
    if (s.length == 0) return @"";
    NSMutableString *m = [s mutableCopy];
    [m replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, m.length)];
    return m;
}

@end
