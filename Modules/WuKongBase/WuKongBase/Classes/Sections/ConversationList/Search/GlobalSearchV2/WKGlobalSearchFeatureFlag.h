//
//  WKGlobalSearchFeatureFlag.h
//  WuKongBase
//
//  全局搜索「服务端 API 化」灰度开关。镜像 WKInteractiveCardCell +cardFeatureEnabled 的模式：
//  优先看 NSUserDefaults / 启动参数覆盖，否则读远程配置；灰度期默认关闭 → 回落到本地 DB 搜索
//  (WKGlobalSearchResultController)。
//
//  一键关闭（QA / 回退）：启动参数 `-OCTO_GLOBAL_SEARCH_API_ENABLED 0`。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKGlobalSearchFeatureFlag : NSObject

/// 是否启用服务端 API 全局搜索。YES → WKGlobalSearchV2VC；NO → 旧本地搜索栈。
+ (BOOL)apiEnabled;

@end

NS_ASSUME_NONNULL_END
