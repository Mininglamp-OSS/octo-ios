//
//  WKConversationSettingVM.h
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKFormItemModel.h"
#import "WKFormSection.h"
#import "WuKongBase.h"
#import "WKGroupBaseInfo.h"
#import "WKUserOnlineResp.h"
NS_ASSUME_NONNULL_BEGIN
@class WKConversationSettingVM;

@protocol WKConversationSettingDelegate <NSObject>

@optional


/**
 群名点击

 @param vm <#vm description#>
 */
-(void) settingOnGroupNameClick:(WKConversationSettingVM*)vm;

/**
 群公告点击
 
 @param vm <#vm description#>
 */
-(void) settingOnGroupNoticeClick:(WKConversationSettingVM*)vm;


/**
 清空当前会话的消息

 @param vm <#vm description#>
 */
-(void) settingOnClearMessages:(WKConversationSettingVM*)vm;


/// 退出群聊
/// @param vm <#vm description#>
-(void) settingOnGroupExit:(WKConversationSettingVM*)vm;


/**
 频道数据更新

 @param vm <#vm description#>
 */
-(void) settingOnChannelUpdate:(WKConversationSettingVM*)vm;

// 顶部成员数据更新
-(void) settingOnTopNMembersUpdate:(WKConversationSettingVM*)vm;

/**

在群里的昵称
 @param vm <#vm description#>
 */
-(void) settingOnNickNameInGroup:(WKConversationSettingVM*)vm;


/// 举报
/// @param vm <#vm description#>
-(void) settingOnReport:(WKConversationSettingVM*)vm;



/**
 黑明单设置
 */
-(void) settingOnBlacklist:(WKConversationSettingVM*)vm action:(bool) addOrRemove;

@end

@interface WKConversationSettingVM : WKBaseTableVM

@property(nonatomic,strong) WKChannel *channel;

@property(nonatomic,weak) id<WKConversationContext> context;

@property(nonatomic,weak) id<WKConversationSettingDelegate> delegate;

@property(nonatomic,assign,readonly) NSInteger memberCount; // 群成员数量
@property(nonatomic,assign,readonly) WKMemberRole memberRole; // 我在此群的角色
@property(nonatomic,assign,readonly) WKGroupType groupType;

@property(nonatomic,strong) NSArray<WKUserOnlineResp*> *onlineMembers; // 在线成员


/**
 我在群里的信息
 */
@property(nullable,nonatomic,strong) WKChannelMember *memberOfMe;




/**
 频道数据
 */
@property(nonatomic,strong,readonly) WKChannelInfo *channelInfo;

/**
 同步成员
 */
-(void) syncMembersIfNeed;


/**
 我是否是群管理员

 @return <#return value description#>
 */
-(BOOL) isManagerForMe;


/**
 我是否是群创建者

 @return <#return value description#>
 */
-(BOOL) isCreatorForMe;


/**
 我是否是群创建者或管理员

 @return <#return value description#>
 */
-(BOOL) isManagerOrCreatorForMe;


/// 请求群成员邀请
-(AnyPromise*) requestGroupMemberInvite:(NSArray<NSString*>*)uids remark:(NSString*)remark;

/**
 添加黑名单
 */
-(AnyPromise*) addBlacklist;

/**
 移除黑名单
 */
-(AnyPromise*) deleteBlacklist;

// 在线成员
-(AnyPromise*) onlineMembers:(NSArray<NSString*>*)members;

// 获取成员的在线状态
-(WKUserOnlineResp*) memberOnline:(NSString*)uid;

@end




NS_ASSUME_NONNULL_END
