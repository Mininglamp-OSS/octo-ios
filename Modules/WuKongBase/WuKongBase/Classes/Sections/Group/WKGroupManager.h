//
//  WKGroupManager.h
//  WuKongBase
//
//  Created by tt on 2020/1/19.
//

#import <Foundation/Foundation.h>
#import <PromiseKit/PromiseKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"
@class WKGroupManager;
NS_ASSUME_NONNULL_BEGIN

// 成员数据缓存类型
typedef enum : NSUInteger {
    WKChannelMemberCacheTypeUnkown, // 未知
    WKChannelMemberCacheTypeDB, // db
    WKChannelMemberCacheTypeNetwork // 网络
} WKChannelMemberCacheType;

typedef enum : NSUInteger {
    WKGroupSettingKeyMute, // 免打扰
    WKGroupSettingKeyStick, // 置顶
    WKGroupSettingKeySave, //  保存
    WKGroupSettingKeyShowNick, // 显示昵称
    WKGroupSettingKeyInvite, // 成员邀请确认
    WKGroupSettingKeyForbidden, // 群禁言
    WKGroupSettingKeyForbiddenAddFriend, // 群内禁止互相加好友
    WKGroupSettingKeyScreenshot, // 截屏通知
    WKGroupSettingKeyRevokeRemind, // 撤回提醒
    WKGroupSettingKeyJoinGroupRemind, // 进群提醒
    WKGroupSettingKeyChatPwdOn, // 聊天密码开关
    WKGroupSettingKeyReceipt, // 回执开关
    WKGroupSettingKeyAllowViewHistoryMsg, // 允许新成员查看历史消息
    WKGroupSettingKeyRemark, // 群备注
    WKGroupSettingKeyFlame // 阅后即焚
} WKGroupSettingKey;

// 群公告
static NSString *WKGroupAttrKeyNotice = @"notice";
// 群名称
static NSString *WKGroupAttrKeyName = @"name";


@protocol WKGroupManagerDelegate <NSObject>

/**
 创建群组

 @param manager manager
 @param members 群成员uid集合
 */
-(void) groupManager:(WKGroupManager*)manager createGroup:(NSArray<NSString*>*)members object:(id __nullable)object complete:(void(^__nullable)(NSString*groupNo,NSError * __nullable error))complete;


/**
 添加成员
 @param manager manager
 @param groupNo 群编号
 @param members 群成员
 */
-(void) groupManager:(WKGroupManager*)manager groupNo:(NSString*)groupNo membersOfAdd:(NSArray<NSString*>*)members object:(id __nullable)object complete:(void(^__nullable)(NSError * __nullable error))complete;


/**
  搜索群成员
 @param groupNo 群编号
 @param keyword 搜索关键字
 @param page 页码 最小为1
 @param limit 数量限制
 @param complete 结果回调
 */
-(void) groupManager:(WKGroupManager*)manager searchMembers:(NSString*)groupNo keyword:(NSString*)keyword page:(NSInteger)page  limit:(NSInteger)limit complete:(void(^__nullable)(NSError * __nullable error,NSArray<WKChannelMember*>*members))complete;

/**
 删除群成员

 @param manager <#manager description#>
 @param groupNo 群编号
 @param members 群成员
 @param object <#object description#>
 @param complete <#complete description#>
 */
-(void) groupManager:(WKGroupManager*)manager groupNo:(NSString*)groupNo membersOfDelete:(NSArray<NSString*>*)members object:(id __nullable)object complete:(void(^__nullable)(NSError * __nullable error))complete;


/// 将群成员设置为管理员
/// @param manager <#manager description#>
/// @param groupNo 群编号
/// @param members 需要设置为管理员的群成员uid
/// @param complete <#complete description#>
-(void) groupManager:(WKGroupManager*)manager groupNo:(NSString*)groupNo membersToManager:(NSArray<NSString*>*) members complete:(void(^__nullable)(NSError * __nullable error))complete;


/// 将群管理员设置为普通成员
/// @param manager <#manager description#>
/// @param groupNo 群编号
/// @param managers 需要设置为普通成员的管理员列表
/// @param complete <#complete description#>
-(void) groupManager:(WKGroupManager*)manager groupNo:(NSString*)groupNo managersToMember:(NSArray<NSString*>*)managers complete:(void(^__nullable)(NSError * __nullable error))complete;


