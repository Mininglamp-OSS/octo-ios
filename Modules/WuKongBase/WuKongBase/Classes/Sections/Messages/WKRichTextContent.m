//
//  WKRichTextContent.m
//  WuKongBase
//

#import "WKRichTextContent.h"
#import "WuKongBase.h"

// 与 octo-lib 契约对齐的 block type 字符串常量。
static NSString *const kWKRichTextBlockText  = @"text";
static NSString *const kWKRichTextBlockImage = @"image";

@implementation WKRichTextBlock
@end

@implementation WKRichTextContent

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    self.plain = [contentDic[@"plain"] isKindOfClass:[NSString class]] ? contentDic[@"plain"] : nil;

    id rawContent = contentDic[@"content"];
    NSMutableArray<WKRichTextBlock*> *blocks = [NSMutableArray array];

    if ([rawContent isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray*)rawContent) {
            if (![item isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            WKRichTextBlock *block = [self blockFromDict:(NSDictionary*)item];
            if (block) {
                [blocks addObject:block];
            }
        }
    } else if ([rawContent isKindOfClass:[NSString class]]) {
        // 向后兼容：老版本 content 是纯字符串，包成单个 text block。
        NSString *s = (NSString*)rawContent;
        WKRichTextBlock *block = [WKRichTextBlock new];
        block.type = WKRichTextBlockTypeText;
        block.text = s;
        [blocks addObject:block];
        if (self.plain.length == 0) {
            self.plain = s;
        }
    }

    self.content = blocks;

    // plain 缺失时（如老数据）现场遍历 content 兜底，保证复制/摘要不丢字。
    if (self.plain.length == 0) {
        self.plain = [self buildPlain];
    }
}

- (nullable WKRichTextBlock*)blockFromDict:(NSDictionary*)dict {
    NSString *typeStr = [dict[@"type"] isKindOfClass:[NSString class]] ? dict[@"type"] : nil;
    WKRichTextBlock *block = [WKRichTextBlock new];
    if ([typeStr isEqualToString:kWKRichTextBlockText]) {
        block.type = WKRichTextBlockTypeText;
        block.text = [dict[@"text"] isKindOfClass:[NSString class]] ? dict[@"text"] : @"";
        return block;
    }
    if ([typeStr isEqualToString:kWKRichTextBlockImage]) {
        block.type = WKRichTextBlockTypeImage;
        block.url = [dict[@"url"] isKindOfClass:[NSString class]] ? dict[@"url"] : nil;
        block.width = [self integerFromValue:dict[@"width"]];
        block.height = [self integerFromValue:dict[@"height"]];
        return block;
    }
    // read-lenient（契约 §5.4 Postel）：未知 type 不崩，有 text 字段降级取文本。
    if ([dict[@"text"] isKindOfClass:[NSString class]]) {
        block.type = WKRichTextBlockTypeText;
        block.text = dict[@"text"];
        return block;
    }
    return nil;
}

/// 安全取整：仅 NSNumber / NSString 走 integerValue，其它（NSNull 等）返回 0，
/// 避免对非数值类型发 integerValue 崩溃。
- (NSInteger)integerFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
        return [value integerValue];
    }
    return 0;
}

/// 遍历 content 生成纯文本：text 取 text，image 注入本地化占位符。
- (NSString*)buildPlain {
    NSMutableString *result = [NSMutableString string];
    NSString *imagePlaceholder = LLang(@"[图片]");
    for (WKRichTextBlock *block in self.content) {
        if (block.type == WKRichTextBlockTypeImage) {
            [result appendString:imagePlaceholder];
        } else if (block.text.length > 0) {
            [result appendString:block.text];
        }
    }
    return result;
}

- (NSDictionary *)encodeWithJSON {
    // Phase 1 只做接收渲染，发送端留 Phase 2。回写仅用于本地缓存一致性。
    NSMutableArray *contentArr = [NSMutableArray array];
    for (WKRichTextBlock *block in self.content) {
        if (block.type == WKRichTextBlockTypeImage) {
            [contentArr addObject:@{@"type": kWKRichTextBlockImage,
                                    @"url": block.url ?: @"",
                                    @"width": @(block.width),
                                    @"height": @(block.height)}];
        } else if (block.type == WKRichTextBlockTypeText) {
            [contentArr addObject:@{@"type": kWKRichTextBlockText,
                                    @"text": block.text ?: @""}];
        }
    }
    return @{@"content": contentArr, @"plain": self.plain ?: @""};
}

+(NSNumber*) contentType {
    return @(WK_RICHTEXT);
}

- (NSString *)conversationDigest {
    if (self.plain.length > 0) {
        return self.plain;
    }
    NSString *plain = [self buildPlain];
    if (plain.length > 0) {
        return plain;
    }
    return LLang(@"[富文本消息]");
}

- (NSString *)searchableWord {
    return self.plain ?: [self buildPlain];
}

@end
