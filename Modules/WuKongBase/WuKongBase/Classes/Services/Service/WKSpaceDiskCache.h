//
//  WKSpaceDiskCache.h
//  WuKongBase
//
//  关注 tab 用到的两份"每空间"数据（分组结构 / 关注集合）的磁盘缓存。
//
//  为什么需要：切空间时 `WKCategoryService.invalidateCache` + `WKFollowedKeysStore.reset`
//  把这两份数据都清成空，而 `buildGroupDisplayList` 在 followStore 未加载时是
//  fail-closed 的（分组下面一条会话都不渲染）。于是即便会话行本身有缓存，关注 tab
//  仍然要等两个网络请求回来才有内容。把它们按 (uid, spaceId) 落盘后就能立即出内容，
//  网络回来再覆盖。
//
//  存 Library/Application Support/ 而不是 Caches/：Caches 会被系统在磁盘紧张时清掉，
//  那样"上次的数据"就不可靠了。文件很小（几 KB 量级），不参与 iCloud 备份。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSpaceDiskCache : NSObject

/// 读。namespace + spaceId 决定文件；解析失败 / 文件不存在返回 nil。
+ (nullable id)objectForNamespace:(NSString *)ns spaceId:(NSString *)spaceId;

/// 写。obj 必须是 JSON 可序列化的（NSDictionary / NSArray / 基本类型）。
/// 内部原子替换 + 后台队列写，调用方可以在主线程直接调。
+ (void)setObject:(nullable id)obj forNamespace:(NSString *)ns spaceId:(NSString *)spaceId;

/// 删除某个空间的某份缓存。
+ (void)removeNamespace:(NSString *)ns spaceId:(NSString *)spaceId;

/// 切账号 / 退登时清掉当前用户的全部缓存目录。
+ (void)removeAllForCurrentUser;

@end

NS_ASSUME_NONNULL_END