/**
 同步群信息

 @param manager manager
 @param groupNo 群编号
 @param complete 同步完成
 */
-(void) groupManager:(WKGroupManager*)manager syncGroupInfo:(NSString*)groupNo complete:(void(^__nullable)(NSError * __nullable error,bool notifyBefore))complete;

- (NSURLSessionDataTask*)taskGroupManager:(nonnull WKGroupManager *)manager syncGroupInfo:(nonnull NSString *)groupNo complete:(void (^ _Nullable)(NSError *error,bool notifyBefore))complete;

/**
 同步群成员

 @param manager manager
 @param groupNo 群编号
 @param complete 完成
 */
-(void) groupManager:(WKGroupManager*)manager syncMemebers:(NSString*)groupNo complete:(void(^__nullable)(NSInteger syncMemberCount,NSError * __nullable error))complete;


/**
 更新群成员信息

 @param manager manager
 @param groupNo 群编号
 @param memberUID 成员UID
 @param attr 需要修改成员的属性
 @param complete 完成回调
 */
-(void) groupManager:(WKGroupManager*)manager didMemberUpdateAtGroup:(NSString*)groupNo forMemberUID:(NSString*)memberUID withAttr:(NSDictionary*)attr complete:(void(^__nullable)(NSError * __nullable error))complete;


/// 退出群聊
/// @param manager <#manager description#>
/// @param groupNo 群编号
-(void) groupManager:(WKGroupManager*)manager didGroupExit:(NSString*)groupNo complete:(void(^__nullable)(NSError *error))complete;


/// 群解散
/// @param manager <#manager description#>
/// @param groupNo 群编号
-(void) groupManager:(WKGroupManager*)manager didGroupDisband:(NSString*)groupNo complete:(void(^__nullable)(NSError *error))complete;


/**
 群设置
 @param manager <#manager description#>
 @param groupNo 群编号
 @param key 设置key
 @param on 是否开启
 */
-(void) groupManagerSetting:(WKGroupManager*)manager groupNo:(NSString*)groupNo settingKey:(WKGroupSettingKey)key on:(BOOL)on;

/**
  群设置
 @param manager <#manager description#>
 @param groupNo 群编号
 @param key 设置key
 @param value 对应的值
 */
- (void)groupManagerSetting:(WKGroupManager *)manager groupNo:(NSString *)groupNo key:(NSString*)key value:(id)value;

/**
 群备注
 @param manager <#manager description#>
 @param groupNo 群编号
 @param remark 群备注
 */
-(AnyPromise*) groupSettingRemark:(WKGroupManager*)manager groupNo:(NSString*)groupNo remark:(NSString*)remark;

/**
 群信息更新

 @param manager <#manager description#>
 @param groupNo 群编号
 @param attrKey 属性key
 @param attrValue 属性值
 */
-(void) groupManagerUpdate:(WKGroupManager*)manager groupNo:(NSString*)groupNo attrKey:(NSString*)attrKey attrValue:(NSString*)attrValue complete:(void(^)(NSError * __nullable error))complete;

@end

@interface WKGroupManager : NSObject
+ (WKGroupManager *)shared;

@property(nonatomic,strong) id<WKGroupManagerDelegate> delegate;

/**
 创建群聊

 @param members <#members description#>
 @param object <#object description#>
 */
-(void) createGroup:(NSArray<NSString*>*)members object:(id __nullable)object complete:(void(^)(NSString* groupNo,NSError * __nullable error))complete;


/**
 同步群信息

 @param groupNo <#groupNo description#>
 @param complete <#complete description#>
 */
-(void) syncGroupInfo:(NSString*)groupNo complete:(void(^__nullable)(NSError * __nullable error))complete;

-(NSURLSessionDataTask* __nullable) taskSyncGroupInfo:(NSString*)groupNo complete:(void(^__nullable)(NSError *error,bool notifyBefore))complete;
/**
 同步群成员

 @param groupNo 群编号
 @param complete 同步完成后的回调
 */
-(void)  syncMemebers:(NSString*)groupNo complete:(void(^__nullable)(NSInteger syncMemberCount,NSError * __nullable error))complete;


