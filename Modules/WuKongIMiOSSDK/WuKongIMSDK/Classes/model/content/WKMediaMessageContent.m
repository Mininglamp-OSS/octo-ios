//
//  WKMediaMessageContent.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
//

#import "WKMediaMessageContent.h"
#import "WKFileUtil.h"
#import "WKSDK.h"
#import "WKMediaUtil.h"

@interface WKMediaMessageContent ()

@property(nonatomic,strong) NSMutableDictionary *extraData;

@end

@implementation WKMediaMessageContent

@synthesize localPath;
@synthesize remoteUrl;
@synthesize message;
@synthesize extension;
@synthesize thumbExtension;
@synthesize thumbPath;


- (void)writeDataToLocalPath {
    // 创建频道目录
      NSString *uid = [WKSDK shared].options.connectInfo.uid;
    NSString *channelDir = [NSString stringWithFormat:@"%@/%@/%@",[WKSDK shared].options.messageFileRootDir,uid,[WKMediaUtil getChannelDir:self.message.channel]];
    [WKFileUtil createDirectoryIfNotExist:channelDir];
}

- (nullable id)getExtra:(nonnull NSString *)key {
   return [self.extraData objectForKey:key];
}

- (void)setExtra:(nonnull NSString *)value key:(nonnull NSString*)key {
    [self.extraData setValue:value forKey:key];
}

- (NSMutableDictionary *)extraData {
    if(!_extraData) {
        _extraData = [[NSMutableDictionary alloc] init];
    }
    return _extraData;
}


- (NSString *)localPath {
    NSString *uid = [WKSDK shared].options.connectInfo.uid;
    return   [NSString stringWithFormat:@"%@/%@/%@",[WKSDK shared].options.messageFileRootDir,uid, [WKMediaUtil getLocalPath:self]];
}

- (NSString *)thumbPath {
    NSString *uid = [WKSDK shared].options.connectInfo.uid;
    return  [NSString stringWithFormat:@"%@/%@/%@",[WKSDK shared].options.messageFileRootDir,uid, [WKMediaUtil getThumbLocalPath:self]];
}



@end
