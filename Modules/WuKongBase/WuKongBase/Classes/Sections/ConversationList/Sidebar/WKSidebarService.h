// SPDX-License-Identifier: Apache-2.0
// Copyright (c) MININGLAMP. All rights reserved.
//
//  WKSidebarService.h
//  WuKongBase
//
//  POST /v1/sidebar/sync — 关注/最近 双 tab 数据源（DM/群/子区 + category_id + follow_sort）。
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>

@class WKSidebarItemEntity;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKSidebarTab) {
    WKSidebarTabFollow = 0,
    WKSidebarTabRecent = 1,
};

@interface WKSidebarSyncResponse : NSObject
@property (nonatomic, strong) NSArray<WKSidebarItemEntity *> *items;
/// IM 增量同步游标
@property (nonatomic, assign) int64_t version;
/// 关注 CAS 锚点
@property (nonatomic, assign) NSInteger follow_version;
+ (instancetype)fromDict:(NSDictionary *)dict;
@end

@interface WKSidebarService : NSObject

+ (instancetype)shared;

/// 同步会话边栏数据。首次/全量同步：version=0, lastMsgSeqs=@""
/// @param tab follow / recent
- (AnyPromise *)syncWithTab:(WKSidebarTab)tab
                    version:(int64_t)version
               lastMsgSeqs:(NSString *)lastMsgSeqs
                 deviceUUID:(NSString *)deviceUUID;

@end

NS_ASSUME_NONNULL_END
