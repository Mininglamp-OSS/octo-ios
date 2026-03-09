//
//  WKDBaseDB.h
//  WuKongBase
//
//  Created by tt on 2019/12/7.
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>
#import "WKModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKDBaseDB : NSObject

/**
 插入model对象
 
 @param model model对象
 @param table 表名
 @return <#return value description#>
 */
-(AnyPromise*) insertModel:(WKModel*)model forTable:(NSString*)table;

-(AnyPromise*) insertModels:(NSArray<WKModel*>*)models forTable:(NSString*)table;

// 带事务的批量插入（一条失败全回滚，所有成功才会成功插入到数据库）
-(AnyPromise*) insertModelsOfTransaction:(NSArray<WKModel*>*)models forTable:(NSString*)table;


/**
 查询model对象
 
 @param modelClass 实现ATModel了的class
 @param table 表名
 @param format 筛选条件 比如 where name=@"xxxx"
 @return <#return value description#>
 */
-(AnyPromise*) queryModels:(Class)modelClass forTable:(NSString*)table whereFormat:(NSString *__nullable)format, ...;


/**
 查询单个model对象
 
 @param modelClass 实现ATModel了的class
 @param table 表名
 @param format 筛选条件 比如 where name=@"xxxx"
 @return <#return value description#>
 */
-(AnyPromise*) queryModel:(Class)modelClass forTable:(NSString*)table whereFormat:(NSString *__nullable)format, ...;

/**
 删除表里所有数据然后再插入新的models数据
 
 @param models models集合
 @param table 表名
 @return <#return value description#>
 */
-(AnyPromise*) deleteTableAndInsertModels:(NSArray<WKModel*>*)models forTable:(NSString*)table;


/**
 删除表
 
 @param table <#table description#>
 @return <#return value description#>
 */
-(AnyPromise*) deleteTable:(NSString*)table;


/**
 查询表的数据量
 
 @param table <#table description#>
 @return <#return value description#>
 */
-(AnyPromise*) queryCountForTable:(NSString*) table;
-(AnyPromise*) queryCountForTable:(NSString*) table whereFormat:(NSString *)format, ...;



/**
 字典转换为model集合

 @param resultDic <#resultDic description#>
 @param modelClass <#modelClass description#>
 @return <#return value description#>
 */
-(NSArray<WKModel*>*) dictToModels:(NSArray<NSDictionary*>*) resultDic class:(Class)modelClass;
-(WKModel*) dictToModel:(NSDictionary*) resultDic class:(Class)modelClass;
@end

NS_ASSUME_NONNULL_END
