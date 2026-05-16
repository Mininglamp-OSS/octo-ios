// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKReactionView.h
//  WuKongBase
//
//  Created by tt on 2021/9/13.
//

#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKReactionBaseView : UIView

@property(nonatomic,assign) NSInteger reactionNum;

-(void) render:(NSArray<WKReaction*>*) reactions;


@end

NS_ASSUME_NONNULL_END
