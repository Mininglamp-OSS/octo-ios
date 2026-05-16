// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKScreenshotContent.h
//  WuKongBase
//  截屏通知
//  Created by tt on 2020/10/16.
//

#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKScreenshotContent : WKMessageContent

@property(nonatomic,copy) NSString *tip;

@end

NS_ASSUME_NONNULL_END
