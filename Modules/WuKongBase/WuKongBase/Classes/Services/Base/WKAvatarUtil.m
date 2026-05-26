//
//  WKUserAvatarUtil.m
//  WuKongBase
//
//  Created by tt on 2020/2/29.
//

#import "WKAvatarUtil.h"
#import "WKApp.h"

@implementation WKAvatarUtil

+(NSString*) getAvatar:(NSString*)uid {
    return [[NSURL URLWithString:[NSString stringWithFormat:@"users/%@/avatar",uid] relativeToURL:[NSURL URLWithString:[WKApp shared].config.apiBaseUrl]] absoluteString];
}

+(NSString*) getFullAvatarWIthPath:(NSString*)avatarPath {
    if(!avatarPath) {
        return nil;
    }
    if([avatarPath hasPrefix:@"http"]) {
        return avatarPath;
    }
    if([avatarPath hasPrefix:@"/"]) {
        return [NSString stringWithFormat:@"%@%@",[WKApp shared].config.apiBaseUrl,[avatarPath stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""]];
    }
    return  [NSString stringWithFormat:@"%@%@",[WKApp shared].config.apiBaseUrl,avatarPath];
}

+(NSString*) getAvatar:(NSString*)uid cacheKey:(NSString*)cacheKey {
    NSString *url = [self getAvatar:uid];
    NSString *key = (cacheKey && cacheKey.length > 0) ? cacheKey : @"0";
    url = [NSString stringWithFormat:@"%@?v=%@", url, key];
    return url;
}

+(NSString*) getGroupAvatar:(NSString*)groupNo {
     return [[NSURL URLWithString:[NSString stringWithFormat:@"groups/%@/avatar",groupNo] relativeToURL:[NSURL URLWithString:[WKApp shared].config.apiBaseUrl]] absoluteString];
}

+(NSString*) getGroupAvatar:(NSString*)groupNo cacheKey:(NSString*)cacheKey {
    NSString *url = [self getGroupAvatar:groupNo];
    NSString *key = (cacheKey && cacheKey.length > 0) ? cacheKey : @"0";
    url = [NSString stringWithFormat:@"%@?v=%@", url, key];
    return url;
}

+(NSString*) stableCacheKeyFromAvatarURL:(NSString*)avatarURL {
    if (avatarURL.length == 0) return nil;
    NSRange queryStart = [avatarURL rangeOfString:@"?"];
    if (queryStart.location == NSNotFound) {
        return avatarURL; // 无 query，整 URL 就是稳定 key
    }
    NSString *path = [avatarURL substringToIndex:queryStart.location];
    NSString *query = [avatarURL substringFromIndex:queryStart.location + 1];
    NSArray<NSString *> *parts = [query componentsSeparatedByString:@"&"];
    NSMutableArray<NSString *> *kept = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSString *part in parts) {
        // 只剥 v=<cacheKey> 这一个 param，其它 query 全部保留 —— 否则把不同身份
        // (如 ?id=a 与 ?id=b) 的头像错误映射到同一 key，cell 复用时闪错图。
        if (![part hasPrefix:@"v="]) {
            [kept addObject:part];
        }
    }
    if (kept.count == 0) return path;
    return [NSString stringWithFormat:@"%@?%@", path, [kept componentsJoinedByString:@"&"]];
}

@end
