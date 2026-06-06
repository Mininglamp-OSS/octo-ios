//
//  NSMutableAttributedString+WK.h
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import <Foundation/Foundation.h>
#import "WKApp.h"
#import "WKRichTextParseService.h"
NS_ASSUME_NONNULL_BEGIN

@interface NSMutableAttributedString (WK)

@property(nonatomic,strong) UIFont *font;
@property(nonatomic,strong) UIColor *textColor;
@property(nonatomic,strong) UIColor *metionColor;
@property(nonatomic,strong) UIColor *linkColor; // 链接颜色
@property(nonatomic,assign) BOOL metionUnderline; //是否显示下划线


@property(nonatomic,strong) NSArray<id<WKMatchToken>> *tokens;

- (void)lim_parse:(NSString *)text;
- (void)lim_parse:(NSString *)text mentionInfo:(WKMentionedInfo* __nullable)mentionInfo;
- (void)lim_parse:(NSString *)text mentionInfo:(WKMentionedInfo *__nullable)mentionInfo options:(WKRichTextParseOptions*__nullable)options;

-(void) lim_render:(NSString *)text tokens:(NSArray<id<WKMatchToken>>*)tokens;

// 追加纯文本，返回新增文本所在 range（沿用当前 font/textColor）。
-(NSRange) appendText:(NSString*)text;

// 追加 @mention（按 token.uid 优先取对应 channelInfo.remark；否则用 token.text），
// 自动套 self.metionColor + 可选下划线，返回新增 mention 所在 range。
-(NSRange) appendMetion:(WKMetionToken*)token;

// 追加远程图片占位（WKRemoteImageToken → WKRemoteImageAttachment），返回占位 range。
-(NSRange) appendRemoteImage:(WKRemoteImageToken*)token;


// 最后一行的宽度
-(CGFloat)lastlineWidth:(CGFloat)maxWidth;

-(CGSize) size:(CGFloat)maxWidth;

@end

NS_ASSUME_NONNULL_END
