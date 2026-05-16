// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKLoginPhoneCheckVC.h
//  WuKongLogin
//
//  Created by tt on 2020/10/26.
//

#import <WuKongBase/WuKongBase.h>
#import "WKLoginPhoneCheckVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKLoginPhoneCheckVC : WKBaseTableVC<WKLoginPhoneCheckVM*>

@property(nonatomic,copy) NSString *phone;
@property(nonatomic,copy) NSString *uid;

@end

NS_ASSUME_NONNULL_END
