//
//  WKUserOnlineResp.h
//  WuKongBase
//
//  Created by tt on 2023/1/3.
//

#import <Foundation/Foundation.h>
#import "WKModel.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKUserOnlineResp:WKModel

@property(nonatomic,copy) NSString *uid;
@property(nonatomic,assign) WKDeviceFlagEnum deviceFlag;
@property(nonatomic,assign) NSInteger lastOnline;
@property(nonatomic,assign) NSInteger lastOffline;
@property(nonatomic,assign) BOOL online;

@end

NS_ASSUME_NONNULL_END
