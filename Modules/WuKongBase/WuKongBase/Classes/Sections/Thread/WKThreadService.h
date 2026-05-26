//
//  WKThreadService.h
//  WuKongBase
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>

@class WKThreadModel;

NS_ASSUME_NONNULL_BEGIN

@interface WKThreadService : NSObject

+ (instancetype)shared;

/// 创建子区
/// @param groupNo 父群编号
/// @param name 子区名称 (最多50字)
/// @param sourceMessageId 来源消息ID (可选)
/// @param sourceMessagePayload 来源消息正文 (可选，从消息创建时需传)
- (AnyPromise *)createThread:(NSString *)groupNo
                        name:(NSString *)name
             sourceMessageId:(nullable NSString *)sourceMessageId
        sourceMessagePayload:(nullable NSDictionary *)sourceMessagePayload;

/// 获取子区列表（全量，最多100条，向后兼容）
/// @param groupNo 父群编号
- (AnyPromise *)listThreads:(NSString *)groupNo;

/// 获取子区列表（分页）
/// @param groupNo 父群编号
/// @param pageIndex 页码（从 1 开始）
/// @param pageSize 每页数量（最大 100）
/// Promise resolves with NSDictionary: {@"count": NSNumber, @"list": NSArray<WKThreadModel *>}
- (AnyPromise *)listThreads:(NSString *)groupNo pageIndex:(NSInteger)pageIndex pageSize:(NSInteger)pageSize;

/// 获取子区列表（带 status 过滤，分页）。Server 自 #1378 起在
/// `GET groups/{groupNo}/threads?status=` 上支持 active / archived / all 三档,
/// 缺省等价于 active。已归档 tab 必须显式传 archived，否则永远拿到空列表。
/// @param status 期望的子区状态：@"active" / @"archived" / @"all"。nil 等价于
///        不传 → 服务端按 active 默认。
- (AnyPromise *)listThreads:(NSString *)groupNo
                     status:(nullable NSString *)status
                  pageIndex:(NSInteger)pageIndex
                   pageSize:(NSInteger)pageSize;

/// 获取群下全部子区（内部自动分页）。
/// 用于会话列表 cachedTopicsByGroup 兜底——大群子区数 >100 时 listThreads 单页拿不全，
/// "+N子区" badge 的 unread 聚合就会偏小（实测群有 176 关注子区时只算到 100 个的未读）。
/// 单次最多翻 maxPages 页（默认 10 = 1000 条上限），避免极端大群拖死冷启动。
/// Promise resolves with NSArray<WKThreadModel *>（合并所有页）。
- (AnyPromise *)listAllThreads:(NSString *)groupNo maxPages:(NSInteger)maxPages;

/// 同 listAllThreads:maxPages: 但返回 (threads, isComplete) 让调用方判断响应是否
/// 被 maxPages 截断。groupNo 上有 >maxPages*100 条子区时 isComplete=NO，调用方
/// 不应基于响应剪枝缓存（否则误删 page maxPages+ 上的真实数据）。
/// Promise resolves with NSDictionary:
///   @{@"threads": NSArray<WKThreadModel *>, @"complete": @YES/@NO}
- (AnyPromise *)listAllThreadsWithCompleteness:(NSString *)groupNo maxPages:(NSInteger)maxPages;

/// 获取子区详情
/// @param groupNo 父群编号
/// @param shortId 子区 shortId
- (AnyPromise *)getThread:(NSString *)groupNo shortId:(NSString *)shortId;

/// 修改子区名称 (与 web 端 `PUT groups/{groupNo}/threads/{shortId}` 对齐)
/// @param groupNo 父群编号
/// @param shortId 子区 shortId
/// @param name 新名称 (最多 50 字)
- (AnyPromise *)updateThread:(NSString *)groupNo shortId:(NSString *)shortId name:(NSString *)name;

/// 加入子区
/// @param shortId 子区 shortId
- (AnyPromise *)joinThread:(NSString *)shortId;

/// 离开子区
/// @param shortId 子区 shortId
- (AnyPromise *)leaveThread:(NSString *)shortId;

/// 归档子区
/// @param groupNo 父群编号
/// @param shortId 子区 shortId
- (AnyPromise *)archiveThread:(NSString *)groupNo shortId:(NSString *)shortId;

/// 取消归档子区
/// @param groupNo 父群编号
/// @param shortId 子区 shortId
- (AnyPromise *)unarchiveThread:(NSString *)groupNo shortId:(NSString *)shortId;

/// 删除子区
/// @param groupNo 父群编号
/// @param shortId 子区 shortId
- (AnyPromise *)deleteThread:(NSString *)groupNo shortId:(NSString *)shortId;

/// 获取子区成员列表
/// @param groupNo 父群编号
/// @param shortId 子区 shortId
- (AnyPromise *)getThreadMembers:(NSString *)groupNo shortId:(NSString *)shortId;

@end

NS_ASSUME_NONNULL_END
