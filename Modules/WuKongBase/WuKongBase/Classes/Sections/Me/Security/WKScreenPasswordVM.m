// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKScreenPasswordVM.m
//  WuKongBase
//
//  Created by tt on 2021/8/16.
//

#import "WKScreenPasswordVM.h"

@implementation WKScreenPasswordVM

-(AnyPromise*) requestCloseLock {
    return  [[WKAPIClient sharedClient] DELETE:@"user/lockscreenpwd" parameters:nil];
}

@end
