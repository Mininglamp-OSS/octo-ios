//
//  WKChannelMemberDB.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/20.
//

#import <Foundation/Foundation.h>
#import "WKChannel.h"
NS_ASSUME_NONNULL_BEGIN

// 成员角色
typedef enum : NSUInteger {
    WKMemberRoleCommon, // 普通成员
    WKMemberRoleCreator, // 创建者
    WKMemberRoleManager, // 管理员
} WKMemberRole;

// 成员状态
typedef enum : NSUInteger {
    WKMemberStatusUnknown,
    WKMemberStatusNormal, // 正常
    WKMemberStatusBlacklist, // 被拉入黑名单
} WKMemberStatus;

@interface WKChannelMember : NSObject

@property(nonatomic,copy)    NSString *channelId; // 频道ID
@property(nonatomic,assign)  uint8_t channelType; // 频道类型
@property(nonatomic,copy) NSString *memberAvatar; // 成员头像
@property(nonatomic,copy)    NSString *memberUid; // 成员uid
@property(nonatomic,copy)    NSString *memberName; // 成员名称
@property(nonatomic,copy)    NSString *memberRemark; // 成员备注

@property(nonatomic,copy,readonly) NSString *displayName;

@property(nonatomic,assign)  WKMemberRole  role; // 成员角色
@property(nonatomic,assign) WKMemberStatus status; // 成员状态

@property(nonatomic,strong) NSNumber *version; // 版本
@property(nonatomic,strong) NSMutableDictionary *extra; // 扩展字段

@property(nonatomic,strong) NSString *createdAt; // 成员加入时间
@property(nonatomic,strong) NSString *updatedAt; // 成员数据最后一次更新时间

@property(nonatomic,assign) BOOL robot; // 是否是机器人
@property(nonatomic,assign) BOOL isDeleted; // 是否已删除

@end

@interface WKChannelMemberDB : NSObject

+ (WKChannelMemberDB *)shared;


/**
 添加或更新成员

 @param members <#members description#>
 */
-(void) addOrUpdateMembers:(NSArray<WKChannelMember*>*)members;


/// 删除频道成员
/// @param channel <#channel description#>
-(void) deleteMembers:(WKChannel*)channel;

/**
 获取频道的成员最新同步key

 @param channel 频道信息
 @return <#return value description#>
 */
-(NSString*) getMemberLastSyncKey:(WKChannel*)channel;


/**
 获取频道对应的成员列表

 @param channel 频道
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
 获取频道成员集合（分页查询）
 @param channel 频道对象
 @param keyword 名字关键字筛选 为空则不做为条件筛选
 @page page 页码 从1开始
 @param limit 数量限制
 */
-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel keyword:(NSString*)keyword page:(NSInteger)page limit:(NSInteger)limit;
-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel role:(WKMemberRole)role;

/// 获取群内的黑名单成员
/// @param channel <#channel description#>
-(NSArray<WKChannelMember*>*) getBlacklistMembersWithChannel:(WKChannel*)channel;


/// 获取管理员和创建者列表
/// @param channel 频道
-(NSArray<WKChannelMember*>*) getManagerAndCreator:(WKChannel*)channel;

/**
 获取频道内指定uid的成员列表

 @param channel <#channel description#>
 @param uids <#uids description#>
 @return <#return value description#>
 */
-(NSArray<WKChannelMember*>*) getMembersWithChannel:(WKChannel*)channel uids:(NSArray<NSString*>*)uids;


/**
  更新指定用户的成员状态
@param status 成员状态
@param channel 频道
@param uids 成员uid集合
 */
-(void) updateMemberStatus:(WKMemberStatus)status channel:(WKChannel*) channel  uids:(NSArray<NSString*>*)uids;

/**
 是否是管理员 （群主或管理者）

 @param channel 频道
 @param uid 用户UID
 @return <#return value description#>
 */
-(BOOL) isManager:(WKChannel*)channel memberUID:(NSString*)uid;


/**
 是否是创建者

 @param channel 频道
 @param uid 用户UID
 @return <#return value description#>
 */
-(BOOL) isCreator:(WKChannel*)channel memberUID:(NSString*)uid;


/// 成员是否存在频道里
/// @param channel 频道对象
/// @param uid 成员uid
-(BOOL) exist:(WKChannel*)channel uid:(NSString*)uid;

/**
 获取指定的成员信息

 @param channel 频道
 @param uid 成员UID
 @return 成员信息
 */
- (WKChannelMember*)get:(WKChannel*)channel  memberUID:(NSString *)uid;

/**
 获取成员数量
 */
-(NSInteger) getMemberCount:(WKChannel*)channel;
@end

NS_ASSUME_NONNULL_END
