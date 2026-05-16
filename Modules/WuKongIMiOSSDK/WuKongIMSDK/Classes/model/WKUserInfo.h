//
//  WKUser.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKUserInfo : NSObject

-(instancetype) initWithUid:(NSString*)uid name:(NSString*__nullable)name avatar:(NSString* __nullable)avatar;

-(instancetype) initWithUid:(NSString*)uid name:(NSString*)name;
/*!
 用户ID
 */
@property (nonatomic, copy) NSString *uid;

/*!
 用户名称
 */
@property (nonatomic, copy) NSString *name;

/*!
 用户头像的URL
 */
@property (nonatomic, copy) NSString *avatar;

/**
 用户信息附加字段
 */
@property (nonatomic, copy) NSString *extra;

@end

NS_ASSUME_NONNULL_END
