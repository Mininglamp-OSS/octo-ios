//
//  WKDBMigration.m
//  WuKongBase
//
//  Created by tt on 2019/12/7.
//

#import "WKDBMigration.h"
#import "WKLogs.h"
#import "FMDBMigrationManager.h"
#import "WKKitDB.h"
@implementation WKDBMigration


static WKDBMigration *_instance = nil;

static FMDBMigrationManager *_manager;

+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(void) createMigrationsTable{
    [[[WKKitDB shared] dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
        _manager = [FMDBMigrationManager managerWithDatabase:db];
        if(![_manager hasMigrationsTable]) {
            NSError *error;
            [_manager createMigrationsTable:&error];
            if(error) {
                WKLogError(@"createMigrationsTable is error 【%@】",error);
            }
        }
    }];
}


-(BOOL) migrateDatabase:(NSBundle*)bundle{
    if(!_manager) {
        [self createMigrationsTable];
    }
    NSError *error;
    [_manager migrateDatabase:bundle error:&error];
    if(error) {
        WKLogError(@"migrateDatabaseToVersion is error 【%@】",error);
        return NO;
    }
    return YES;
}

-(void) resetManager {
    _manager = nil;
}

@end
