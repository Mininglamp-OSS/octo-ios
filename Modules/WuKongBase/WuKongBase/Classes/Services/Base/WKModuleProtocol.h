//
//  WKModuleProtocol.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//
#import "WKModuleContext.h"

typedef enum : NSUInteger {
    WKModuleTypeDefault,
    WKModuleTypeResource
} WKModuleType;


NS_ASSUME_NONNULL_BEGIN
@protocol WKModuleProtocol <NSObject>
/**
 module id 全局唯一
 
 @return module id
 */
-(NSString*_Nonnull) moduleId;

// module类型
-(WKModuleType) moduleType;

// module排序
-(NSInteger) moduleSort;

@optional


/**
 获取module的图片资源
 
 @param name 图片名称
 @return 返回图片对象
 */
- (UIImage*_Nullable) ImageForResource:(NSString*_Nonnull)name;

/**
 获取语言包
 
 @param lang 语言
 */
-(NSDictionary*_Nullable) LangResource:(NSString*_Nullable)lang;


/**
 获取资源bundle
 
 @return return value description
 */
- (NSBundle*_Nullable) resourceBundle;


/**
 图片资源bundle
 
 @return <#return value description#>
 */
- (NSBundle*_Nullable) imageBundle;


/**
 获取资源路径
 
 @param name 资源名称
 @param ext 扩展名称
 @return <#return value description#>
 */
- (nullable NSString *)pathForResource:(nullable NSString *)name ofType:(nullable NSString *)ext;


/**
 module 初始化，在module加载的时候调用
 
 @param context <#context description#>
 */
- (void)moduleInit:(WKModuleContext*_Nonnull)context;



/**
 模块启动中 AppDelegate didFinishLaunching时期调用 晚于moduleInit
 
 @param context <#context description#>
 */
-(BOOL) moduleDidFinishLaunching:(WKModuleContext*_Nonnull) context;


/**
 数据库已初始化
 */
-(void) moduleDidDatabaseLoad:(WKModuleContext*_Nonnull) context;

-(BOOL) moduleOpenURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

-(BOOL) moduleContinueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;

- (void)moduleDidReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

@end

NS_ASSUME_NONNULL_END
