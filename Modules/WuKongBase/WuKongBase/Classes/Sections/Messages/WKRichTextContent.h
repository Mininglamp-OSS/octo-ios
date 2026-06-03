//
//  WKRichTextContent.h
//  WuKongBase
//
//  图文混排消息（RichText, ContentType=14）。
//  跨端契约见 octo-lib docs/richtext-blocks-contract.md：content 为有序 block
//  数组（text / image），数组顺序即图文穿插顺序；plain 为 server 生成的冗余纯
//  文本，供复制/搜索/摘要复用。Phase 1 只做接收渲染，发送端留 Phase 2。
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

@end

@interface WKRichTextContent : WKMessageContent

/// 有序 block 数组，顺序即图文穿插顺序。
@property(nonatomic,strong) NSArray<WKRichTextBlock*> *content;

/// 顶层冗余纯文本（server 生成）。复制/摘要走它。
@property(nonatomic,copy,nullable) NSString *plain;

@end

NS_ASSUME_NONNULL_END
