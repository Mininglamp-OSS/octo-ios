// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKStringUtil.h
//  WuKongBase
//
//  Created by tt on 2021/11/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKStringUtil : NSObject

// 匹配@符号
+ (NSArray *)matchMention:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
