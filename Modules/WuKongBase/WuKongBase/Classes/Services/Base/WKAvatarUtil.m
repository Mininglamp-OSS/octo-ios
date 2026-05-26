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
    if (query.length == 0) return path;
    NSArray<NSString *> *parts = [query componentsSeparatedByString:@"&"];
    // 仅剥**末尾**的那一个 v=<cacheKey> ——
    // 这里的 `v=` 是 WKAvatarUtil.getGroupAvatar:cacheKey: / getAvatar:cacheKey:
    // 以及 cell 内联拼装时**始终追加在最后**的 cache-buster；上游 channelInfo.logo
    // 自带的 v=（若把 v 当 variant 含义）应保留, 否则会让不同身份的头像错误归一。
    NSString *last = parts.lastObject;
    if (![last hasPrefix:@"v="]) {
        return avatarURL; // 末尾不是我们追加的 cache-buster, 整 URL 当稳定 key
    }
    if (parts.count == 1) {
        return path; // 唯一 query 就是 cache-buster, 去掉后只剩 path
    }
    NSArray<NSString *> *kept = [parts subarrayWithRange:NSMakeRange(0, parts.count - 1)];
    return [NSString stringWithFormat:@"%@?%@", path, [kept componentsJoinedByString:@"&"]];
}

@end
