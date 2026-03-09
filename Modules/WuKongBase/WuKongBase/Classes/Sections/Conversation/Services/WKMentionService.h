//
//  WKMentionService.h
//  WuKongBase
//
//  Created by tt on 2020/7/16.
//

#import <Foundation/Foundation.h>
#import "WKMatchToken.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN


@interface WKMentionService : NSObject

+ (WKMentionService *)shared;

/**
 替换字符串的@占位符
 
 @param str 需要替换的字符串
 @return 返回替换好的字符串
 */
-(NSArray<id<WKMatchToken>>*)parseMention:(NSString *)str mentionInfo:(WKMentionedInfo * __nullable)mentionInfo;
@end

NS_ASSUME_NONNULL_END
