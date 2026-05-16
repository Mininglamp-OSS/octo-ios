// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKContactsVC.h
//  WuKongContacts
//
//  Created by tt on 2019/12/7.
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
#import "WKContacts.h"
NS_ASSUME_NONNULL_BEGIN

@protocol WKContactsDelegate <NSObject>

-(NSArray<WKContacts*>*) contactsData;

@end

@interface WKContactsVC : WKBaseVC

@property(nonatomic,weak) id<WKContactsDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
