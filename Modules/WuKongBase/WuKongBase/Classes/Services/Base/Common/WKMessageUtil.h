//
//  WKMessageUtil.h
//  WuKongBase
//
//  Created by tt on 2020/10/12.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageUtil : NSObject

+(WKMessage*) toMessage:(NSDictionary*)messageDict;

+(WKMessageExtra*) toMessageExtra:(NSDictionary*)dataDict channel:(WKChannel*)channel;

+(WKReaction*) toReaction:(NSDictionary*)dataDict;

@end

NS_ASSUME_NONNULL_END
