// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSafeFilePreviewVC : WKBaseVC

+ (void)showFilePreview:(NSURL *)fileURL title:(NSString *)title;
+ (void)dismissPreview;

@end

NS_ASSUME_NONNULL_END
