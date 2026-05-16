// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKScreenPasswordVC.h
//  WuKongBase
//
//  Created by tt on 2021/8/16.
//

#import <WuKongBase/WuKongBase.h>
#import "WKScreenPasswordVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKScreenPasswordVC : WKBaseVC<WKScreenPasswordVM*>

@property(nonatomic,copy) void(^onFinished)(NSString *pwd);

@property(nonatomic,assign) BOOL allowBack; // 是否允许返回


@end

NS_ASSUME_NONNULL_END
