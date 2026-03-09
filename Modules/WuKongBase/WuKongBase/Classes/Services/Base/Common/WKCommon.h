//
//  WKCommon.h
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKCommon : NSObject


/**
 常用动画效果
 
 @param block <#block description#>
 */
+(void) commonAnimation:(void(^)(void)) block;

+(void) commonAnimation:(void(^)(void)) block completion:(void(^)(void)) completion;

+(int) iosMajorVersion;

@end

NS_ASSUME_NONNULL_END

