// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKGlobalSearchController.h
//  WuKongBase
//
//  Created by tt on 2020/4/24.
//

#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKGlobalSearchController : UISearchController

+(instancetype) searchController;

-(void) refreshSearchbar;


@end

NS_ASSUME_NONNULL_END
