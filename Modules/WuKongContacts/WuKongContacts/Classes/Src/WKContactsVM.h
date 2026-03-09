//
//  WKContactsVM.h
//  WuKongContacts
//
//  Created by tt on 2019/12/7.
//

#import <Foundation/Foundation.h>
#import <WuKongBase/WuKongBase.h>
#import <PromiseKit/PromiseKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKContactsVM : WKBaseTableVM


/**
 搜索好友

 @param keyword 好友关键字
 @return <#return value description#>
 */
-(AnyPromise*) searchFriend:(NSString*)keyword;

@end

@interface WKUserResp : WKModel

@property(nonatomic,copy) NSString * uid;

@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *vercode;
@property(nonatomic,copy) NSString *avatar;

@end


@interface WKUserSearchResp : WKModel

@property(nonatomic,assign) BOOL exist;

@property(nonatomic,strong) WKUserResp *user;

@end

NS_ASSUME_NONNULL_END



