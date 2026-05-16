//
//  WKDBaseDB.m
//  WuKongBase
//
//  Created by tt on 2019/12/7.
//

#import "WKDBaseDB.h"
#import "WKModel.h"
#import "WKKitDB.h"
@implementation WKDBaseDB


-(AnyPromise*) insertModel:(WKModel*)model forTable:(NSString*)table {
    if(!model) [NSException exceptionWithName:NSInternalInconsistencyException reason:@"model is nil" userInfo:nil];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [[[WKKitDB shared] dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
            BOOL isSuccess = [[WKKitDB shared] insertTable:table dic:[model toMap:ModelMapTypeDB] db:db];
            if(isSuccess) {
                resolve(@(isSuccess));
            }else{
                resolve([NSError errorWithDomain:[NSString stringWithFormat:@"[%@]插入错误!",model.class] code:0 userInfo:nil]);
            }
        }];
    }];
}

-(AnyPromise*) deleteTableAndInsertModels:(NSArray<WKModel*>*)models forTable:(NSString*)table{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        WKKitDB *atdb = [WKKitDB shared];
        [[atdb dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
            if ([atdb deleteTable:table db:db]){
                NSArray *array = [atdb insertTable:table db:db dicArray:[self modelsToArrayDics:models]];
                if(!array || array.count<=0) {
                    resolve(@(true));
                }else{
                    resolve([NSError errorWithDomain:[NSString stringWithFormat:@"[%lu条数据]插入错误!",(unsigned long)array.count] code:0 userInfo:@{@"array":array}]);
                }
            }
        }];
    }];
}

-(AnyPromise*) deleteTable:(NSString*)table{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        WKKitDB *atdb = [WKKitDB shared];
        [[atdb dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
            BOOL success = [atdb deleteTable:table db:db];
            if(success) {
                resolve(@(true));
            }else{
                resolve([NSError errorWithDomain:@"删除失败" code:0 userInfo:nil]);
            }
        }];
    }];
}

-(AnyPromise*) insertModels:(NSArray<WKModel*>*)models forTable:(NSString*)table{
    if(!models || models.count<=0) [NSException exceptionWithName:NSInternalInconsistencyException reason:@"models is nil or <=0 " userInfo:nil];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [[[WKKitDB shared] dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
            NSMutableArray *dicts = [NSMutableArray array];
            for(WKModel *model in models) {
                [dicts addObject:[model toMap:ModelMapTypeDB]];
            }
            NSArray *array = [[WKKitDB shared] insertTable:table db:db dicArray:dicts];
            if(!array || array.count<=0) {
                resolve(@(true));
            }else{
                resolve([NSError errorWithDomain:[NSString stringWithFormat:@"[%lu条数据]插入错误!",(unsigned long)array.count] code:0 userInfo:@{@"array":array}]);
            }
        }];
    }];
}

-(AnyPromise*) insertModelsOfTransaction:(NSArray<WKModel*>*)models forTable:(NSString*)table{
    if(!models || models.count<=0) [NSException exceptionWithName:NSInternalInconsistencyException reason:@"models is nil or <=0 " userInfo:nil];
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [[[WKKitDB shared] dbQueue] inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
            NSMutableArray *dicts = [NSMutableArray array];
            for(WKModel *model in models) {
                [dicts addObject:[model toMap:ModelMapTypeDB]];
            }
            NSArray *array = [[WKKitDB shared] insertTable:table db:db dicArray:dicts];
            if(!array || array.count<=0) {
                resolve(@(true));
            }else{
                *rollback = true;
                resolve([NSError errorWithDomain:[NSString stringWithFormat:@"[%lu条数据]插入错误,全部回滚!",(unsigned long)array.count] code:0 userInfo:@{@"array":array}]);
            }
        }];
    }];
}

-(NSArray<NSDictionary*>*) modelsToArrayDics:(NSArray<WKModel*>*)models {
    NSMutableArray<NSDictionary*> *dicts = [NSMutableArray array];
    if(models) {
        for(WKModel *model in models) {
            [dicts addObject:[model toMap:ModelMapTypeDB]];
        }
    }
    return dicts;
}

