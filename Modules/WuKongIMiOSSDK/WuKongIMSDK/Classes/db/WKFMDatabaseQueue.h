//
//  WKFMDatabaseQueue.h
//  WuKongIMSDK
//
//  Created by tt on 2021/8/26.
//

#import <fmdb/FMDB.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKFMDatabaseQueue : NSObject


+(WKFMDatabaseQueue*) databaseQueue:(FMDatabaseQueue*)queue;


- (void)inDatabase:(void (NS_NOESCAPE^)(FMDatabase * _Nonnull db))block;

- (void)inTransaction:(__attribute__((noescape)) void (^)(FMDatabase *db, BOOL *rollback))block;

-(void) close;

@end

NS_ASSUME_NONNULL_END
