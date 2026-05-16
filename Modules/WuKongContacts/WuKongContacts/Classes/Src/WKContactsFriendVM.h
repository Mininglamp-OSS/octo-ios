//
//  WKContactsFriendVM.h
//  WuKongContacts
//
//  Created by tt on 2021/9/22.
//

#import <WuKongBase/WuKongBase.h>
#import "WKContactsFriendCell.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKContactsFriendVM : WKBaseVM


// 获取通讯录
-(AnyPromise*) requestMaillist;

-(AnyPromise*) requestUpload:(NSArray<WKContactsFriendModel*>*)friends;

-(AnyPromise*) applyFriend:(NSString*)uid remark:(NSString*)remark vercode:(NSString*)vercode;

@end

@interface WKContactsFriendResp : WKModel

@property(nonatomic,copy) NSString *zone;
@property(nonatomic,copy) NSString *phone;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *vercode;
@property(nonatomic,copy) NSString *uid;
@property(nonatomic,assign) BOOL isFriend;

@end

NS_ASSUME_NONNULL_END
