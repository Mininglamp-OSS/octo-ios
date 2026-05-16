// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMessageExtra.m
//  WuKongIMSDK
//
//  Created by tt on 2022/4/12.
//

#import "WKMessageExtra.h"

@implementation WKMessageExtra

- (BOOL)isEdit {
    if(self.editedAt>0) {
        return true;
    }
    return false;
}

@end
