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

@end

NS_ASSUME_NONNULL_END
