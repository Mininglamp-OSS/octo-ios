//
//  WKContacts.h
//  WuKongBase
//
//  Created by tt on 2019/12/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 选择模式
typedef enum : NSUInteger {
    WKContactsModeMulti, // 多选模式
    WKContactsModeSingle, // 单选模式
} WKContactsMode;

@interface WKContacts : NSObject
// 用户uid
@property(nonatomic,copy) NSString *uid;
// 联系人头像
@property(nonatomic,copy) NSString *avatar;
// 联系人姓名
@property(nonatomic,copy) NSString *name;
// 展示名字
@property(nonatomic,copy) NSString *displayName;
// 扩展字段
@property(nonatomic,strong) NSDictionary *extra;
@end



NS_ASSUME_NONNULL_END
