//
//  WKGlobalSearchEntry.h
//  WuKongBase
//
//  全局搜索入口工厂：按灰度开关返回服务端 API 版（WKGlobalSearchV2VC）或旧本地搜索版
//  （WKGlobalSearchResultController）。所有全局搜索入口统一走此工厂，开关关闭即安全回落。
//

#import <UIKit/UIKit.h>
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKGlobalSearchEntry : NSObject

/// 构造全局搜索页。type 决定默认 tab；kw 为预填关键词（可空）。
+ (UIViewController *)controllerWithSearchType:(WKHistoryMessageSearchType)type
                                       keyword:(nullable NSString *)keyword;

@end

NS_ASSUME_NONNULL_END
