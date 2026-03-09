//
//  ContactsHeaderItem.h
//  WuKongBase
//
//  Created by tt on 2020/1/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^WKContactsHeaderItemClick)(void);

@interface WKContactsHeaderItem : NSObject
@property(nonatomic,copy) NSString *sid;  // 唯一ID
@property(nonatomic,copy) NSString *icon; // icon
@property(nonatomic,copy) NSString *title; // 标题
@property(nonatomic,copy) NSString *moduleID; // 模块ID
@property(nonatomic,strong) WKContactsHeaderItemClick onClick; // 点击
@property(nonatomic,copy) NSString *badgeValue; // 红点

@property(nonatomic,copy) NSString *avatarURL; // 头像url

+(WKContactsHeaderItem*) initWithSid:(NSString*)sid title:(NSString*)title icon:(NSString*)icon moduleID:(NSString*)moduleID onClick:(WKContactsHeaderItemClick)onClick;

@end

NS_ASSUME_NONNULL_END
