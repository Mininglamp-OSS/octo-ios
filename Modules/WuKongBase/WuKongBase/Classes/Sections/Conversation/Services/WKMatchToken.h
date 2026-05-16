//
//  WKMatchToken.h
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKatchTokenTypeText, // 普通文本
    WKatchTokenTypeLink, // 普通链接
    WKatchTokenTypeMetion, // @
    WKatchTokenTypeEmoji, // emoji
    WKatchTokenTypeLink2, // 文本链接 必入 (百度)[http://baidu.com] // 显示为 百度
    WKatchTokenTypeBold, // 加粗
    WKatchTokenTypeRemoteImage, // 远程图片
    WKatchTokenTypeColor, // 颜色
    WKatchTokenTypeUnderline, // 下划线
    WKatchTokenTypeItalic, // 斜体
    WKatchTokenTypeStrikethrough, // 中划线
    WKatchTokenTypeFont, // 字体
    WKatchTokenTypeInlineCode, // 行内代码
    WKatchTokenTypeHeading, // 标题
    WKatchTokenTypeCodeBlock, // 代码块
    WKatchTokenTypeListItem, // 列表项
    WKatchTokenTypeBlockquote, // 引用
    WKatchTokenTypeTable, // 表格
    WKatchTokenTypeTaskItem, // 任务列表项
    WKatchTokenTypeHorizontalRule, // 水平分割线
    WKatchTokenTypeBoldItalic, // 粗斜体
} WKatchTokenType;

@protocol WKMatchToken <NSObject,NSCopying>

@property (nonatomic,copy) NSString *text;
@property (assign, nonatomic) NSRange  range;
@property(assign,nonatomic) WKatchTokenType type;

@end

@interface WKDefaultToken : NSObject<WKMatchToken>

+(WKDefaultToken*) text:(NSString*)text range:(NSRange)range type:(WKatchTokenType)type;

@end

@interface WKMetionToken : WKDefaultToken

@property(nonatomic,copy) NSString *uid;
@property(assign,nonatomic) NSInteger index; // 第几个@位

@end

@interface WKEmotionToken :WKDefaultToken

@property (copy, nonatomic) NSString *imageName;

@end

@interface WKLinkToken : WKDefaultToken
@property (nonatomic,copy) NSString *linkText;
@property (nonatomic,copy) NSString *linkContent;
@end

@interface WKBoldToken : WKDefaultToken

@property (nonatomic,copy) NSString *boldText; // 加粗的文本

@end

@interface WKRemoteImageToken : WKDefaultToken

@property(nonatomic,copy) NSString *url; // 图片下载地址
@property(nonatomic,assign) CGSize size; // 图片大小

@end

@interface WKColorToken : WKDefaultToken

@property(nonatomic,strong) UIColor *color;

@end

@interface WKUnderlineToken : WKDefaultToken

@end

@interface WKItalicToken : WKDefaultToken

@property (nonatomic,copy) NSString *italicText;

@end

@interface WKStrikethroughToken : WKDefaultToken

@property (nonatomic,copy) NSString *strikethroughText;

@end

@interface WKFontToken : WKDefaultToken

@property(nonatomic,assign) CGFloat fontSize;

@end

@interface WKInlineCodeToken : WKDefaultToken

@property (nonatomic,copy) NSString *codeText;

@end

@interface WKHeadingToken : WKDefaultToken

@property (nonatomic,copy) NSString *headingText;
@property (nonatomic,assign) NSInteger level; // 1, 2, 3

@end

@interface WKCodeBlockToken : WKDefaultToken

@property (nonatomic,copy) NSString *codeContent;
@property (nonatomic,copy, nullable) NSString *language;

@end

@interface WKListItemToken : WKDefaultToken

@property (nonatomic,copy) NSString *itemText;
@property (nonatomic,assign) BOOL ordered;
@property (nonatomic,assign) NSInteger orderNumber;

@end

@interface WKBlockquoteToken : WKDefaultToken

@property (nonatomic,copy) NSString *quoteText;

@end

@interface WKTableToken : WKDefaultToken

@property (nonatomic,strong) NSArray<NSArray<NSString*>*> *rows; // 每行每列的内容
@property (nonatomic,assign) BOOL hasHeader; // 是否有表头

@end

@interface WKTaskItemToken : WKDefaultToken

@property (nonatomic,copy) NSString *itemText;
@property (nonatomic,assign) BOOL checked;

@end

@interface WKHorizontalRuleToken : WKDefaultToken

@end

@interface WKBoldItalicToken : WKDefaultToken

@property (nonatomic,copy) NSString *boldItalicText;

@end

NS_ASSUME_NONNULL_END
