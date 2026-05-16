// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKDBRecoveryManager.m
//  TangSengDaoDao
//

#import "WKDBRecoveryManager.h"
#import <WuKongBase/WuKongBase.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface WKDBRecoveryManager ()
@property(nonatomic, assign) BOOL recovering;
@end

@implementation WKDBRecoveryManager

+ (instancetype)shared {
    static WKDBRecoveryManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [self new]; });
    return instance;
}

- (BOOL)isRecovering { return self.recovering; }

- (void)performRecoveryWithIMDBPath:(NSString *)imDBPath
                                uid:(NSString *)uid
                           progress:(WKDBRecoveryProgressBlock)progress
                         completion:(WKDBRecoveryCompletionBlock)completion {
    if (self.recovering) return;
    self.recovering = YES;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;

        void(^report)(float, NSString *) = ^(float p, NSString *step) {
            dispatch_async(dispatch_get_main_queue(), ^{ progress(p, step); });
        };

        report(0.05f, @"正在关闭数据库连接...");
        [self closeAllDBConnections];

        report(0.30f, @"正在清理损坏文件...");
        [self deleteDBFilesAtPath:imDBPath error:&error];
        if (error) { [self finishWithError:error completion:completion]; return; }

        NSString *kitDBPath = [self kitDBPathForUID:uid];
        [self deleteDBFilesAtPath:kitDBPath error:&error];
        if (error) { [self finishWithError:error completion:completion]; return; }

        report(0.65f, @"正在重建 IM 数据库...");
        [[WKDB sharedDB] switchDB:uid];

        report(0.85f, @"正在重建配置数据库...");
        [[WKKitDB shared] switchDB:uid];

        report(1.00f, @"验证完成");
        self.recovering = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, nil);
        });
    });
}

#pragma mark - private

- (void)closeAllDBConnections {
    [[WKDB sharedDB].dbQueue close];
    [[WKKitDB shared].dbQueue close];
}

- (NSString *)kitDBPathForUID:(NSString *)uid {
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    return [NSString stringWithFormat:@"%@/db/wukongkit_%@.db", docsDir, uid];
}

- (void)deleteDBFilesAtPath:(NSString *)basePath error:(NSError **)outError {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *suffixes = @[@"", @"-wal", @"-shm"];
    for (NSString *suffix in suffixes) {
        NSString *path = [basePath stringByAppendingString:suffix];
        if ([fm fileExistsAtPath:path]) {
            NSError *err = nil;
            [fm removeItemAtPath:path error:&err];
            if (err && outError) { *outError = err; return; }
        }
    }
}

- (void)finishWithError:(NSError *)error completion:(WKDBRecoveryCompletionBlock)completion {
    self.recovering = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(NO, error);
    });
}

@end
