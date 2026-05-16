// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  ATKitSearchController.h
//  WuKongBase
//
//  Created by tt on 2019/12/31.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSearchController : UISearchController

/**
 获取搜索的view
 
 @return <#return value description#>
 */
-(UIView*) searchBarView;

@end

NS_ASSUME_NONNULL_END
