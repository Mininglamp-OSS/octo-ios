//
//  WKEndpointManager.h
//  WuKongCore
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>
#import "WKEndpoint.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKEndpointManager : NSObject

/**
 注册端点
 @param endpoint 端点对象
 */
-(void) registerEndpoint:(WKEndpoint*)endpoint;

-(void) unregisterEndpoint:(WKEndpoint*)endpoint;

-(void) unregisterEndpointWithCategory:(NSString*)category;


/**
 通过sid获取端点

 @param sid <#sid description#>
 @return <#return value description#>
 */
-(WKEndpoint*) getEndpointWithSid:(NSString*)sid;


/**
 通过category查询端点集合

 @param category <#category description#>
 @return <#return value description#>
 */
-(NSArray<WKEndpoint*>*) getEndpointsWithCategory:(NSString*)category;


-(void) registerMergeForwardItem:(NSInteger)contentType cls:(Class)cls;

-(Class) mergeForwardItem:(NSInteger)contentType;


// 跳转到用户资料界面
// @param uid 为用户的uid
// @param vercode 申请加好友的验证码
// @param channel 从那个频道跳转过来的
- (void)pushUserInfoVC:(NSString*)uid;
- (void)pushUserInfoVC:(NSString*)uid vercode:(NSString*)vercode;
- (void)pushUserInfoVC:(NSString*)uid vercode:(NSString*)vercode source:(WKChannel*)channel;

@end

NS_ASSUME_NONNULL_END
