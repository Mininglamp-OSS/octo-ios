//
//  WKConversationVM.h
//  WuKongBase
//
//  Created by tt on 2022/5/19.
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <PromiseKit/PromiseKit.h>
#import "WKGroupBaseInfo.h"
#import "WKModel.h"
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationVM : NSObject

@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,strong) WKChannelInfo *channelInfo;


@property(nonatomic,assign,readonly) WKGroupType groupType;

// -------------------- 群成员相关 --------------------
@property(nonatomic,strong) NSArray<WKChannelMember*> *members;
@property(nullable,nonatomic,strong) WKChannelMember *memberOfMe; // 我在群里的信息

@property(nonatomic,assign,readonly) NSInteger memberCount;
@property(nonatomic,assign,readonly) WKMemberRole memberRole;
@property(nonatomic,assign) NSInteger forbiddenExpirTime; // 禁言过期时间 0表示未禁言

@property(nonatomic,copy) void(^onMemberUpdate)(void); // 群成员有更新

/**
 获取所有成员

 @return <#return value description#>
 */
-(NSArray<WKChannelMember*>*) getAllMembers;

/**
 同步成员
 */
-(void) syncMembersIfNeed;

-(void) requestMembers;



/// 正在输入中
-(void) typing;


@end



NS_ASSUME_NONNULL_END
