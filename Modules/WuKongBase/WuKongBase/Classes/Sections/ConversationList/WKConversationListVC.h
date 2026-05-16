// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConversationListVC.h
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import <UIKit/UIKit.h>
#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationListVC : WKBaseVC

-(instancetype) initWithTitle:(NSString*)title;

-(void) setCustomTitle:(NSString*)title;
@end

NS_ASSUME_NONNULL_END
