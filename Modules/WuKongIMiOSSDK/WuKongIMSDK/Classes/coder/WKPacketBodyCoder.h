// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKPacketBodyCoder.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/25.
//
#import "WKPacket.h"

@protocol WKPacketBodyCoder <NSObject>

-(WKPacket*) decode:(NSData*) body header:(WKHeader*)header;

-(NSData*) encode:(WKPacket*)packet;

@end
