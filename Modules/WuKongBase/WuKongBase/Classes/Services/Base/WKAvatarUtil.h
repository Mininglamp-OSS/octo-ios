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

/// 从带 `?v=cacheKey` 的头像 URL 推导一个**稳定缓存 key**。
///
/// 仅剥掉 URL 末尾的那个 `v=...`（即 `getAvatar:cacheKey:` /
/// `getGroupAvatar:cacheKey:` / cell 内联拼装时**始终追加在最后**的 cache-buster），
/// 其它 query（包括上游 `channelInfo.logo` 自带的中间位置 `v=`）一律保留。这样
/// 避免不同身份的头像（如 `?id=a&v=A` 与 `?id=b&v=B`、或两条 logo 把 `v` 当 variant
/// 含义的不同链接）被错误归到同一 key 下。
///
/// **约定**：本工程内 `v=` query 参数保留给 SDWebImage 缓存失效用，调用方追加 `v=`
/// 时务必放在 query 末尾；上游 logo URL 若已有同名参数应视作不同语义（保留不剥）。
///
/// 会话列表 cell 用此 key 在 SDImageCache 里多存一份头像，供 cacheKey 抖动后的
/// cache-miss 兜底（详见 WKConversationListCell.applyAvatarURL:）。
///
/// 示例:
///   `https://cdn/avatar?v=AAA`              → `https://cdn/avatar`
///   `https://cdn/avatar?id=a&v=BBB`         → `https://cdn/avatar?id=a`
///   `https://cdn/avatar?v=variant&v=CCC`    → `https://cdn/avatar?v=variant`
///   `https://cdn/avatar?size=128&v=DDD`     → `https://cdn/avatar?size=128`
///   `https://cdn/avatar?size=128`           → `https://cdn/avatar?size=128` (末位非 v=, 整 URL 保留)
///   `https://cdn/avatar`                    → `https://cdn/avatar`
+(nullable NSString*) stableCacheKeyFromAvatarURL:(nullable NSString*)avatarURL;
@end

NS_ASSUME_NONNULL_END
