//
//  WKCore.h
//  WuKongCore
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>
#import "WKEndpoint.h"
#import "WKEndpointManager.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKCore : NSObject

/**
 注册端点
 @param endpoint 端点对象
 */
-(void) registerEndpoint:(WKEndpoint*)endpoint;

@end

NS_ASSUME_NONNULL_END
