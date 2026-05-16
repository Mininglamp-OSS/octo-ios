//
//  WKMoneyUtil.h
//  WuKongBase
//
//  Created by tt on 2020/8/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKMoneyUtil : NSObject

// 分转元并格式化
+ (NSString *)penny2YuanFormat:(NSNumber *)penny;
// 分转元
+ (NSNumber *)penny2Yuan:(NSNumber *)penny;

//元转分
+ (NSNumber *)yuan2Penny:(NSNumber *)yuan;

@end

NS_ASSUME_NONNULL_END
