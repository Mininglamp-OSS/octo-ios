//
//  WKServerConfig.m
//  WuKongBase
//
//  动态服务器地址配置管理
//

#import "WKServerConfig.h"

static NSString * const kWKCustomServerIPKey   = @"WKCustomServerIP";
static NSString * const kWKCustomHttpsOnKey    = @"WKCustomHttpsOn";
static NSString * const kWKServerHistoryKey    = @"WKServerHistory";
static NSString * const kDefaultServerIP       = @"api-test.example.com";

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

    // 同时写入历史记录
    [self addToHistory:ip httpsOn:on];
}

+ (BOOL)hasCustomServer {
    NSString *customIP = [[NSUserDefaults standardUserDefaults] stringForKey:kWKCustomServerIPKey];
    return (customIP.length > 0);
}

#pragma mark - 历史记录

+ (NSArray<NSDictionary *> *)presetServers {
    return @[
        @{@"ip": @"api-test.example.com", @"https": @(YES), @"label": @"国内版"},
        @{@"ip": @"api-test.example.com",         @"https": @(YES), @"label": @"国际版"},
    ];
}

+ (NSArray<NSDictionary *> *)serverHistory {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kWKServerHistoryKey];
    NSMutableArray *result = saved ? [saved mutableCopy] : [NSMutableArray array];

    // 确保预设地址始终存在
    for (NSDictionary *preset in [self presetServers]) {
        BOOL exists = NO;
        for (NSDictionary *item in result) {
            if ([item[@"ip"] isEqualToString:preset[@"ip"]]) {
                exists = YES;
                break;
            }
        }
        if (!exists) {
            [result addObject:preset];
        }
    }
    return result;
}

+ (void)addToHistory:(NSString *)ip httpsOn:(BOOL)on {
    NSMutableArray *history = [[self serverHistory] mutableCopy];
    // 去重：移除已有的相同条目
    NSMutableArray *toRemove = [NSMutableArray array];
    for (NSDictionary *entry in history) {
        if ([entry[@"ip"] isEqualToString:ip]) {
            [toRemove addObject:entry];
        }
    }
    [history removeObjectsInArray:toRemove];
    // 插入到最前面
    [history insertObject:@{@"ip": ip, @"https": @(on)} atIndex:0];
    // 最多保留 10 条
    if (history.count > 10) {
        history = [[history subarrayWithRange:NSMakeRange(0, 10)] mutableCopy];
    }
    [[NSUserDefaults standardUserDefaults] setObject:history forKey:kWKServerHistoryKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)removeServerFromHistory:(NSDictionary *)entry {
    NSMutableArray *history = [[self serverHistory] mutableCopy];
    NSMutableArray *toRemove = [NSMutableArray array];
    for (NSDictionary *item in history) {
        if ([item[@"ip"] isEqualToString:entry[@"ip"]]) {
            [toRemove addObject:item];
        }
    }
    [history removeObjectsInArray:toRemove];
    [[NSUserDefaults standardUserDefaults] setObject:history forKey:kWKServerHistoryKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
