//
//  WKGlobalSearchFeatureFlag.m
//  WuKongBase
//

#import "WKGlobalSearchFeatureFlag.h"

@implementation WKGlobalSearchFeatureFlag

+ (BOOL)apiEnabled {
    // 与 WKInteractiveCardCell +cardFeatureEnabled 同款：NSUserDefaults / 启动参数覆盖优先，
    // 默认开启。服务端仍是权威——backend 非 ES 时返回 SEARCH_DISABLED，V2 页面据此运行时回落到
    // 本地搜索（见 WKGlobalSearchV2VC）。QA 一键关闭：`-OCTO_GLOBAL_SEARCH_API_ENABLED 0`。
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:@"OCTO_GLOBAL_SEARCH_API_ENABLED"];
    if (v == nil) {
        return YES;
    }
    return [v boolValue];
}

@end
