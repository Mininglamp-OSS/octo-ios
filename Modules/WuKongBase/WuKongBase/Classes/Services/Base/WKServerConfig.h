//
//  WKServerConfig.h
//  WuKongBase
//
//  动态服务器地址配置管理
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKServerConfig : NSObject

+ (NSString *)serverIP;
+ (BOOL)httpsOn;
+ (void)saveServerIP:(NSString *)ip httpsOn:(BOOL)on;
+ (BOOL)hasCustomServer;

/// 获取历史服务器列表，每项为 @{@"ip": ip, @"https": @(YES/NO)}
+ (NSArray<NSDictionary *> *)serverHistory;

/// 获取内置预设服务器列表（由 OctoConfig.xcconfig 注入，空配置时返回 @[]）
+ (NSArray<NSDictionary *> *)presetServers;

/// 从历史记录中删除指定条目
+ (void)removeServerFromHistory:(NSDictionary *)entry;

@end

NS_ASSUME_NONNULL_END
