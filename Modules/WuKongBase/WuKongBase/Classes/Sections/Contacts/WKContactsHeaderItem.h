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
@property(nonatomic,copy) NSString *countValue; // 右侧计数，如 "(4)"

@property(nonatomic,copy) NSString *avatarURL; // 头像url

@property(nonatomic,copy) NSString *svgIconName; // SVG图标名称 (e.g. "person-plus", "users", "bot")
@property(nonatomic,copy) NSString *gradientKind; // 渐变类型 ("friend", "group", "ai")

+(WKContactsHeaderItem*) initWithSid:(NSString*)sid title:(NSString*)title icon:(NSString*)icon moduleID:(NSString*)moduleID onClick:(WKContactsHeaderItemClick)onClick;

@end

NS_ASSUME_NONNULL_END