/**
 同步群成员

 @param groupNo 群编号
 */
-(void)  syncMemebers:(NSString*)groupNo;

/**
  搜索成员
 @param keyword 根据关键字搜索
 @param limit 每次获取数据限制
 @param complete 结果回掉，注意这里回掉可能会被调用多次 比如本地有缓存的时候会回掉一次，网络请求到数据后也会回掉一次。注意重复处理
 */
-(void) searchMembers:(WKChannel*)channel keyword:(NSString * __nullable)keyword limit:(NSInteger)limit complete:(void(^)(WKChannelMemberCacheType cacheType,NSArray<WKChannelMember*>*members))complete;
/**
  搜索成员
 @param keyword 根据关键字搜索
 @param page 开始页码
 @param limit 每次获取数据限制
 @param requestStrategy 请求策略
 @param complete 结果回掉，注意这里回掉可能会被调用多次 比如本地有缓存的时候会回掉一次，网络请求到数据后也会回掉一次。注意重复处理
 */
-(void) searchMembers:(WKChannel*)channel keyword:(NSString * __nullable)keyword page:(NSInteger)page limit:(NSInteger)limit requestStrategy:(WKRequestStrategy)requestStrategy complete:(void(^)(WKChannelMemberCacheType cacheType,NSArray<WKChannelMember*>*members))complete;





/**
 添加群成员

 @param groupNo 群编号
 @param members 群成员
 @param object <#object description#>
 */
-(void) groupNo:(NSString*)groupNo membersOfAdd:(NSArray<NSString*>*)members object:(id __nullable)object complete:(void(^__nullable)(NSError *error))complete;


/**
 删除群成员

 @param groupNo 群编号
 @param members 群成员
 @param object <#object description#>
 @param complete <#complete description#>
 */
-(void) groupNo:(NSString*)groupNo membersOfDelete:(NSArray<NSString*>*)members object:(id __nullable)object complete:(void(^__nullable)(NSError *error))complete;



/// 将成员设置为管理员
/// @param groupNo 群编号
/// @param members 需要设置成群管理员的成员uids
/// @param complete <#complete description#>
-(void) groupNo:(NSString*)groupNo membersToManager:(NSArray<NSString*>*)members complete:(void(^__nullable)(NSError *error))complete;


/// 将管理员设置为普通成员
/// @param groupNo 群编号
/// @param managers 需要设置成普通成员的管理员
/// @param complete <#complete description#>
-(void) groupNo:(NSString*)groupNo managersToMember:(NSArray<NSString*>*)managers complete:(void(^__nullable)(NSError *error))complete;


/**
 群设置

 @param groupNo 群编号
 @param key 设置key
 @param on 是否开启
 */
-(void) groupSetting:(NSString*)groupNo settingKey:(WKGroupSettingKey)key on:(BOOL)on;

/**
群设置
 @param groupNo 群编号
 @param key 设置key
 @param value 设置对应的值
 */
- (void)groupSetting:(NSString *)groupNo key:(NSString*)key value:(id)value;

/**
 群备注

 @param groupNo 群编号
 @param remark 群备注
 */
- (AnyPromise*)groupRemark:(NSString *)groupNo remark:(NSString*)remark;

/**
 群更新

 @param groupNo 群编号
 @param attrKey 群属性
 @param attrValue 属性值
 */
-(void) groupUpdate:(NSString*)groupNo attrKey:(NSString*)attrKey attrValue:(NSString*)attrValue complete:(void(^__nullable)(NSError *error))complete;


/**
 修改群成员信息

 @param groupNo 群编号
 @param memberUID 群成员UID
 @param attr 修改的属性
 @param complete <#complete description#>
 */
-(void) didMemberUpdateAtGroup:(NSString*)groupNo forMemberUID:(NSString*)memberUID withAtrr:(NSDictionary*)attr complete:(void(^__nullable)(NSError *error))complete;



/// 退出群聊
/// @param groupNo 群编号
-(void) didGroupExit:(NSString*)groupNo complete:(void(^__nullable)(NSError * __nullable error))complete;

/// 群解散
/// @param groupNo 群编号
-(void) didGroupDisband:(NSString*)groupNo complete:(void(^__nullable)(NSError * __nullable error))complete;
@end

NS_ASSUME_NONNULL_END
