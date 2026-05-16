//
//  WKScreenPasswordVM.m
//  WuKongBase
//
//  Created by tt on 2021/8/16.
//

#import "WKScreenPasswordSetVM.h"
#import "WKMD5Util.h"
@implementation WKScreenPasswordSetVM


-(AnyPromise*) requestLockscreenpwd:(NSString*)password {
   
    NSString *pwd = [[self class] digestLockScreenPwd:password];
    [WKApp shared].loginInfo.extra[@"lock_screen_pwd"] = pwd;
    [[WKApp shared].loginInfo save];
   return [[WKAPIClient sharedClient] POST:@"user/lockscreenpwd" parameters:@{
        @"lock_screen_pwd":pwd,
    }];
}

+(NSString*) digestLockScreenPwd:(NSString*)pwd {
    return [WKMD5Util md5HexDigest:[NSString stringWithFormat:@"%@%@",pwd,[WKApp shared].loginInfo.uid]];
}

@end
