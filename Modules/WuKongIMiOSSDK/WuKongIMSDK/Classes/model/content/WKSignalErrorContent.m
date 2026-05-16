//
//  WKSignalErrorContent.m
//  WuKongIMSDK
//
//  Created by tt on 2021/9/9.
//

#import "WKSignalErrorContent.h"

@implementation WKSignalErrorContent


+(NSNumber*) contentType {
    return @(WK_SIGNAL_ERROR);
}

- (NSString *)conversationDigest {
    return @"[解密失败]";
}

@end
