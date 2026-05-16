// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKUnknownContent.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import "WKUnknownContent.h"
#import "WKConst.h"
@implementation WKUnknownContent

+(NSNumber*) contentType {
    return @(WK_UNKNOWN);
}

- (NSString *)conversationDigest {
    return @"[未知消息]";
}

// 重写decode 让其不执行父类的decode操作
- (void)decode:(NSData *)data {
    
}

@end
