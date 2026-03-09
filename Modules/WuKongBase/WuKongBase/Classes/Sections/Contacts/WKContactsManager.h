//
//  WKContactsManager.h
//  Pods
//
//  Created by tt on 2020/1/4.
//

#import <Foundation/Foundation.h>
#import "WKFriendRequestDB.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN





@protocol WKContactsManagerDelegate;

@interface WKContactsManager : NSObject

+ (WKContactsManager *)shared;


/**
 获取所有好友邀请请求

 @return <#return value description#>
 */
-(NSArray<WKFriendRequestDBModel*>*) getAllFriendRequest;


/**
 未读数量

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
 添加委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKContactsManagerDelegate>) delegate;


/**
 移除委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKContactsManagerDelegate>) delegate;

- (void)callFriendRequestUnreadCountDelegate:(int)unreadCount;


@end

@protocol WKContactsManagerDelegate <NSObject>


@optional
/**
 收到好友请求消息

 @param manager <#manager description#>
 @param friendRequestDBModel 最新的请求
 */
-(void) contactsManager:(WKContactsManager*)manager lastFriendRequest:(WKFriendRequestDBModel*)friendRequestDBModel;


/**
 好友请求未读数量

 @param manager <#manager description#>
 @param unreadCount 未读数量
 */
-(void) contactsManager:(WKContactsManager*)manager friendRequestUnreadCount:(int)unreadCount;


/**
 收到好友接受好友邀请的消息 UI层在此方法里做联系人同步的操作

 @param manager <#manager description#>
 */
-(void) contactsManager:(WKContactsManager *)manager friendAccepted:(NSDictionary*)param;



@end

NS_ASSUME_NONNULL_END
