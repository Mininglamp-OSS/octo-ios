//
//  WKRichTextParseService.h
//  WuKongBase
//
//  Created by tt on 2021/7/27.
//

#import <Foundation/Foundation.h>
#import "WKMatchToken.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKRichTextParseOptions : NSObject

@property(nonatomic,assign) BOOL disableLink; // 禁止解析链接

@end

@interface WKRichTextParseService : NSObject

+ (WKRichTextParseService *)shared;

-(NSArray<id<WKMatchToken>>*) parse:(NSString*)text mentionInfo:(WKMentionedInfo* __nullable)mentionInfo options:(WKRichTextParseOptions* __nullable)options;

// 链接解析
-(NSArray<id<WKMatchToken>>*) parseLink:(NSString*)text;
@end

NS_ASSUME_NONNULL_END
