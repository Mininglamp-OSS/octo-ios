//
//  WKLoginVM.h
//  WuKongLogin
//
//  Created by tt on 2019/12/1.
//

#import <WuKongBase/WuKongBase.h>
#import <PromiseKit/PromiseKit.h>
@class WKLoginResp;
NS_ASSUME_NONNULL_BEGIN

@interface WKLoginVM : WKBaseVM

/**
 登录
 
 @param username 用户名
 @param password 密码
 @return 返回
 */
-(AnyPromise*) login:(NSString*) username password:(NSString*)password;



/// 处理登录返回数据
/// @param resp 登录返回数据
/// @param isSave 是否保存登录信息
+(void) handleLoginData:(WKLoginResp*)resp isSave:(BOOL)isSave;
@end


NS_ASSUME_NONNULL_END

@interface WKLoginResp : WKModel

@property(nonatomic,copy) NSString *_Nonnull uid; // 唯一ID
@property(nonatomic,copy) NSString *_Nonnull shortNo; // 唯一短编码
@property(nonatomic,strong) NSNumber * _Nonnull shortStatus; // 短编码状态 0.未设置 1.已设置
@property(nonatomic,copy) NSString * _Nullable  name; // 昵称
@property(nonatomic,strong) NSNumber *_Nonnull sex;
@property(nonatomic,copy) NSString * _Nullable  zone; // 手机区号
@property(nonatomic,copy) NSString * _Nullable  phone; // 手机号
@property(nonatomic,copy) NSString * _Nullable  avatar; // 头像
@property(nonatomic,copy) NSString * _Nonnull token; // api的token
@property(nonatomic,copy) NSString * _Nonnull imToken; // im的token
@property(nonatomic,copy) NSNumber * _Nonnull serverID; // 分配给用户的IM 服务的ID
@property(nonatomic,copy) NSString * _Nonnull chatPwd; // 聊天密码
@property(nonatomic,copy) NSString * _Nullable lockScreenPwd; // 锁屏密码
@property(nonatomic,strong,nonnull) NSNumber *lockAfterMinute; // 多久后锁屏
@property(nonatomic,strong) NSDictionary * _Nullable setting; // 相关设置
@property(nonatomic,copy) NSString * _Nonnull rsaPublicKey; // 服务器公钥

@end
