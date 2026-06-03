//
//  WKRichTextContent.m
//  WuKongBase
//

#import "WKRichTextContent.h"
#import "WuKongBase.h"

// 与 octo-lib 契约对齐的 block type 字符串常量。
static NSString *const kWKRichTextBlockText  = @"text";
static NSString *const kWKRichTextBlockImage = @"image";

// 发送侧 plain 生成时 image block 注入的占位符（wire token，与 octo-lib
// RichTextImagePlaceholder 对齐，**不可本地化**——上 wire 的 plain 须跨端一致）。
// 区别于接收侧 buildPlain 用的 LLang(@"[图片]")（那是本地 UI 显示，可随语言变）。
static NSString *const kWKRichTextImageWireToken = @"[图片]";

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
        block.size = [self integerFromValue:dict[@"size"]];
        block.name = [dict[@"name"] isKindOfClass:[NSString class]] ? dict[@"name"] : nil;
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
    // 发送侧序列化 content blocks + 本地 plain 占位（server #232 Finalize 重算覆盖）。
    // size/name 仅在有值时带上，避免往 wire 注入 0/空 字段污染与 octo-lib 权威 schema
    // 的 byte-match。SDK 会注入 type=14。
    NSMutableArray *contentArr = [NSMutableArray array];
    for (WKRichTextBlock *block in self.content) {
        if (block.type == WKRichTextBlockTypeImage) {
            NSMutableDictionary *img = [@{@"type": kWKRichTextBlockImage,
                                          @"url": block.url ?: @"",
                                          @"width": @(block.width),
                                          @"height": @(block.height)} mutableCopy];
            if (block.size > 0) {
                img[@"size"] = @(block.size);
            }
            if (block.name.length > 0) {
                img[@"name"] = block.name;
            }
            [contentArr addObject:img];
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

#pragma mark - 发送侧构造器

+ (WKRichTextBlock *)textBlock:(NSString *)text {
    WKRichTextBlock *block = [WKRichTextBlock new];
    block.type = WKRichTextBlockTypeText;
    block.text = text ?: @"";
    return block;
}

+ (WKRichTextBlock *)imageBlock:(NSString *)url
                          width:(NSInteger)width
                         height:(NSInteger)height
                           size:(NSInteger)size
                           name:(NSString *)name {
    WKRichTextBlock *block = [WKRichTextBlock new];
    block.type = WKRichTextBlockTypeImage;
    block.url = url;
    block.width = width;
    block.height = height;
    block.size = size;
    block.name = name;
    return block;
}

+ (instancetype)contentWithBlocks:(NSArray<WKRichTextBlock *> *)blocks {
    WKRichTextContent *content = [WKRichTextContent new];
    content.content = blocks ?: @[];
    // 本地填 plain 占位（image → [图片] wire token，非本地化），server #232 重算覆盖。
    content.plain = [content buildWirePlain];
    return content;
}

/// 发送侧 plain 生成：与 buildPlain 同遍历规则，但 image 注入**非本地化** wire token，
/// 保证上 wire 的 plain 跨端一致（接收侧 buildPlain 的本地化 [图片] 只用于本机显示）。
- (NSString *)buildWirePlain {
    NSMutableString *result = [NSMutableString string];
    for (WKRichTextBlock *block in self.content) {
        if (block.type == WKRichTextBlockTypeImage) {
            [result appendString:kWKRichTextImageWireToken];
        } else if (block.text.length > 0) {
            [result appendString:block.text];
        }
    }
    return result;
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
