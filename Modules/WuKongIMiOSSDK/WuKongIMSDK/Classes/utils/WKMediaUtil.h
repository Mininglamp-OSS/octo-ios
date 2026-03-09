//
//  WKMediaUtils.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
//

#import <Foundation/Foundation.h>
#import "WKMediaProto.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMediaUtil : NSObject


/**
 获取媒体本地路径

 @param media <#media description#>
 @return <#return value description#>
 */
+(NSString*) getLocalPath:(id<WKMediaProto>)media;


/**
 获取媒体副本本地路径

 @param media <#media description#>
 @return <#return value description#>
 */
+(NSString*) getThumbLocalPath:(id<WKMediaProto>)media;


/**
 获取频道的存储目录

 @param channel <#channel description#>
 @return <#return value description#>
 */
+(NSString*) getChannelDir:(WKChannel*) channel;

@end

NS_ASSUME_NONNULL_END
