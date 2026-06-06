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

    NSUInteger maxCols = 0;
    for (NSArray *r in rows) if (r.count > maxCols) maxCols = r.count;

    NSMutableString *html = [NSMutableString stringWithCapacity:MAX(rows.count, (NSUInteger)1) * 64];
    [html appendFormat:
        @"<html><head><meta charset='utf-8'>"
        @"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<style>"
        @"html,body{margin:0;padding:0;height:100%%;background:%@;color:%@;"
        @"font-family:-apple-system,system-ui;font-size:14px}"
        @".wrap{overflow:auto;-webkit-overflow-scrolling:touch;height:100%%}"
        @"table{border-collapse:collapse;width:max-content;min-width:100%%}"
        @"th,td{padding:8px 12px;border:1px solid %@;white-space:nowrap;"
        @"vertical-align:top;text-align:left;max-width:480px;overflow:hidden;text-overflow:ellipsis}"
        @"th{background:%@;font-weight:600;position:sticky;top:0;z-index:1}"
        @"tbody tr:nth-child(even){background:%@}"
        @"td{user-select:text;-webkit-user-select:text}"
        @"</style></head><body><div class='wrap'><table>",
        bg, fg, border, headerBg, altBg];

    if (rows.count == 0) {
        [html appendString:@"</table></div></body></html>"];
        return html;
    }

    NSArray<NSString *> *header = rows.firstObject;
    [html appendString:@"<thead><tr>"];
    for (NSUInteger i = 0; i < maxCols; i++) {
        NSString *cell = i < header.count ? header[i] : @"";
        [html appendFormat:@"<th>%@</th>", [self escapeHTML:cell]];
    }
    [html appendString:@"</tr></thead><tbody>"];

    for (NSUInteger r = 1; r < rows.count; r++) {
        NSArray<NSString *> *row = rows[r];
        [html appendString:@"<tr>"];
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
