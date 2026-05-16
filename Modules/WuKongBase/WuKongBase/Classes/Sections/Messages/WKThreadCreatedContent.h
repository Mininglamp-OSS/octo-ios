// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKThreadCreatedContent.h
//  WuKongBase
//

#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKThreadCreatedContent : WKMessageContent

@property (nonatomic, copy)   NSString *threadName;
@property (nonatomic, copy)   NSString *threadShortId;
@property (nonatomic, copy)   NSString *threadChannelId;
@property (nonatomic, assign) uint8_t   threadChannelType;
@property (nonatomic, copy)   NSString *creatorUid;
@property (nonatomic, copy)   NSString *creatorName;
@property (nonatomic, assign) NSInteger messageCount;
@property (nonatomic, copy, nullable) NSString *sourceMessageId;

/// 已创建子区的源消息ID集合（用于判断消息是否已创建过子区）
+ (NSMutableSet<NSString *> *)sourceMessageIdSet;

/// 源消息ID → 子区信息映射（用于在源消息 cell 内绘制子区指示条）
+ (NSMutableDictionary<NSString *, WKThreadCreatedContent *> *)sourceMessageThreadMap;

/// 子区消息数量缓存：threadChannelId -> @(messageCount)
+ (NSMutableDictionary<NSString *, NSNumber *> *)messageCountCache;

/// 通知名：子区消息数量更新
extern NSString * const WKThreadMessageCountUpdatedNotification;

@end

NS_ASSUME_NONNULL_END