-(AnyPromise*) queryModels:(Class)modelClass forTable:(NSString*)table whereFormat:(NSString *)format, ...{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [[[WKKitDB shared] dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
            
            NSArray<NSDictionary*> *resultDic = [[WKKitDB shared] QueryTable:table db:db whereFormat:where];
            NSMutableArray *modelList = [[NSMutableArray alloc] init];
            IMP imp = [self getModelFromMapTypeSel:modelClass];
            if(imp) {
                WKModel* (*convertMap)(id, SEL,NSDictionary*,ModelMapType) = (void *)imp;
                if(resultDic&&resultDic.count>0) {
                    SEL sel = NSSelectorFromString(@"fromMap:type:");
                    for (NSDictionary *dic in resultDic) {
                        WKModel *model = convertMap(modelClass,sel,dic,ModelMapTypeDB);
                        [modelList addObject:model];
                    }
                }
            }
            resolve(modelList);
        }];
    }];
}

-(AnyPromise*) queryModel:(Class)modelClass forTable:(NSString*)table whereFormat:(NSString *)format, ...{
    va_list args;
    va_start(args, format);
    NSString *where = format?[[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:args]:format;
    va_end(args);
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [[[WKKitDB shared] dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
            
            NSArray<NSDictionary*> *resultDic = [[WKKitDB shared] QueryTable:table db:db whereFormat:where];
            WKModel *model;
            IMP imp = [self getModelFromMapTypeSel:modelClass];
            if(imp) {
                WKModel* (*convertMap)(id, SEL,NSDictionary*,ModelMapType) = (void *)imp;
                if(resultDic&&resultDic.count>0) {
                    SEL sel = NSSelectorFromString(@"fromMap:type:");
                    NSDictionary *dic = resultDic[0];
                    model = convertMap(modelClass,sel,dic,ModelMapTypeDB);
                }
            }
            resolve(model);
        }];
    }];
}

-(NSArray<WKModel*>*) dictToModels:(NSArray<NSDictionary*>*) resultDic class:(Class)modelClass {
    NSMutableArray *modelList = [[NSMutableArray alloc] init];
    IMP imp = [self getModelFromMapTypeSel:modelClass];
    if(imp) {
        WKModel* (*convertMap)(id, SEL,NSDictionary*,ModelMapType) = (void *)imp;
        if(resultDic&&resultDic.count>0) {
            SEL sel = NSSelectorFromString(@"fromMap:type:");
            for (NSDictionary *dic in resultDic) {
                WKModel *model = convertMap(modelClass,sel,dic,ModelMapTypeDB);
                [modelList addObject:model];
            }
        }
    }
    return modelList;
}
-(WKModel*) dictToModel:(NSDictionary*) resultDic class:(Class)modelClass {
    IMP imp = [self getModelFromMapTypeSel:modelClass];
    if(imp) {
        WKModel* (*convertMap)(id, SEL,NSDictionary*,ModelMapType) = (void *)imp;
        if(resultDic) {
            SEL sel = NSSelectorFromString(@"fromMap:type:");
            WKModel *model = convertMap(modelClass,sel,resultDic,ModelMapTypeDB);
            return model;
        }
    }
    return nil;
}

-(AnyPromise*) queryCountForTable:(NSString*) table {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [[[WKKitDB shared] dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
            NSNumber *count = [[WKKitDB shared] queryCount:table db:db];
            resolve(count);
        }];
    }];
}
-(AnyPromise*) queryCountForTable:(NSString*) table whereFormat:(NSString *)format, ...{
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        [[[WKKitDB shared] dbQueue] inDatabase:^(FMDatabase * _Nonnull db) {
            NSNumber *count = [[WKKitDB shared] queryCount:table db:db whereFormat:format];
            resolve(count);
        }];
    }];
}

-(IMP) getModelFromMapTypeSel:(Class)modelClass {
    if ([modelClass respondsToSelector:@selector(fromMap:type:)]){
        SEL sel = NSSelectorFromString(@"fromMap:type:");
        IMP imp = [modelClass methodForSelector:sel];
        return imp;
    }
    return nil;
}

@end
