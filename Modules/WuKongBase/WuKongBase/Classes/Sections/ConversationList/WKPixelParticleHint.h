// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKPixelParticleHint.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKPixelParticleHint : UIView

+ (void)showInView:(UIView *)parentView
         avatarURL:(nullable NSString *)avatarURL
              name:(NSString *)name
           content:(nullable NSString *)content
           onTap:(nullable void(^)(void))onTap;

+ (void)dismissCurrent;

@end

NS_ASSUME_NONNULL_END
