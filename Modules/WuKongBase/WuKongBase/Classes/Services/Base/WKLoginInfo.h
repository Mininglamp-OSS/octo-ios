//
//  WKLoginInfo.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN



@interface WKLoginInfo : NSObject<NSCoding>
+ (WKLoginInfo *)shared;
/**
 用户唯一ID
 */
@property(nonatomic,copy) NSString *uid;

@property(nonatomic,copy) NSString *deviceUUID; // 设备唯一ID，卸载app将会改变

/**
 用户token
 */
@property(nonatomic,copy) NSString *token;

// im token
@property(nonatomic,copy) NSString *imToken;


// 设备token 推送用的
@property(nonatomic,copy) NSString *deviceToken;


/**
 扩展数据
 */
@property(nonatomic,strong) NSMutableDictionary *extra;

-(void) save;

-(void) load;
// 清空所有登录信息
-(void) clear;
// 清除核心数据
-(void) clearMainData;

@end

NS_ASSUME_NONNULL_END
