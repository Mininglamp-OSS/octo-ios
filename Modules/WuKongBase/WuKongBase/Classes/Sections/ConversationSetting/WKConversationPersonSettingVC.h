// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConversationSettingVC.h
//  WuKongBase
//
//  Created by tt on 2020/1/20.
//

#import "WKBaseVC.h"
#import "WKBaseTableVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConversationSettingVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKConversationPersonSettingVC : WKBaseTableVC<WKConversationSettingVM*>

@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,weak) id<WKConversationContext> context;

@end

NS_ASSUME_NONNULL_END
