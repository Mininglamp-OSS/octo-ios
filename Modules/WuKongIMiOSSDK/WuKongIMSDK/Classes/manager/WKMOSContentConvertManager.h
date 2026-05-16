//
//  WKMOSContentConvertManager.h
//  WuKongIMSDK
//
//  Created by tt on 2020/6/5.
//

#import <Foundation/Foundation.h>
#import "WKMessage.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMOSContentConvertManager : NSObject

+ (WKMOSContentConvertManager *)shared;

// 将mos的content转换为lm的content（TODO:为了兼容lm协议，如果没有指定mos协议不用管此方法）
-(NSDictionary*) convertContentToLM:(NSDictionary *)contentDic message:(WKMessage*)message;
// 将lm的content转换为mos的content （TODO:为了兼容lm协议，如果没有指定mos协议不用管此方法）
-(NSDictionary*) convertContentToMOS:(NSDictionary *)contentDic message:(WKMessage*)message;


/// 将mos正文类型转换为lm的正文类型
/// @param mosContentType <#mosContentType description#>
-(NSInteger) convertTypeToLM:(NSInteger)mosContentType;

@end

NS_ASSUME_NONNULL_END
