// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSecurityTipManager.h
//  WuKongBase
//
//  Created by tt on 2022/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSecurityTipManager : NSObject

+ (instancetype _Nonnull )shared;

-(NSString*) tip;

-(BOOL) match:(NSString*)text;

-(void) syncIfNeed;

@end

NS_ASSUME_NONNULL_END
