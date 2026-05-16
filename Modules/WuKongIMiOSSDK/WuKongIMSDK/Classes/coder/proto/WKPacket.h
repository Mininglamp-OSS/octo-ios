// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKPacket.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//

#import <Foundation/Foundation.h>
#import "WKHeader.h"
typedef NSString* (^Encode)(void);

@interface WKPacket : NSObject

@property(nonatomic,strong) WKHeader *header;


@end
