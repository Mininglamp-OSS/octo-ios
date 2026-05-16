// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKLogicView.h
//  WuKongLogin
//
//  Created by tt on 2019/12/2.
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN

typedef void(^onLogin)(NSString*mobile,NSString*password,NSString *country);
@interface WKLoginView : UIView

@property(nonatomic,copy) onLogin onLogin;

@property(nonatomic,strong) NSString *country;
@property(nonatomic,strong) NSString *mobile;

- (void)viewConfigChange:(WKViewConfigChangeType)type;

// Refresh the Aegis SSO entry based on the current `WKAppRemoteConfig.oidcProviders`.
// Safe to call before the button has been laid out; it builds the button lazily when
// providers arrive and hides it when the list is empty.
- (void)refreshOidcProviders;
@end

NS_ASSUME_NONNULL_END
