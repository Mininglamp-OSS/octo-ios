// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKStickerBigViewModal.h
//  WuKongBase
//
//  Created by tt on 2021/10/20.
//

#import <Foundation/Foundation.h>
#import <SDWebImage/SDWebImage.h>
#import "WKStickerPackage.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKStickerBigViewModal : NSObject

@property(nonatomic,strong) NSString *path;

+(WKStickerBigViewModal*) focusedView:(UIView*)focusedView sticker:(WKSticker*)sticker;

-(void) presentOnWindow:(UIWindow*)window;

@end

NS_ASSUME_NONNULL_END
