// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKGroupMdVC : WKBaseVC

@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,assign) BOOL canEdit;

@end

NS_ASSUME_NONNULL_END
