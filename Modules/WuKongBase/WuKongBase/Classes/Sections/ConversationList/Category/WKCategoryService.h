// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKCategoryService.h
//  WuKongBase
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>

@class WKCategoryEntity;

NS_ASSUME_NONNULL_BEGIN

@interface WKCategoryService : NSObject

+ (instancetype)shared;

/// 获取分组列表
- (AnyPromise *)listCategories:(NSString *)spaceId;

/// 创建分组
- (AnyPromise *)createCategory:(NSString *)spaceId name:(NSString *)name;

/// 重命名分组
- (AnyPromise *)renameCategory:(NSString *)spaceId categoryId:(NSString *)categoryId name:(NSString *)name;

/// 删除分组
- (AnyPromise *)deleteCategory:(NSString *)spaceId categoryId:(NSString *)categoryId;

/// 排序分组
- (AnyPromise *)sortCategories:(NSString *)spaceId categoryIds:(NSArray<NSString *> *)categoryIds;

/// 移动群聊到分组（categoryId 传空字符串表示移出分组）
- (AnyPromise *)moveGroup:(NSString *)groupNo toCategoryId:(nullable NSString *)categoryId;

/// 清除缓存（切换 Space 时调用）
- (void)invalidateCache;

@end

NS_ASSUME_NONNULL_END
