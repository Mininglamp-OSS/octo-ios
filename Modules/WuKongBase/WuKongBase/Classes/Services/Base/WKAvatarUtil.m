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

+(NSString*) getGroupAvatar:(NSString*)groupNo {
     return [[NSURL URLWithString:[NSString stringWithFormat:@"groups/%@/avatar",groupNo] relativeToURL:[NSURL URLWithString:[WKApp shared].config.apiBaseUrl]] absoluteString];
}

@end
