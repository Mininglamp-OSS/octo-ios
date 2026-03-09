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
@end

NS_ASSUME_NONNULL_END
