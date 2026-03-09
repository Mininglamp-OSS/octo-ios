//
//  WKContactsInfoVM.h
//  WuKongContacts
//
//  Created by tt on 2020/1/4.
//

#import <Foundation/Foundation.h>
#import <WuKongBase/WuKongBase.h>
#import <PromiseKit/PromiseKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKContactsInfoVM : NSObject


/**
 获取用户信息

 @param uid 用户uid
 @return <#return value description#>
 */
-(AnyPromise*) getUserInfo:(NSString*)uid;


/**
 申请好友

 @param uid 好友uid
 @param remark 申请备注
 @return <#return value description#>
 */
-(AnyPromise*) applyFriend:(NSString*)uid remark:(NSString*)remark;

@end

@interface WKUserInfoResp : WKModel

@property(nonatomic,copy) NSString * uid;

@property(nonatomic,copy) NSString *name;

@property(nonatomic,copy) NSString *avatar;

@end


NS_ASSUME_NONNULL_END
