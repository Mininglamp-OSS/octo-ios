//
//  WKGlobalSearchModels.h
//  WuKongBase
//
//  全局搜索 L1 聚合总览（POST /v1/messages/_search_global_groups）的数据模型。
//  每个 bucket = 一个会话/群/子区/私聊，带 约N 命中数 + latest_at + preview[]。
//  preview[] 复用会话内搜索的 WKChannelHistorySearchItem（MessageHit 同口径）。
//
//  与 web GlobalMessageSearchService / useGlobalChatSearch 同口径。
//

#import <Foundation/Foundation.h>
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

/// L1 聚合桶。channelType: 1=私聊(DM) / 2=群 / 5=子区(thread)。
@interface WKGlobalSearchGroupBucket : NSObject

@property (nonatomic, copy, nullable) NSString *channelId;      // 群/子区 id；DM 时为对端 uid（已反解）
@property (nonatomic, assign) NSInteger channelType;
@property (nonatomic, copy, nullable) NSString *parentGroupNo;  // 子区所属父群（type=5 才有）
@property (nonatomic, copy, nullable) NSString *groupName;      // 群名 / DM 对端用户名
@property (nonatomic, copy, nullable) NSString *threadId;       // 子区 id（type=5）
@property (nonatomic, copy, nullable) NSString *threadName;     // 子区名（type=5）

@property (nonatomic, assign) NSInteger matchCount;             // ≈命中数（过滤前，近似）
@property (nonatomic, assign) BOOL matchCountApprox;            // 恒 true → 显示「约N」
@property (nonatomic, assign) NSTimeInterval latestAt;          // 最近命中时间（秒）
@property (nonatomic, copy, nullable) NSString *latestAtRaw;    // 原始 latest_at 字符串

/// 精确可见的预览命中（每条已做可见性过滤，可直接渲染）。
@property (nonatomic, copy) NSArray<WKChannelHistorySearchItem *> *preview;

/// 列表行标题：群→群名；子区→「群名 · 子区名」；私聊→对端名。
@property (nonatomic, copy, readonly) NSString *displayTitle;
/// 是否是子区桶。
@property (nonatomic, assign, readonly) BOOL isThread;
/// 是否是私聊桶。
@property (nonatomic, assign, readonly) BOOL isDM;
/// 用于跳 L2 的 channel_ids 身份 [{channel_id, channel_type}]。
- (NSDictionary *)l2ChannelIdentity;

+ (nullable instancetype)bucketFromDict:(NSDictionary *)dict;

@end

/// L1 一次聚合结果。
@interface WKGlobalSearchGroupsResult : NSObject
@property (nonatomic, copy) NSArray<WKGlobalSearchGroupBucket *> *buckets;
@property (nonatomic, assign) NSInteger totalGroups;      // 命中群总数（近似）
@property (nonatomic, assign) BOOL totalGroupsApprox;     // 恒 true → 显示「约M」
@property (nonatomic, assign) BOOL hasMore;               // true = 命中群超桶上限 → 提示缩小范围
@property (nonatomic, assign) NSInteger sequence;         // 回带的请求序号，用于丢弃过期响应

+ (instancetype)resultFromResponse:(id)response;
@end

NS_ASSUME_NONNULL_END
