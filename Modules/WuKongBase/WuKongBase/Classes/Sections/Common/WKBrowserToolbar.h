// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKBrowserToolbar.h
//  WuKongBase
//
//  Created by tt on 2021/3/24.
//

#import <Foundation/Foundation.h>
#import <YBImageBrowser/YBImageBrowser.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKBrowserToolbar : NSObject<YBIBToolViewHandler>

@property(nonatomic,strong) YBImageBrowser *browser;

@end

NS_ASSUME_NONNULL_END
