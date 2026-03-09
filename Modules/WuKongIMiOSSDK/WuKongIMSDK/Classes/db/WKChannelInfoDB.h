//
//  WKChannelInfoDB.h
//  WuKongIMSDK
//
//  Created by tt on 2019/12/23.
//

#import <Foundation/Foundation.h>
#import "WKChannelInfo.h"
#import "WKDB.h"
#import "WKChannelInfoSearchResult.h"
#import "WKChannelMessageSearchResult.h"
NS_ASSUME_NONNULL_BEGIN

// 频道在线状态
typedef enum : NSUInteger {
    WKOnlineStatusOffline, // 离线
    WKOnlineStatusOnline, // 在线
} WKOnlineStatus;

// 频道状态
typedef enum : NSUInteger {
    WKChannelStatusUnkown,
    WKChannelStatusNormal,
    WKChannelStatusBlacklist,
} WKChannelStatus;

@interface WKChannelInfoDB : NSObject
+ (WKChannelInfoDB *)shared;

/**
 保存频道信息

 @param channelInfo 频道信息
 @return <#return value description#>
 */
-(BOOL) saveChannelInfo:(WKChannelInfo*)channelInfo;


/**
 批量修改或添加频道信息

 @param channelInfos <#channelInfos description#>
 @return 已存在的旧的频道信息集合
 */
-(NSArray<WKChannelInfo*>*) addOrUpdateChannelInfos:(NSArray<WKChannelInfo*>*)channelInfos;

/**
 更新频道信息

 @param channelInfo <#channelInfo description#>
 */
-(void) updateChannelInfo:(WKChannelInfo*)channelInfo;




/// 更新在线状态
/// @param channel 指定的频道
/// @param status 在线状态
/// @param lastOffline 最后一次离线时间
-(void) updateChannelOnlineStatus:(WKChannel*)channel status:(WKOnlineStatus)status lastOffline:(NSTimeInterval)lastOffline;

/**
  更新在线状态
 @param channel 指定的频道
 @param status 在线状态
 @param lastOffline 最后一次离线时间
 @param mainDeviceFlag 在线的主设备
 */
-(void) updateChannelOnlineStatus:(WKChannel*)channel status:(WKOnlineStatus)status lastOffline:(NSTimeInterval)lastOffline mainDeviceFlag:(WKDeviceFlagEnum)mainDeviceFlag;


/// 删除频道信息
/// @param channel <#channel description#>
-(void) deleteChannelInfo:(WKChannel*)channel;

/**
 获取频道信息

 @param channel 频道
 @return <#return value description#>
 */
-(WKChannelInfo*) queryChannelInfo:(WKChannel*)channel;
-(WKChannelInfo*) queryChannelInfo:(WKChannel*)channel  db:(FMDatabase*)db;


/// 通过状态查询频道信息
/// @param status 0.正常 2.黑明单
-(NSArray<WKChannelInfo*>*) queryChannelInfosWithStatus:(WKChannelStatus)status;


/// 通过状态和关注类型查询频道集合
/// @param status 状态
/// @param follow <#follow description#>
-(NSArray<WKChannelInfo*>*) queryChannelInfosWithStatusAndFollow:(WKChannelStatus)status follow:(WKChannelInfoFollow)follow;


/// 获取跟我好友关系的频道数据
/// @param keyword 关键字
/// @param limit 数量限制
-(NSArray<WKChannelInfo*>*) queryChannelInfoWithFriend:(NSString*)keyword limit:(NSInteger)limit;



/// 查询所有在线的频道
-(NSArray<WKChannelInfo*>*) queryChannelOnlines;

/// 搜索频道信息
/// @param keyword 频道关键字
/// @param channelType 频道类型
/// @param limit 数量限制
-(NSArray<WKChannelInfoSearchResult*>*) searchChannelInfoWithKeyword:(NSString*)keyword channelType:(uint8_t)channelType limit:(NSInteger)limit;


/// 搜索频道信息
/// @param keyword 频道关键字
/// @param limit 数量限制

-(NSArray<WKChannelMessageSearchResult*>*) searchChannelMessageWithKeyword:(NSString*)keyword  limit:(NSInteger)limit;

/// 查询频道
/// @param keyword 关键字
/// @param channelType 频道类型
/// @param limit 数量限制
-(NSArray<WKChannelInfo*>*) queryChannelInfoWithType:(NSString*)keyword channelType:(uint8_t)channelType limit:(NSInteger)limit;


/**
 查询最近会话的频道
 */
-(NSArray<WKChannelInfo*>*) queryAllConversationChannelInfos;
@end

NS_ASSUME_NONNULL_END
