// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKScreenPasswordVM.h
//  WuKongBase
//
//  Created by tt on 2021/8/16.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKScreenPasswordVM : WKBaseVM

// 关闭解锁密码
-(AnyPromise*) requestCloseLock;

@end

NS_ASSUME_NONNULL_END
