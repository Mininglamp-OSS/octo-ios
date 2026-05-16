//
//  WKModuleManager.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>
#import "WKModuleProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKModuleManager : NSObject
+ (WKModuleManager *)shared;
/**
 注册module
 
 @param moduleProtocol <#moduleProtocol description#>
 */
-(void) registerModule:(id<WKModuleProtocol>) moduleProtocol;


/**
 获取module

 @param sid <#sid description#>
 @return <#return value description#>
 */
-(id<WKModuleProtocol>) getModuleWithId:(NSString*)sid;


-(NSArray<id<WKModuleProtocol>>*) getAllModules;

/**
  资源模块
 */
-(NSArray<id<WKModuleProtocol>>*) getResourceModules;
/**
  模块初始化
 */
-(void) didModuleInit;
/**
 启动所有模块
 **/
- (BOOL)didFinishLaunching;

-(BOOL) didOpenURL:(NSURL*)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

-(BOOL) didContinueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;

- (void)moduleDidReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
/**
 数据库已加载
 */
-(void) didDatabaseLoad;
@end

NS_ASSUME_NONNULL_END
