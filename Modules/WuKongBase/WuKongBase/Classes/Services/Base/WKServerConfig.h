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

@end

NS_ASSUME_NONNULL_END
