//
//  WKDB.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import "WKDB.h"
#import "WKSDK.h"
#import "WKDBMigrationManager.h"
#import <objc/runtime.h>

// 数据库中常见的几种类型
#define SQL_TEXT     @"TEXT" //文本
#define SQL_INTEGER  @"INTEGER" //int long integer ...
#define SQL_REAL     @"REAL" //浮点
#define SQL_BLOB     @"BLOB" //data

@interface WKDB ()
// 当前数据库的uid
@property(nonatomic,copy) NSString *currentUid;
// 当前db前缀
@property(nonatomic,copy) NSString *currentDBPrefix;

@end
@implementation WKDB

static WKDB *_instance;

static WKDBMigrationManager *_manager;

+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKDB *)sharedDB
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(BOOL) needSwitchDB:(NSString*)uid {
    NSString *dbPrefix = [WKSDK shared].options.dbPrefix;
    if(![dbPrefix isEqualToString:_currentDBPrefix]) {
        if(self.currentUid && ![self.currentUid isEqualToString:@""] && [self.currentUid isEqualToString:uid]) {
               return false;
           }
    }
   self.currentDBPrefix = dbPrefix;
    return true;
}

-(void) switchDB:(NSString*)uid {
    self.currentUid = uid;
    if(self.dbQueue) {
        [self.dbQueue close];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
   BOOL isExist = [fileManager fileExistsAtPath: [WKSDK shared].options.dbDir];
    if(!isExist) {
        NSError *error;
        if (![fileManager createDirectoryAtPath:[WKSDK shared].options.dbDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"creat Directory Failed:%@",[error localizedDescription]);
        }
    }
    NSString *dbPath = [NSString stringWithFormat:@"%@/%@%@.db",[WKSDK shared].options.dbDir,[WKSDK shared].options.dbPrefix,uid];
    if([WKSDK shared].isDebug) {
        NSLog(@"数据库路径 -> %@",dbPath);
    }
    
    NSString *dbKey = uid;
    
    
//    [WKFMEncryptHelper shared].encryptKey = dbKey;
//    [[WKFMEncryptHelper shared] unEncryptDatabase:dbPath targetPath:[NSString stringWithFormat:@"%@.tmp.db",dbPath]];
//
    
    FMDatabaseQueue *fmdb = [FMDatabaseQueue databaseQueueWithPath:dbPath];
  
    self.dbQueue = [WKFMDatabaseQueue databaseQueue:fmdb] ;
    [self.dbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        [db setKeyWithData:[dbKey dataUsingEncoding:NSUTF8StringEncoding]];
//        [db setKey:uid];
    }];
    // 合并数据库
    [self migrateDatabase];
}
-(void) createMigrationsTable{
    [[self dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
        _manager = [WKDBMigrationManager managerWithDatabase:db];
         if(![_manager hasMigrationsTable]) {
             NSError *error;
             [_manager createMigrationsTable:&error];
             if(error) {
                  NSLog(@"createMigrationsTable is error 【%@】",error);
             }
         }
    }];
}
-(BOOL) migrateDatabase{
   [self createMigrationsTable];
    NSError *error;
    [_manager migrateDatabase:[self resourceBundle] error:&error];
    if(error) {
        NSLog(@"migrateDatabaseToVersion is error 【%@】",error);
        return NO;
    }
    return YES;
}

- (NSBundle*) resourceBundle{
    NSURL *url = [self module_bundleUrl:[NSString stringWithFormat:@"WuKongIMSDK"]  cls:[self class]];
     return [NSBundle bundleWithURL:url];
}

- (NSURL *)module_bundleUrl:(NSString*)podName  cls:(Class) cls {
    NSBundle *bundle = [NSBundle bundleForClass:cls];
    NSLog(@"bundle-->%@",bundle.bundlePath);
    NSURL *url = [bundle URLForResource:podName withExtension:@"bundle"];
    return url;
}


- (BOOL)createTable:(NSString *)tableName dic:(NSDictionary*)dic db:(FMDatabase*)db
{
    return [self createTable:tableName dic:dic excludeName:nil db:db];
}

