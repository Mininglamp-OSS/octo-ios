// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKTaskOperator.m
//  WuKongIMSDK
//
//  Created by tt on 2021/4/22.
//

#import "WKTaskOperator.h"

@implementation WKTaskOperator

+(WKTaskOperator*) cancel:(void(^)(void))cancel suspend:(void(^)(void))suspend resume:(void(^)(void))resume {
    WKTaskOperator *operator = [WKTaskOperator new];
    operator.cancel = cancel;
    operator.suspend = suspend;
    operator.resume = resume;
    return operator;
    
}

@end
