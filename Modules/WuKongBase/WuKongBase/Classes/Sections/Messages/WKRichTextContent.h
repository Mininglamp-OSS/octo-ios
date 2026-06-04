//
//  WKRichTextContent.h
//  WuKongBase
//
//  图文混排消息（RichText, ContentType=14）。
//  跨端契约见 octo-lib docs/richtext-blocks-contract.md：content 为有序 block
//  数组（text / image），数组顺序即图文穿插顺序；plain 为 server 生成的冗余纯
//  文本，供复制/搜索/摘要复用。Phase 1：接收渲染 + 发送构造共用同一份 schema。
//

#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

/// 单个 block 类型（与 octo-lib RichTextBlockText/Image 对齐）。
typedef NS_ENUM(NSUInteger, WKRichTextBlockType) {
    WKRichTextBlockTypeUnknown = 0,
    WKRichTextBlockTypeText,   // "text"
    WKRichTextBlockTypeImage,  // "image"
};

/// content 数组中的单个元素。
@interface WKRichTextBlock : NSObject

@property(nonatomic,assign) WKRichTextBlockType type;

// text block
@property(nonatomic,copy,nullable) NSString *text;

// image block
@property(nonatomic,copy,nullable) NSString *url;
@property(nonatomic,assign) NSInteger width;
@property(nonatomic,assign) NSInteger height;
/// 图片字节大小（可选，仅 >0 时序列化进 wire）。
@property(nonatomic,assign) NSInteger size;
/// 原始文件名（可选，仅非空时序列化进 wire）。
@property(nonatomic,copy,nullable) NSString *name;

@end

@interface WKRichTextContent : WKMessageContent

/// 有序 block 数组，顺序即图文穿插顺序。
@property(nonatomic,strong) NSArray<WKRichTextBlock*> *content;

/// 顶层冗余纯文本（server 生成）。复制/摘要走它。
@property(nonatomic,copy,nullable) NSString *plain;

#pragma mark - 发送侧构造器（与接收侧 decode 共用同一份 schema）

/// 构造一个 text block。
+ (WKRichTextBlock *)textBlock:(NSString *)text;

/// 构造一个 image block。url/width/height 为契约必填（width/height 须 >0，供端
/// 上占位排版）；size/name 仅在有值时序列化进 wire，避免注入 0/空字段污染 byte-match。
+ (WKRichTextBlock *)imageBlock:(NSString *)url
                          width:(NSInteger)width
                         height:(NSInteger)height
                           size:(NSInteger)size
                           name:(nullable NSString *)name;

/// 构造一条可发送的 RichText(=14) 正文。plain 本地填非本地化占位（image →
/// [图片] wire token），仅用于本地回显 / 离线兜底；server #232 Finalize 会重算覆盖。
+ (instancetype)contentWithBlocks:(NSArray<WKRichTextBlock *> *)blocks;

@end

NS_ASSUME_NONNULL_END
