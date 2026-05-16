// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKDBMigration.h
//  WuKongBase
//
//  Created by tt on 2019/12/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKDBMigration : NSObject

+ (instancetype)shared;

-(BOOL) migrateDatabase:(NSBundle*)bundle;

-(void) resetManager;

@end

NS_ASSUME_NONNULL_END
