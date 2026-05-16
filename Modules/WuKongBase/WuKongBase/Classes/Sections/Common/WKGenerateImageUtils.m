// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKGenerateImageUtils.m
//  WuKongBase
//
//  Created by tt on 2022/6/21.
//

#import "WKGenerateImageUtils.h"
#import  <WuKongBase/WuKongBase-Swift.h>
@implementation WKGenerateImageUtils


+ (UIImage * _Nullable)generateTintedImgWithImage:(UIImage * _Nullable)image color:(UIColor * _Nonnull)color backgroundColor:(UIColor * _Nullable)backgroundColor  {
    return  [GenerateImageUtils generateTintedImgWithImage:image color:color backgroundColor:backgroundColor];
}

@end
