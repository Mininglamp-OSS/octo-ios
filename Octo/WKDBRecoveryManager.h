// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKDBRecoveryManager.h
//  Octo
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^WKDBRecoveryProgressBlock)(float progress, NSString *step);
typedef void(^WKDBRecoveryCompletionBlock)(BOOL success, NSError * _Nullable error);

@interface WKDBRecoveryManager : NSObject

+ (instancetype)shared;

@property(nonatomic, readonly) BOOL isRecovering;

/**
 执行数据库全量重置。
 删除 IM DB + Kit DB（含 WAL/SHM），然后重新调用 switchDB: 重建。
 必须在主线程调用，内部自动切到后台执行。
 */
- (void)performRecoveryWithIMDBPath:(NSString *)imDBPath
                                uid:(NSString *)uid
                           progress:(WKDBRecoveryProgressBlock)progress
                         completion:(WKDBRecoveryCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
