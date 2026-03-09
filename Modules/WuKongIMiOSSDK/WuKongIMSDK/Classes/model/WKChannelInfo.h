//
//  WKChannelInfo.h
//  WuKongIMSDK
//
//  Created by tt on 2019/12/23.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
#import "WKConst.h"
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKChannelInfoFollowStrange = 0, // 未关注
    WKChannelInfoFollowFriend = 1, // 已关注
     WKChannelInfoFollowAll = 2,
} WKChannelInfoFollow;

// 扩展字段的key
typedef NSString *WKChannelExtraKey NS_STRING_ENUM;

@interface WKChannelInfo : NSObject<NSCopying>

// 频道
@property(nonatomic,strong) WKChannel *channel;

// 父类频道
@property(nonatomic,strong,nullable) WKChannel *parentChannel;
/**
 是否已关注 0.未关注（陌生人） 1.已关注（好友）
 */
@property(nonatomic,assign) WKChannelInfoFollow follow;

@property(nonatomic,assign) BOOL beDeleted; // 是否被对方删除 (好友单向删除)

@property(nonatomic,assign) BOOL beBlacklist; // 是否被对方拉入黑名单

/**
 频道名字
 */
@property(nonatomic,copy) NSString *name;

/**
 频道备注
 */
@property(nonatomic,copy) NSString *remark;


/// 展示的名字（如果remark为空则显示name，如果remark有值则显示remark）
@property(nonatomic,copy) NSString *displayName;


/**
频道公告
 */
@property(nonatomic,copy) NSString *notice;


/**
 频道logo
 */
@property(nonatomic,copy) NSString *logo;

/**
 是否置顶
 */
@property(nonatomic,assign) BOOL stick;


/**
 是否免打扰
 */
@property(nonatomic,assign) BOOL mute;


/**
 是否显示昵称
 */
@property(nonatomic,assign) BOOL showNick;


/**
 是否保存
 */
@property(nonatomic,assign) BOOL save;


/// 是否全员禁言
@property(nonatomic,assign) BOOL forbidden;


/// 群聊邀请确认
@property(nonatomic,assign) BOOL invite;

/**
 频道版本号
 */
@property(nonatomic,assign) long long version;


/// 频道状态 0.正常  2.黑名单
@property(nonatomic,assign) NSInteger status;




/// 是否开启已读回执
@property(nonatomic,assign) BOOL receipt;

/// 是否开启了阅后即焚
@property(nonatomic,assign) BOOL flame;
@property(nonatomic,assign) NSInteger flameSecond; // 开启阅后即焚的秒数

/// 是否是机器人
@property(nonatomic,assign) BOOL robot;


/// 频道类别
@property(nonatomic,copy) NSString *category;

/// 是否在线
@property(nonatomic,assign) BOOL online;
// 在线的主设备
@property(nonatomic,assign) WKDeviceFlagEnum deviceFlag;
/// 最后一次离线时间
@property(nonatomic,assign) NSTimeInterval lastOffline;


/**
 扩展字段
 */
@property(nonatomic,strong) NSMutableDictionary<WKChannelExtraKey,id> *extra;

/// 获取扩展字段内的值
/// @param key <#key description#>
-(id) extraValueForKey:(WKChannelExtraKey)key;

-(id) extraValueForKey:(WKChannelExtraKey)key defaultValue:(id _Nullable)value;

-(void) setExtraValue:(id)value forKey:(WKChannelExtraKey)key;

-(BOOL) settingForKey:(WKChannelExtraKey)key defaultValue:(BOOL)on;

-(void) setSettingValue:(BOOL)on forKey:(WKChannelExtraKey)key;
@end

NS_ASSUME_NONNULL_END