- (BOOL)createTable:(NSString *)tableName dic:(NSDictionary*)dic excludeName:(NSArray *)nameArr db:(FMDatabase*)db
{
    
    
    NSMutableString *fieldStr = [[NSMutableString alloc] initWithFormat:@"CREATE TABLE %@ (pkid  INTEGER PRIMARY KEY,", tableName];
    
    int keyCount = 0;
    for (NSString *key in dic) {
        
        keyCount++;
        if ((nameArr && [nameArr containsObject:key]) || [key isEqualToString:@"pkid"]) {
            continue;
        }
        if (keyCount == dic.count) {
            [fieldStr appendFormat:@" %@ %@)", key, dic[key]];
            break;
        }
        
        [fieldStr appendFormat:@" %@ %@,", key, dic[key]];
    }
    
    BOOL creatFlag;
    creatFlag = [db executeUpdate:fieldStr];
    
    return creatFlag;
}


- (NSString *)createTable:(NSString *)tableName model:(Class)cls excludeName:(NSArray *)nameArr
{
    NSMutableString *fieldStr = [[NSMutableString alloc] initWithFormat:@"CREATE TABLE %@ (pkid INTEGER PRIMARY KEY,", tableName];
    
    NSDictionary *dic = [self modelToDictionary:cls excludePropertyName:nameArr];
    int keyCount = 0;
    for (NSString *key in dic) {
        
        keyCount++;
        
        if ([key isEqualToString:@"pkid"]) {
            continue;
        }
        if (keyCount == dic.count) {
            [fieldStr appendFormat:@" %@ %@)", key, dic[key]];
            break;
        }
        
        [fieldStr appendFormat:@" %@ %@,", key, dic[key]];
    }
    
    return fieldStr;
}

#pragma mark - *************** runtime
- (NSDictionary *)modelToDictionary:(Class)cls excludePropertyName:(NSArray *)nameArr
{
    NSMutableDictionary *mDic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList(cls, &outCount);
    for (int i = 0; i < outCount; i++) {
        
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        if ([nameArr containsObject:name]) continue;
        
        NSString *type = [NSString stringWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
        
        id value = [self propertTypeConvert:type];
        if (value) {
            [mDic setObject:value forKey:name];
        }
        
    }
    free(properties);
    
    return mDic;
}

// 获取model的key和value
- (NSDictionary *)getModelPropertyKeyValue:(id)model tableName:(NSString *)tableName clomnArr:(NSArray *)clomnArr
{
    NSMutableDictionary *mDic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([model class], &outCount);
    
    for (int i = 0; i < outCount; i++) {
        
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        if (![clomnArr containsObject:name]) {
            continue;
        }
        
        id value = [model valueForKey:name];
        if (value) {
            [mDic setObject:value forKey:name];
        }
    }
    free(properties);
    
    return mDic;
}

- (NSString *)propertTypeConvert:(NSString *)typeStr
{
    NSString *resultStr = nil;
    if ([typeStr hasPrefix:@"T@\"NSString\""]) {
        resultStr = SQL_TEXT;
    } else if ([typeStr hasPrefix:@"T@\"NSData\""]) {
        resultStr = SQL_BLOB;
    } else if ([typeStr hasPrefix:@"Ti"]||[typeStr hasPrefix:@"TI"]||[typeStr hasPrefix:@"Ts"]||[typeStr hasPrefix:@"TS"]||[typeStr hasPrefix:@"T@\"NSNumber\""]||[typeStr hasPrefix:@"TB"]||[typeStr hasPrefix:@"Tq"]||[typeStr hasPrefix:@"TQ"]) {
        resultStr = SQL_INTEGER;
    } else if ([typeStr hasPrefix:@"Tf"] || [typeStr hasPrefix:@"Td"]){
        resultStr= SQL_REAL;
    }
    
    return resultStr;
}

// 得到表里的字段名称
- (NSArray *)getColumnArr:(NSString *)tableName db:(FMDatabase *)db
{
    NSMutableArray *mArr = [NSMutableArray arrayWithCapacity:0];
    
    FMResultSet *resultSet = [db getTableSchema:tableName];
    
    while ([resultSet next]) {
        [mArr addObject:[resultSet stringForColumn:@"name"]];
    }
    
    return mArr;
}

#pragma mark - *************** 增删改查
- (BOOL)insertTable:(NSString *)tableName dic:(NSDictionary*)parameters db:(FMDatabase*)db
{
    NSArray *columnArr = [self getColumnArr:tableName db:db];
    return [self insertTable:tableName dic:parameters columnArr:columnArr db:db];
}
- (BOOL) insertTable:(NSString *)tableName dic:(NSDictionary*)parameters columnArr:(NSArray *)columnArr db:(FMDatabase*)db
{
    NSDictionary *dic = parameters;
    BOOL flag;
    
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"INSERT INTO %@ (", tableName];
    NSMutableString *tempStr = [NSMutableString stringWithCapacity:0];
    NSMutableArray *argumentsArr = [NSMutableArray arrayWithCapacity:0];
    for (NSString *key in dic) {
        if (![columnArr containsObject:key]) {
            continue;
        }
        [finalStr appendFormat:@"%@,", key];
        [tempStr appendString:@"?,"];
        [argumentsArr addObject:dic[key]];
    }
    [finalStr deleteCharactersInRange:NSMakeRange(finalStr.length-1, 1)];
    if (tempStr.length)
        [tempStr deleteCharactersInRange:NSMakeRange(tempStr.length-1, 1)];
    [finalStr appendFormat:@") values (%@)", tempStr];
    
    flag = [db executeUpdate:finalStr withArgumentsInArray:argumentsArr];
    return flag;
    
}

