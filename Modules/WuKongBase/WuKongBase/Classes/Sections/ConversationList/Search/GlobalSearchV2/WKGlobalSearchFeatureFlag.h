//
//  WKGlobalSearchFeatureFlag.h
//  WuKongBase
//
//  全局搜索「服务端 API 化」灰度开关。镜像 WKInteractiveCardCell +cardFeatureEnabled 的模式：
//  NSUserDefaults / 启动参数覆盖优先，否则**默认开启**（V2 为生产默认路径）。服务端仍是权威——
//  backend 非 ES 时返回 SEARCH_DISABLED，V2 页面据此运行时回落到本地搜索
//  (WKGlobalSearchResultController)；开关关时同样回落本地栈。
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
