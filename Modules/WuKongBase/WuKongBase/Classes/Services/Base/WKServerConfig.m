//
//  WKServerConfig.m
//  WuKongBase
//
//  动态服务器地址配置管理
//

#import "WKServerConfig.h"

static NSString * const kWKCustomServerIPKey = @"WKCustomServerIP";
static NSString * const kWKCustomHttpsOnKey  = @"WKCustomHttpsOn";
static NSString * const kDefaultServerIP     = @"api-test.example.com";

@implementation WKServerConfig

+ (NSString *)serverIP {
    NSString *customIP = [[NSUserDefaults standardUserDefaults] stringForKey:kWKCustomServerIPKey];
    if (customIP.length > 0) {
        return customIP;
    }
    return kDefaultServerIP;
}

+ (BOOL)httpsOn {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kWKCustomHttpsOnKey]) {
        return [[NSUserDefaults standardUserDefaults] boolForKey:kWKCustomHttpsOnKey];
    }
    return YES;
}

+ (void)saveServerIP:(NSString *)ip httpsOn:(BOOL)on {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:ip forKey:kWKCustomServerIPKey];
    [defaults setBool:on forKey:kWKCustomHttpsOnKey];
    [defaults synchronize];
}

+ (BOOL)hasCustomServer {
    NSString *customIP = [[NSUserDefaults standardUserDefaults] stringForKey:kWKCustomServerIPKey];
    return (customIP.length > 0);
}

@end
