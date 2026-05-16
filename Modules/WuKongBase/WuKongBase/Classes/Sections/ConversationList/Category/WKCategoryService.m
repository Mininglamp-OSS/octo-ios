// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKCategoryService.m
//  WuKongBase
//

#import "WKCategoryService.h"
#import "WKCategoryEntity.h"
#import "WKAPIClient.h"

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
        return list;
    });
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
