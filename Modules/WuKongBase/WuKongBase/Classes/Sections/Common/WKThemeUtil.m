//
//  WKThemeUtil.m
//  WuKongBase
//
//  Created by tt on 2022/9/9.
//

#import "WKThemeUtil.h"
#import "WKApp.h"
@implementation WKThemeUtil

+(NSData*) getChatBackground:(WKChannel*)channel style:(WKSystemStyle)style{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *channelBackgroundDir = [self getOrCreateChannelBackgroudDir:channel];
   NSString *bgFilePath = [channelBackgroundDir stringByAppendingPathComponent:[self getChatbackgroundName:style]];
    if([fileManager fileExistsAtPath:bgFilePath]) {
        return [NSData dataWithContentsOfFile:bgFilePath];
    }
    if(style != WKSystemStyleLight) {
        bgFilePath = [channelBackgroundDir stringByAppendingPathComponent:[self getChatbackgroundName:WKSystemStyleLight]];
        if([fileManager fileExistsAtPath:bgFilePath]) {
            return [NSData dataWithContentsOfFile:bgFilePath];
        }
    }
    return nil;
}

+(NSString*) getOrCreateChannelBackgroudDir:(WKChannel*)channel {
    NSString *themeDir = [WKApp.shared.config.fileStorageDir stringByAppendingPathComponent:@"theme"];
    
    NSString *channelBackgroundDir = [themeDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%hhu",channel.channelId,channel.channelType]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL exist = [fileManager fileExistsAtPath:channelBackgroundDir];
    if(!exist) {
        NSError *error;
        [fileManager createDirectoryAtPath:channelBackgroundDir withIntermediateDirectories:YES attributes:nil error:&error];
        if(error) {
            NSLog(@"创建频道主题目录失败！=>%@",error);
        }
    }
    return channelBackgroundDir;
}

// 是否存在聊天背景图
+(BOOL) existChatBackground:(WKChannel*)channel {
    NSString *themeDir = [WKApp.shared.config.fileStorageDir stringByAppendingPathComponent:@"theme"];
    
    NSString *channelBackgroundDir = [themeDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%hhu",channel.channelId,channel.channelType]];
    NSString *bgFilePath = [channelBackgroundDir stringByAppendingPathComponent:@"chatbackgroud"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:bgFilePath];
}

/**
 保存某个频道的背景图
 */
+(BOOL) saveChatBackground:(WKChannel*)channel data:(NSData*)data style:(WKSystemStyle)style{
    if(!data) {
        return false;
    }
    NSString *channelBackgroundDir = [self getOrCreateChannelBackgroudDir:channel];
    NSString *bgFilePath = [channelBackgroundDir stringByAppendingPathComponent:[self getChatbackgroundName:style]];
   return [data writeToFile:bgFilePath atomically:YES];
}

// 保存默认背景图
+(BOOL) saveDefaultBackground:(NSData*)data style:(WKSystemStyle)style{
    if(!data) {
        return false;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *themeDir = [WKApp.shared.config.fileStorageDir stringByAppendingPathComponent:@"theme"];
    BOOL exist = [fileManager fileExistsAtPath:themeDir];
    if(!exist) {
        NSError *error;
        [fileManager createDirectoryAtPath:themeDir withIntermediateDirectories:YES attributes:nil error:&error];
        if(error) {
            NSLog(@"创建主题目录失败！=>%@",error);
            return false;
        }
    }
    NSString *file = [themeDir stringByAppendingPathComponent:[self getChatbackgroundName:style]];
   
    
    return [data writeToFile:file atomically:YES];
}

+(NSString*) getChatbackgroundName:(WKSystemStyle)style {
    if(style == WKSystemStyleDark) {
        return @"chatbackgroud-dark";
    }
    return @"chatbackgroud";
}

+(BOOL) existDefaultbackground {
    NSString *themeDir = [WKApp.shared.config.fileStorageDir stringByAppendingPathComponent:@"theme"];
    
    NSString *bgFilePath = [themeDir stringByAppendingPathComponent:@"chatbackgroud"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:bgFilePath];
}

+(NSData*) getDefaultBackground:(WKSystemStyle)style {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *themeDir = [WKApp.shared.config.fileStorageDir stringByAppendingPathComponent:@"theme"];
    NSString *file = [themeDir stringByAppendingPathComponent:[self getChatbackgroundName:style]];
    if([fileManager fileExistsAtPath:file]) {
        return [NSData dataWithContentsOfFile:file];
    }
    if(style != WKSystemStyleLight) {
        file = [themeDir stringByAppendingPathComponent:[self getChatbackgroundName:WKSystemStyleLight]];
        if([fileManager fileExistsAtPath:file]) {
            return [NSData dataWithContentsOfFile:file];
        }
    }
   
    return nil;
}

@end
