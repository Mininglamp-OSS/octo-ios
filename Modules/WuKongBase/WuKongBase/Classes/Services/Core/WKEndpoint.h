//
//  WKEndpoint.h
//  WuKongCore
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable (^WKHandler)(id param);

@interface WKEndpoint : NSObject

+(WKEndpoint*) initWithSid:(NSString*)sid handler:(id)handler category:(NSString* __nullable)category sort:(NSNumber* __nullable)sort;
+(WKEndpoint*) initWithSid:(NSString*)sid handler:(id)handler category:(NSString* __nullable)category;
+(WKEndpoint*) initWithSid:(NSString*)sid handler:(id)handler;

/**
 端点唯一ID
 */
@property(nonatomic,copy)  NSString  *sid;

/**
 类别
 */
@property(nonatomic,copy) NSString  *category;


/**
 顺序 越大越靠前
 */
@property(nonatomic,strong) NSNumber *sort;

// 所属模块ID
@property(nonatomic,copy,nullable) NSString *moduleID;

/**
 端点具体处理逻辑
 */
@property(nonatomic,copy) WKHandler handler;

@end

NS_ASSUME_NONNULL_END
