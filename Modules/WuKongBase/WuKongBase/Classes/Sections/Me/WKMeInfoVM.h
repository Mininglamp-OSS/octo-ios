//
//  WKMeInfoVM.h
//  WuKongBase
//
//  Created by tt on 2020/6/23.
//

#import "WuKongBase.h"

NS_ASSUME_NONNULL_BEGIN
@class WKMeInfoVM;
@protocol WKMeInfoDelegate<NSObject>

@optional


/// 修改名字
/// @param vm <#vm description#>
-(void) meInfoVMUpdateName:(WKMeInfoVM*)vm;

/// 修改性别
/// @param vm <#vm description#>
-(void) meInfoVMUpdateSex:(WKMeInfoVM*)vm;

/// 修改短编号
/// @param vm <#vm description#>
-(void) meInfoVMUpdateShortNo:(WKMeInfoVM*)vm;

@end

@interface WKMeInfoVM : WKBaseTableVM

@property(nonatomic,weak) id<WKMeInfoDelegate> delegate;

// 手机号 / 邮箱：来自服务端 users/<uid>。phoneEmailLoaded 为 NO 时两行整体不展示，
// 避免拉取中或拉取失败时沿用上一次的旧值；为 YES 后再按值是否为空决定展示内容。
@property(nonatomic,assign) BOOL phoneEmailLoaded;
@property(nonatomic,copy) NSString *phone;
@property(nonatomic,copy) NSString *email;
@property(nonatomic,copy) NSString *zone;

/// 更新我的个人信息
/// @param field 属性
/// @param value 值
-(AnyPromise*) updateInfo:(NSString*)field value:(NSString*)value;

/// 拉取自己的手机号/邮箱（服务端 users/<uid>，本地登录缓存里没有邮箱、手机号也可能是登录时的旧值）
-(AnyPromise*) fetchPhoneEmail;

@end

NS_ASSUME_NONNULL_END
