//
//  WKCategoryService.m
//  WuKongBase
//

#import "WKCategoryService.h"
#import "WKCategoryEntity.h"
#import "WKAPIClient.h"
#import "WKSpaceDiskCache.h"
#import "WKConvListCache.h"

/// 磁盘缓存 namespace（文件名前缀）
static NSString * const kWKCategoryCacheNamespace = @"categories";

@interface WKCategoryService ()
@property (nonatomic, strong, nullable) NSArray<WKCategoryEntity *> *cachedCategories;
@property (nonatomic, copy, nullable) NSString *cachedSpaceId;
@end

@implementation WKCategoryService

+ (instancetype)shared {
    static WKCategoryService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKCategoryService alloc] init];
    });
    return instance;
}

- (AnyPromise *)listCategories:(NSString *)spaceId {
    NSString *path = [NSString stringWithFormat:@"spaces/%@/categories", spaceId];
    return [[WKAPIClient sharedClient] GET:path parameters:@{}].then(^(NSArray *results) {
        NSArray<WKCategoryEntity *> *list = [WKCategoryEntity fromDictArray:results];
        self.cachedCategories = list;
        self.cachedSpaceId = spaceId;
        // 落盘服务端原始 JSON（不是 entity）—— 回读直接走 fromDictArray:，
        // 不需要给 entity 加一套序列化，字段增删也自动跟随服务端。
        if ([results isKindOfClass:[NSArray class]]) {
            [WKSpaceDiskCache setObject:results forNamespace:kWKCategoryCacheNamespace spaceId:spaceId];
        }
        return list;
    });
}

/// 同步读磁盘缓存。切空间 / 冷启动时用来立即 seed VM.categoryList ——
/// 否则 buildGroupDisplayList 拿不到分组结构，关注 tab 连 section header 都没有，
/// 要等 categories 接口回来才有内容。
- (nullable NSArray<WKCategoryEntity *> *)cachedCategoriesForSpace:(NSString *)spaceId {
    if (spaceId.length == 0) return nil;
    // 内存缓存命中同一空间时直接用（避免重复解析）
    if (self.cachedCategories && [self.cachedSpaceId isEqualToString:spaceId]) {
        return self.cachedCategories;
    }
    if (![WKConvListCache enabled]) return nil;
    id cached = [WKSpaceDiskCache objectForNamespace:kWKCategoryCacheNamespace spaceId:spaceId];
    if (![cached isKindOfClass:[NSArray class]]) return nil;
    NSArray<WKCategoryEntity *> *list = [WKCategoryEntity fromDictArray:(NSArray *)cached];
    NSLog(@"[CategoryCache] hydrate space=%@ count=%lu", spaceId, (unsigned long)list.count);
    return list;
}

- (AnyPromise *)createCategory:(NSString *)spaceId name:(NSString *)name {
    NSString *path = [NSString stringWithFormat:@"spaces/%@/categories", spaceId];
    NSDictionary *params = @{@"name": name};
    return [[WKAPIClient sharedClient] POST:path parameters:params].then(^(NSDictionary *result) {
        [self invalidateCache];
        return [WKCategoryEntity fromDict:result];
    });
}

- (AnyPromise *)renameCategory:(NSString *)spaceId categoryId:(NSString *)categoryId name:(NSString *)name {
    NSString *path = [NSString stringWithFormat:@"spaces/%@/categories/%@", spaceId, categoryId];
    NSDictionary *params = @{@"name": name};
    return [[WKAPIClient sharedClient] PUT:path parameters:params].then(^(id result) {
        [self invalidateCache];
        return result;
    });
}

- (AnyPromise *)deleteCategory:(NSString *)spaceId categoryId:(NSString *)categoryId {
    NSString *path = [NSString stringWithFormat:@"spaces/%@/categories/%@", spaceId, categoryId];
    return [[WKAPIClient sharedClient] DELETE:path parameters:@{}].then(^(id result) {
        [self invalidateCache];
        return result;
    });
}

- (AnyPromise *)sortCategories:(NSString *)spaceId categoryIds:(NSArray<NSString *> *)categoryIds {
    NSString *path = [NSString stringWithFormat:@"spaces/%@/categories/sort", spaceId];
    NSDictionary *params = @{@"category_ids": categoryIds};
    return [[WKAPIClient sharedClient] PUT:path parameters:params].then(^(id result) {
        [self invalidateCache];
        return result;
    });
}

- (AnyPromise *)moveGroup:(NSString *)groupNo toCategoryId:(nullable NSString *)categoryId {
    NSString *path = [NSString stringWithFormat:@"groups/%@/category", groupNo];
    NSDictionary *params = @{@"category_id": categoryId ?: @""};
    return [[WKAPIClient sharedClient] PUT:path parameters:params].then(^(id result) {
        [self invalidateCache];
        return result;
    });
}

- (void)invalidateCache {
    self.cachedCategories = nil;
    self.cachedSpaceId = nil;
}

@end