// 直接传一个array插入
- (NSArray *)insertTable:(NSString *)tableName db:(FMDatabase*)db dicArray:(NSArray<NSDictionary*> *)dicArray {
    int errorIndex = 0;
    NSMutableArray *resultMArr = [NSMutableArray arrayWithCapacity:0];
    NSArray *columnArr = [self getColumnArr:tableName db:db];
    for (NSDictionary *parameters in dicArray) {
        
        BOOL flag = [self insertTable:tableName dic:parameters columnArr:columnArr db:db];
        if (!flag) {
            [resultMArr addObject:@(errorIndex)];
        }
        errorIndex++;
    }
    
    return resultMArr;
}



- (BOOL) deleteTable:(NSString *)tableName db:(FMDatabase*)db whereFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    BOOL flag;
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"delete from %@  %@", tableName,where];
    flag = [db executeUpdate:finalStr];
    
    return flag;
}

- (BOOL)deleteTable:(NSString *)tableName db:(FMDatabase*)db
{
    
    NSString *sqlstr = [NSString stringWithFormat:@"DELETE FROM %@", tableName];
    if (![db executeUpdate:sqlstr])
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)dropTable:(NSString *)tableName db:(FMDatabase*)db
{
    
    NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tableName];
    if (![db executeUpdate:sqlstr])
    {
        return NO;
    }
    return YES;
}

- (BOOL)updateTable:(NSString *)tableName db:(FMDatabase*)db dic:(NSDictionary*)parameters whereFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    BOOL flag;
    NSDictionary *dic;
    NSArray *clomnArr = [self getColumnArr:tableName db:db];
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        dic = parameters;
    }else {
        dic = [self getModelPropertyKeyValue:parameters tableName:tableName clomnArr:clomnArr];
    }
    
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"update %@ set ", tableName];
    NSMutableArray *argumentsArr = [NSMutableArray arrayWithCapacity:0];
    
    for (NSString *key in dic) {
        
        if (![clomnArr containsObject:key] || [key isEqualToString:@"pkid"]) {
            continue;
        }
        [finalStr appendFormat:@"%@ = %@,", key, @"?"];
        [argumentsArr addObject:dic[key]];
    }
    
    [finalStr deleteCharactersInRange:NSMakeRange(finalStr.length-1, 1)];
    if (where.length) [finalStr appendFormat:@" %@", where];
    
    
    flag =  [db executeUpdate:finalStr withArgumentsInArray:argumentsArr];
    
    return flag;
}

- (NSArray<NSDictionary*> *)QueryTable:(NSString *)tableName db:(FMDatabase*)db whereFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"select * from %@ %@", tableName, where?where:@""];
    NSArray *clomnArr = [self getColumnArr:tableName db:db];
    FMResultSet *set = [db executeQuery:finalStr];
    NSMutableArray *resultArray = [NSMutableArray array];
    if(clomnArr) {
        while ([set next]) {
            NSMutableDictionary *rowDic = [[NSMutableDictionary alloc] init];
            for (NSString *name in clomnArr) {
                id value = [set objectForColumnName:name];
                [rowDic setObject:value forKey:name];
            }
            [resultArray addObject:rowDic];
        }
        
    }
    return resultArray;
}

