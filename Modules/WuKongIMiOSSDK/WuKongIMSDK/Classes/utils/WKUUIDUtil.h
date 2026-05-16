//
//  WKUUIDUtil.h
//  WuKongIMSDK
//
//  Created by tt on 2020/5/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKUUIDUtil : NSObject

+ (NSString*)getUUID;

+(NSString*) getClientMsgNo:(NSInteger)clientMsgDeviceId;
@end

NS_ASSUME_NONNULL_END
