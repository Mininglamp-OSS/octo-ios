//
//  WKScreenshotContent.m
//  WuKongBase
//
//  Created by tt on 2020/10/16.
//

#import "WKScreenshotContent.h"
#import "WKApp.h"
#import "WuKongBase.h"

@interface WKScreenshotContent ()


@end

@implementation WKScreenshotContent


- (NSString *)tip {
    if(_tip) {
        return _tip;
    }
    WKUserInfo *userInfo = self.senderUserInfo;
    NSString *name = LLang(@"你");
    if([userInfo.uid isEqualToString:[WKApp shared].loginInfo.uid]) {
        name = LLang(@"你");
    }else{
       WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:userInfo.uid]];
        if(channelInfo) {
            name = channelInfo.displayName;
        }else{
            name = userInfo.name;
        }
    }
    _tip =  [NSString stringWithFormat:LLang(@"%@在聊天中截屏了"),name];
    return _tip;
}

- (NSDictionary *)encodeWithJSON {
    return @{@"from_uid":[WKApp shared].loginInfo.uid?:@"",@"from_name":[WKApp shared].loginInfo.extra[@"name"]?:@""};
}

- (NSString *)conversationDigest {
    return self.tip;
}

+ (NSNumber*)contentType {
    return @(WK_SCREENSHOT);
}
@end
