// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKGroupBaseInfo.m
//  WuKongBase
//
//  Created by tt on 2022/8/31.
//

#import "WKGroupBaseInfo.h"

@implementation WKGroupBaseInfo

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKGroupBaseInfo *base = [WKGroupBaseInfo new];
    base.quit = [dictory[@"quit"] boolValue];
    base.memberCount = [dictory[@"member_count"] integerValue];
    base.onlineCount = [dictory[@"online_count"] integerValue];
    base.role = [dictory[@"role"] integerValue];
    return base;
}

@end

