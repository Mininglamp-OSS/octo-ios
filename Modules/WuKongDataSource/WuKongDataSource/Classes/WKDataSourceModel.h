//
//  WKDataSourceModel.h
//  WuKongDataSource
//
//  Created by tt on 2022/12/2.
//

#import <Foundation/Foundation.h>
#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN


// 群信息
@interface WKGroupModel : WKModel
@property(nonatomic,copy)   NSString *groupNo; // 群编号
@property(nonatomic,copy)   NSString *name; // 群名称
@property(nonatomic,copy)   NSString *notice; // 群公告
@property(nonatomic,copy)   NSString *avatar; // 群头像
@property(nonatomic,assign) BOOL mute; // 免打扰
@property(nonatomic,assign) BOOL receipt; // 消息回执
@property(nonatomic,assign) BOOL stick; // 置顶
@property(nonatomic,assign) BOOL save; // 是否保存
@property(nonatomic,assign) BOOL showNick; // 是否显示昵称
@property(nonatomic,assign) BOOL forbidden; // 是否全员禁言
@property(nonatomic,assign) BOOL forbiddenAddFriend; // 是否禁止互加好友
@property(nonatomic,assign) BOOL screenshot; // 截屏通知
@property(nonatomic,assign) BOOL joinGroupRemind; // 进群通知
@property(nonatomic,assign) BOOL revokeRemind; // 撤回通知
@property(nonatomic,assign) BOOL invite; // 群聊邀请确认
@property(nonatomic,assign) BOOL chatPwdOn; // 聊天密码开关
@property(nonatomic,assign) BOOL allowViewHistoryMsg; //允许新成员查看历史消息
@property(nonatomic,assign) long version; // 群版本号
@end

@interface WKGroupMemberModel : WKModel
@property(nonatomic,assign) long _id; // 群编号
@property(nonatomic,copy)   NSString *groupNo; // 群编号
@property(nonatomic,copy)   NSString *uid; // 成员uid
@property(nonatomic,copy)   NSString *name; // 成员名称
@property(nonatomic,copy)   NSString *avatar; // 成员头像
@property(nonatomic,copy)  NSString *remark; // 成员备注
@property(nonatomic,assign) WKMemberRole role; // 成员角色  WKMemberRoleCommon,WKMemberRoleCreator,WKMemberRoleManager
@property(nonatomic,assign) WKMemberStatus status; // 成员状态
@property(nonatomic,strong) NSNumber *version;// 版本
@property(nonatomic,copy) NSString *inviteUID; // 邀请人uid
@property(nonatomic,copy) NSString *vercode; // 加好友的code
@property(nonatomic,assign) BOOL robot; // 是否是机器人
@property(nonatomic,assign) BOOL isDeleted; // 是否已删除
@property(nonatomic,copy)   NSString *createdAt; // 创建时间
@property(nonatomic,copy)  NSString *updatedAt; // 更新时间
@property(nonatomic,assign) NSInteger forbiddenExpirTime; // 禁言过期时间（没被禁言为0）



-(WKChannelMember*) toChannelMember;

@end


NS_ASSUME_NONNULL_END
