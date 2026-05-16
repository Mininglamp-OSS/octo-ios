//
//  WKKitDB.h
//  WuKongBase
//
//  Created by tt on 2019/12/7.
//

#import <Foundation/Foundation.h>
#import <fmdb/FMDB.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKKitDBConfig: NSObject


/**
 数据库目录
 */
@property(nonatomic,strong) NSString* dbDir;


@end

@interface WKKitDB : NSObject

+ (instancetype)shared;

-(void) switchDB:(NSString*)uid;

@property (nonatomic, strong)FMDatabaseQueue *dbQueue;



/**
 db配置
 */
@property(nonatomic,strong) WKKitDBConfig *config;



/**
 创建表
 
 @param tableName 表名
 @param dic 字典类型 key为列明 value为列类型
 @param db db对象
 @return <#return value description#>
 */
- (BOOL)createTable:(NSString *)tableName dic:(NSDictionary*)dic db:(FMDatabase*)db;



/**
 插入数据
 
 @param tableName 表名
 @param parameters 参数为字典类型 key为列表名 value为对应的值
 @param db <#db description#>
 @return <#return value description#>
 */
- (BOOL)insertTable:(NSString *)tableName dic:(NSDictionary*)parameters db:(FMDatabase*)db;



/**
 批量插入数据
 
 @param tableName 表名
 @param db <#db description#>
 @param dicArray 参数为字典类型的数组 key为列名 value为对应的值
 @return <#return value description#>
 */
- (NSArray *)insertTable:(NSString *)tableName db:(FMDatabase*)db dicArray:(NSArray<NSDictionary*> *)dicArray;


/**
 根据条件删除表
 
 @param tableName 表名
 @param db <#db description#>
 @param format 条件限制
 @return <#return value description#>
 */
- (BOOL) deleteTable:(NSString *)tableName db:(FMDatabase*)db whereFormat:(NSString *)format, ...;


/**
 删除表数据
 
 @param tableName <#tableName description#>
 @param db <#db description#>
 @return <#return value description#>
 */
- (BOOL)deleteTable:(NSString *)tableName db:(FMDatabase*)db;


/**
 卸载表
 
 @param tableName <#tableName description#>
 @param db <#db description#>
 @return <#return value description#>
 */
- (BOOL)dropTable:(NSString *)tableName db:(FMDatabase*)db;


/**
 更新表
 
 @param tableName 表名
 @param db <#db description#>
 @param parameters 参数 key为列名 value为值
 @param format 条件限制
 @return <#return value description#>
 */
- (BOOL)updateTable:(NSString *)tableName db:(FMDatabase*)db dic:(NSDictionary*)parameters whereFormat:(NSString *)format, ...;


/**
 查询表
 
 @param tableName 表名
 @param db <#db description#>
 @param parameters 参数为字典类型时key为需要查询的列名 value可为空 返回的结果为字典数组 参数为Class类型时 返回Class对应的对象集合
 @param format <#format description#>
 @return <#return value description#>
 */
- (NSArray *)QueryTable:(NSString *)tableName db:(FMDatabase*)db param:(id)parameters whereFormat:(NSString *)format, ...;

- (NSArray<NSDictionary*> *)QueryTable:(NSString *)tableName db:(FMDatabase*)db whereFormat:(NSString *)format, ...;


/**
 查询单个对象
 
 @param tableName 表名
 @param db <#db description#>
 @param parameters 参数为字典类型时key为需要查询的列名 value可为空 返回的结果为字典类型 参数为Class类型时 返回Class对应的对象
 @param format <#format description#>
 @return <#return value description#>
 */
- (id)QueryTableFirst:(NSString *)tableName db:(FMDatabase*)db param:(id)parameters whereFormat:(NSString *)format, ...;

/**
 是否存在表
 
 @param tableName 表名
 @param db <#db description#>
 @return <#return value description#>
 */
- (BOOL)isExistTable:(NSString *)tableName db:(FMDatabase*)db;


/**
 查询表的数据量
 
 @param tableName <#tableName description#>
 @param db <#db description#>
 @return <#return value description#>
 */
-(NSNumber*)  queryCount:(NSString *)tableName db:(FMDatabase*)db;


/**
 

 @param tableName <#tableName description#>
 @param db <#db description#>
 @param format <#format description#>
 @return <#return value description#>
 */
-(NSNumber*)  queryCount:(NSString *)tableName db:(FMDatabase*)db whereFormat:(NSString *)format, ...;


@end


NS_ASSUME_NONNULL_END
