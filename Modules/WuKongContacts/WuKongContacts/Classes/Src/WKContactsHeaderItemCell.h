// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKContactsHeaderItemCell.h
//  WuKongContacts
//
//  Created by tt on 2020/1/4.
//

#import <UIKit/UIKit.h>
#import "WKContactsHeaderItem.h"
#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKContactsHeaderItemCell : WKCell

-(void)refresh:(WKContactsHeaderItem*)model;

@end

NS_ASSUME_NONNULL_END
