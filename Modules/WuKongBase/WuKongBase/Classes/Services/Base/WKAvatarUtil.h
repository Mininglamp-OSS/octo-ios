//
//  WKAvatarUtil.h
//  WuKongBase
//
//  Created by tt on 2020/2/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAvatarUtil : NSObject


/// 通过uid获取用户头像
/// @param uid <#uid description#>
+(NSString*) getAvatar:(NSString*)uid;

/// 获取用户头像（带缓存key，用于使SDWebImage缓存失效）
+(NSString*) getAvatar:(NSString*)uid cacheKey:(NSString*)cacheKey;

/// 获取完整头像URL
/// @param avatarPath <#avatarPath description#>
+(NSString*) getFullAvatarWIthPath:(NSString*)avatarPath;


/// 获取群头像
/// @param groupNo <#groupNo description#>
+(NSString*) getGroupAvatar:(NSString*)groupNo;

/// 获取群头像（带缓存key，用于使SDWebImage缓存失效）
/// @param groupNo 群编号
/// @param cacheKey 缓存key（群成员变化时生成的新UUID）
+(NSString*) getGroupAvatar:(NSString*)groupNo cacheKey:(NSString*)cacheKey;

/// 从带 `?v=cacheKey` 的头像 URL 推导一个**稳定缓存 key**，仅剥掉 cache-busting
/// 的 `v=` 参数，保留其它 query（如 `?id=...`）以避免不同身份的头像被错误归到同一
/// key 下。会话列表 cell 用此 key 在 SDImageCache 里多存一份头像，供 cacheKey 抖动
/// 后的 cache-miss 兜底。
///
/// 示例:
///   `https://cdn/avatar?v=AAA`          → `https://cdn/avatar`
///   `https://cdn/avatar?id=a&v=BBB`     → `https://cdn/avatar?id=a`
///   `https://cdn/avatar?v=CCC&size=128` → `https://cdn/avatar?size=128`
///   `https://cdn/avatar`                → `https://cdn/avatar`
+(nullable NSString*) stableCacheKeyFromAvatarURL:(nullable NSString*)avatarURL;
@end

NS_ASSUME_NONNULL_END
