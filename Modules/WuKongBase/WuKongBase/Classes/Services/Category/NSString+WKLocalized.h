// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  NSString+Localized.h
//  WuKongBase
//
//  Created by tt on 2020/12/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKNoUse : NSObject
@end


@interface NSString (WKLocalized)

-(NSString* _Nonnull) Localized:(id)the;

-(NSString* _Nonnull) LocalizedWithClass:(Class)cls;

-(NSString* _Nonnull) LocalizedWithBundle:(NSBundle*)bundle;
@end

NS_ASSUME_NONNULL_END
