//
//  WKChannelRequestQueue.h
//  WuKongIMSDK
//
//  Created by tt on 2021/4/22.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKChannelRequestQueue : NSObject

+ (WKChannelRequestQueue *)shared;


-(void) addRequest:(WKChannel*)channel complete:(void(^)(NSError *error,bool notifyBefore))complete;

-(void) cancelRequest:(WKChannel*)channel;
@end

NS_ASSUME_NONNULL_END
