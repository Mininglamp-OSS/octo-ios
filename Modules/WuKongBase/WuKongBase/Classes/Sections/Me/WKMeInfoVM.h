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


/// 更新我的个人信息
/// @param field 属性
/// @param value 值
-(AnyPromise*) updateInfo:(NSString*)field value:(NSString*)value;

@end

NS_ASSUME_NONNULL_END
