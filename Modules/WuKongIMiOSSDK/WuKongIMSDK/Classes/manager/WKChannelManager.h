//
//  WKChannelManager.h
//  WuKongIMSDK
//
//  Created by tt on 2019/12/23.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
#import "WKChannelInfo.h"
#import "WKChannelMemberDB.h"
#import "WKTaskOperator.h"


NS_ASSUME_NONNULL_BEGIN


@protocol WKChannelManagerDelegate <NSObject>

@optional


/**
 频道信息更新

 @param channelInfo <#channelInfo description#>
 */
-(void) channelInfoUpdate:(WKChannelInfo*)channelInfo;

-(void) channelInfoUpdate:(WKChannelInfo*)channelInfo oldChannelInfo:(WKChannelInfo* __nullable)oldChannelInfo;


/// 频道数据移除
/// @param channel <#channel description#>
-(void) channelInfoDelete:(WKChannel*)channel oldChannelInfo:(WKChannelInfo * __nullable )oldChannelInfo;

@end


typedef void  (^WKChannelInfoBlock)(WKChannelInfo*);

@interface WKChannelManager : NSObject

+ (WKChannelManager *)shared;

/**
 获取频道信息

 @param channel 频道
 @param channelInfoBlock 获取到频道信息回调
 */
-(WKTaskOperator*) fetchChannelInfo:(WKChannel*) channel  completion:(_Nullable WKChannelInfoBlock)channelInfoBlock;

-(void) fetchChannelInfo:(WKChannel*) channel;

/**
  添加频道请求（此方法适合大量cell获取频道数据）
 */
-(void) addChannelRequest:(WKChannel*)channel complete:(void(^_Nullable)(NSError *error,bool notifyBefore))complete;

/**
  取消请求
 */
-(void) cancelRequest:(WKChannel*)channel;

/**
 获取频道信息

 @param channel 频道
 @return <#return value description#>
 */
-(WKChannelInfo*) getChannelInfo:(WKChannel*)channel;

/**
  获取用户频道信息
 */
-(WKChannelInfo*) getChannelInfoOfUser:(NSString*)uid;

/**
删除频道信息
 */
-(void) deleteChannelInfo:(WKChannel*) channel;


/**
 添加或更新频道，如果需要更新的话（只与version大于当前库里的version才更新）

 @param channelInfo <#channelInfo description#>
 */
-(void) addOrUpdateChannelInfoIfNeed:(WKChannelInfo*) channelInfo;


/**
 添加或更新（不比较版本）

 @param channelInfo <#channelInfo description#>
 */
-(void) addOrUpdateChannelInfo:(WKChannelInfo*) channelInfo;


/// 更新频道信息
/// @param channelInfo <#channelInfo description#>
-(void) updateChannelInfo:(WKChannelInfo*) channelInfo;


/// 添加频道信息
/// @param channelInfo <#channelInfo description#>
-(void) addChannelInfo:(WKChannelInfo*) channelInfo;
/**
 更新频道设置

 @param channel 频道
 @param setting 频道设置字典 比例设置免打扰 则传 @{@"mute":@(true)} 设置多个 @{@"mute":@(true),@"stick":@(true)}
 */
-(void) updateChannelSetting:(WKChannel*)channel setting:(NSDictionary*)setting;


/**
 批量添加或更新频道信息 (不通知上层)

 @param channelInfos <#channelInfos description#>
 */
-(void) addOrUpdateChannelInfos:(NSArray<WKChannelInfo*>*) channelInfos;


/**
  删除某个频道内的成员
 @param channel 频道
 */
-(void) deleteMembers:(WKChannel*)channel;

/**
 添加或更新频道成员

 @param members 频道成员集合
 */
-(void) addOrUpdateMembers:(NSArray<WKChannelMember*>*)members;


/**
 获取频道成员集合

 @param channel 频道对象
 @return <#return value description#>
 */
-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel;

/**
  获取频道成员集合
 @param channel 频道对象
 @param limit 数量限制
 */
-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel limit:(NSInteger)limit;

/**
 频道成员数量
 */
-(NSInteger) getMemberCount:(WKChannel*)channel;


/**
 获取频道指定成员

 @param channel 频道
 @param uid 成员UID
 */
-(WKChannelMember*) getMember:(WKChannel*)channel uid:(NSString*)uid;



/// 是否是管理员（群主或管理员）
/// @param channel <#channel description#>
/// @param uid <#uid description#>
-(BOOL) isManager:(WKChannel*)channel memberUID:(NSString*)uid;

/**
 获取频道的成员最新同步key
 
 @param channel 频道信息
 @return <#return value description#>
 */
-(NSString*) getMemberLastSyncKey:(WKChannel*)channel;


/// 设置频道在线
/// @param channel <#channel description#>
/// @param deviceFlag 设备标记
-(void) setChannelOnline:(WKChannel*)channel deviceFlag:(WKDeviceFlagEnum)deviceFlag;
-(void) setChannelOnline:(WKChannel*)channel;

/// 设置频道离线
/// @param channel <#channel description#>
-(void) setChannelOffline:(WKChannel*)channel;
- (void)setChannelOffline:(WKChannel *)channel deviceFlag:(WKDeviceFlagEnum)deviceFlag;


/// 只更新频道的在线状态
/// @param online <#online description#>
-(void) updateChannelOnlineStatus:(WKChannel*)channel online:(BOOL)online;



/// 设置频道离线
/// @param channel 频道
/// @param lastOffline 最后一次离线时间
/// @param deviceFlag 最后一次离线的设备
- (void)setChannelOffline:(WKChannel *)channel lastOffline:(NSTimeInterval)lastOffline deviceFlag:(WKDeviceFlagEnum)deviceFlag;
-(void) setChannelOffline:(WKChannel*)channel lastOffline:(NSTimeInterval)lastOffline;
/**
 设置频道缓存

 @param channelInfo <#channelInfo description#>
 */
-(void) setCache:(WKChannelInfo*) channelInfo;


/**
 获取缓存内的频道信息

 @return <#return value description#>
 */
-(WKChannelInfo*) getCache:(WKChannel*)channel;


/**
  从缓存中获取频道成员
 */
-(WKChannelMember*) getMemberFromCache:(WKChannel *)channel uid:(NSString *)uid;


// 删除频道的成员缓存
-(void) deleteMembersWithChannelFromCache:(WKChannel*)channel;

/**
 移除频道所有缓存
 */
-(void) removeChannelAllCache;
/**
 添加连接委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKChannelManagerDelegate>) delegate;


/**
 移除连接委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKChannelManagerDelegate>) delegate;

@end

NS_ASSUME_NONNULL_END
