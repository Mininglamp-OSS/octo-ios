//
//  WKFriendRequestDB.h
//  WuKongBase
//
//  Created by tt on 2020/1/4.
//

#import <Foundation/Foundation.h>
#import "WKConstant.h"
NS_ASSUME_NONNULL_BEGIN
@interface WKFriendRequestDBModel : NSObject
@property(nonatomic,copy) NSString *uid; // 用户uid
@property(nonatomic,copy) NSString *name; // 用户名字
@property(nonatomic,copy) NSString *avatar; // 用户头像
@property(nonatomic,copy) NSString *remark; // 备注
@property(nonatomic,copy) NSString *token; // 邀请凭证，确认邀请的时候需要传
@property(nonatomic,assign) int status; //状态 0.等待确认 1.已确认
@property(nonatomic,assign) BOOL readed; // 是否已读
@property(nonatomic,strong) NSDate *createdAt; // 创建时间
@property(nonatomic,strong) NSDate *updatedAt; // 更新时间
@end

@interface WKFriendRequestDB : NSObject
+ (instancetype)shared;



/**
 添加好友请求

 @param model <#model description#>
 @return 是否是新的请求
 */
-(BOOL) addFriendRequest:(WKFriendRequestDBModel*)model;


/**
 获取所有好友请求

 @return <#return value description#>
 */
-(NSArray<WKFriendRequestDBModel*>*) getAllFriendRequest;


/**
 获取未读数量

 @return <#return value description#>
 */
-(int) getFriendRequestUnreadCount;

/**
 标记所有好友请求为已读
 */
-(void) markAllFriendRequestToReaded;


/**
 修改某个好友请求的状态
 
 @param uid <#uid description#>
 */
-(void) updateFriendRequestStatus:(NSString*)uid status:(WKFriendRequestStatus)status;

/**
  删除单个好友请求
 */
-(void) deleteFriendRequest:(NSString*)uid;

@end



NS_ASSUME_NONNULL_END
