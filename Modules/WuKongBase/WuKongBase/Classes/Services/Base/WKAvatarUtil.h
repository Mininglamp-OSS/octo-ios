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
@end

NS_ASSUME_NONNULL_END
