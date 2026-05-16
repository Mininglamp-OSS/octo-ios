// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKBotPlazaVM.h
//  WuKongContacts
//

#import <WuKongBase/WuKongBase.h>
#import "WKBotListVM.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKBotPlazaVM : NSObject

/// 请求AI广场Bot列表
-(AnyPromise*) requestBots;

@end

NS_ASSUME_NONNULL_END