- (NSArray *)QueryTable:(NSString *)tableName db:(FMDatabase*)db param:(id)parameters whereFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    
    NSMutableArray *resultMArr = [NSMutableArray arrayWithCapacity:0];
    NSDictionary *dic;
    NSMutableString *finalStr = [[NSMutableString alloc] initWithFormat:@"select * from %@ %@", tableName, where?where:@""];
    NSArray *clomnArr = [self getColumnArr:tableName db:db];
    
    FMResultSet *set = [db executeQuery:finalStr];
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        dic = parameters;
        
        while ([set next]) {
            NSMutableDictionary *resultDic = [NSMutableDictionary dictionaryWithCapacity:0];
            for (NSString *key in dic) {
                
                if ([dic[key] isEqualToString:SQL_TEXT]) {
                    id value = [set stringForColumn:key];
                    if (value)
                        [resultDic setObject:value forKey:key];
                } else if ([dic[key] isEqualToString:SQL_INTEGER]) {
                    [resultDic setObject:@([set longLongIntForColumn:key]) forKey:key];
                } else if ([dic[key] isEqualToString:SQL_REAL]) {
                    [resultDic setObject:[NSNumber numberWithDouble:[set doubleForColumn:key]] forKey:key];
                } else if ([dic[key] isEqualToString:SQL_BLOB]) {
                    id value = [set dataForColumn:key];
                    if (value)
                        [resultDic setObject:value forKey:key];
                }
            }
            if (resultDic) [resultMArr addObject:resultDic];
        }
        
    }else{
        Class CLS;
        if ([parameters isKindOfClass:[NSString class]]) {
            if (!NSClassFromString(parameters)) {
                CLS = nil;
            } else {
                CLS = NSClassFromString(parameters);
            }
        } else if ([parameters isKindOfClass:[NSObject class]]) {
            CLS = [parameters class];
        } else {
            CLS = parameters;
        }
        if (CLS) {
            NSDictionary *propertyType = [self modelToDictionary:CLS excludePropertyName:nil];
            
            while ([set next]) {
                
                id model = CLS.new;
                for (NSString *name in clomnArr) {
                    if ([propertyType[name] isEqualToString:SQL_TEXT]) {
                        id value = [set stringForColumn:name];
                        if (value)
                            [model setValue:value forKey:name];
                    } else if ([propertyType[name] isEqualToString:SQL_INTEGER]) {
                        [model setValue:@([set longLongIntForColumn:name]) forKey:name];
                    } else if ([propertyType[name] isEqualToString:SQL_REAL]) {
                        [model setValue:[NSNumber numberWithDouble:[set doubleForColumn:name]] forKey:name];
                    } else if ([propertyType[name] isEqualToString:SQL_BLOB]) {
                        id value = [set dataForColumn:name];
                        if (value)
                            [model setValue:value forKey:name];
                    }
                }
                
                [resultMArr addObject:model];
            }
        }
    }
    return resultMArr;
}

- (id)QueryTableFirst:(NSString *)tableName db:(FMDatabase*)db param:(id)parameters whereFormat:(NSString *)format, ...{
    
    NSArray *dataArray = [self QueryTable:tableName db:db param:parameters whereFormat:format];
    if(dataArray && [dataArray count]>0) {
        return dataArray[0];
    }
    return nil;
}

-(NSNumber*)  queryCount:(NSString *)tableName db:(FMDatabase*)db{
    FMResultSet *set = [db executeQuery:[NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@",tableName]];
    NSInteger count=0;
    while ([set next])
    {
        count = [set intForColumn:@"count"];
    }
    return @(count);
}

- (BOOL)isExistTable:(NSString *)tableName db:(FMDatabase*)db
{
    
    FMResultSet *set = [db executeQuery:@"SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and name = ?", tableName];
    while ([set next])
    {
        NSInteger count = [set intForColumn:@"count"];
        if (count == 0) {
            return NO;
        } else {
            return YES;
        }
    }
    return NO;
}

@end
