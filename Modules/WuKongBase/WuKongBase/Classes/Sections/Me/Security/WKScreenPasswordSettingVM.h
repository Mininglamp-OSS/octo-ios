//
//  WKScreenPasswordSettingVM.h
//  WuKongBase
//
//  Created by tt on 2021/8/16.
//

#import <WuKongBase/WuKongBase.h>
@class WKScreenPasswordSettingVM;
NS_ASSUME_NONNULL_BEGIN
@protocol WKScreenPasswordSettingVMDelegate <NSObject>

@optional

-(void) screenPasswordSettingVMAutoLockDidClick:(WKScreenPasswordSettingVM*)vm;

// 关闭解锁密码
-(void) screenPasswordSettingVMCloseLockDidClick:(WKScreenPasswordSettingVM*)vm;

// 更改解锁密码
-(void) screenPasswordSettingVMChangeLockDidClick:(WKScreenPasswordSettingVM*)vm;

@end


@interface WKScreenPasswordSettingVM : WKBaseTableVM

@property(nonatomic,weak) id<WKScreenPasswordSettingVMDelegate> delegate;


// 获取锁定的时间描述
-(NSString*) getLockTimeDesc:(NSInteger)minute;

// 请求设置锁屏时间
-(AnyPromise*) requestSetLockAfterMinute;

// 关闭解锁密码
-(AnyPromise*) requestCloseLock;

@end

NS_ASSUME_NONNULL_END
