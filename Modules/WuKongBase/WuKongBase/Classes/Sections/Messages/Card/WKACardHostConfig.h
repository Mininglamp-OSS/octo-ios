//
//  WKACardHostConfig.h
//  WuKongBase
//
//  构建 Adaptive Cards 渲染用的 ACOHostConfig（字体/间距/颜色/暗色主题）。
//
#import <Foundation/Foundation.h>
#import <AdaptiveCards/ACOHostConfig.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKACardHostConfig : NSObject

/// 返回与当前 App 风格（明/暗）匹配的 HostConfig。内部缓存两套。
+ (ACOHostConfig *)hostConfigForDark:(BOOL)dark;

@end

NS_ASSUME_NONNULL_END
