//
//  WKChannelUtil.h
//  WuKongBase
//
//  Created by tt on 2021/8/4.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKChannelUtil : NSObject

+ (WKChannelInfo *)toChannelInfo2:(NSDictionary*)resultDict;

+(WKChannelInfo*) toChannelInfo:(NSDictionary*)channelDic;

+(WKGroupType) groupType:(WKChannelInfo*)channelInfo;

#pragma mark - 实名认证徽章（YUJ-381 / dmwork-web#1169 Phase A）

/// Tri-state 读取 extra[@"realname_verified"]（YUJ-384 P1-2 修复）：
///   - @YES：字段显式为真（数值 1 / @YES / "1" / "true" / "YES"）
///   - @NO ：字段显式为假（0 / "0" / "false" 等）
///   - nil ：字段缺失 / NSNull / 非 NSDictionary 输入
///
/// 区分「显式 false」与「字段缺失」是为了支持正确的 fallback 语义：调用方仅在
/// nil 时才回退到 person cache；显式 @NO 应直接视为未实名，避免已被取消实名的
/// 用户因 cache 命中而错误打勾（跨端对齐 web `orgData.realname_verified`）。
///
/// 输入容忍度：NSNumber / NSString / nil / NSNull 任一形态皆可。
+(NSNumber * _Nullable) isRealnameVerifiedFromExtra:(NSDictionary * _Nullable)extra;

@end

NS_ASSUME_NONNULL_END
