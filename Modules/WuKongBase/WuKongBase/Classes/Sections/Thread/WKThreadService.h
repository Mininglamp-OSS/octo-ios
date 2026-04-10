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

/// 获取子区列表
/// @param groupNo 父群编号
- (AnyPromise *)listThreads:(NSString *)groupNo;

/// 获取子区详情
/// @param groupNo 父群编号
/// @param shortId 子区 shortId
- (AnyPromise *)getThread:(NSString *)groupNo shortId:(NSString *)shortId;

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
