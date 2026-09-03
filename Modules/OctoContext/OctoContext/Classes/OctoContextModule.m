//
//  OctoContextModule.m
//  OctoContext
//

#import "OctoContextModule.h"
#import "OctoSummaryGroupNotifyHelper.h"

@WKModule(OctoContextModule)

@implementation OctoContextModule

- (NSString *)moduleId {
    return @"OctoContext";
}

- (void)moduleInit:(WKModuleContext *)context {
    NSLog(@"【OctoContext】模块初始化");
    [self registerSummaryDeepLinkPoint];
}

/// 消息里的"查看总结详情"链接 → 群提示判定。
/// WuKongBase 的消息 cell 只知道 endpoint 名字 (WKPOINT_SUMMARY_DEEPLINK), 实现挂在
/// 这里, 双向都不产生编译期依赖。判定是纯副作用: 不拦截、不改导航, 链接照旧打开 WebView。
- (void)registerSummaryDeepLinkPoint {
    [[WKApp shared] setMethod:WKPOINT_SUMMARY_DEEPLINK handler:^id _Nullable(id _Nonnull param) {
        NSString *url = [param isKindOfClass:NSDictionary.class] ? ((NSDictionary *)param)[@"url"] : nil;
        if ([url isKindOfClass:NSString.class]) {
            [OctoSummaryGroupNotifyHelper handleSummaryDeepLink:url];
        }
        return nil;
    }];
}

@end
