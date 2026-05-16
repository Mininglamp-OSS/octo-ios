//
//  WKScreenPasswordVM.h
//  WuKongBase
//
//  Created by tt on 2021/8/16.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKScreenPasswordSetVM : WKBaseVM


// 请求设置锁屏密码
-(AnyPromise*) requestLockscreenpwd:(NSString*)password;

+(NSString*) digestLockScreenPwd:(NSString*)pwd;

@end

NS_ASSUME_NONNULL_END
