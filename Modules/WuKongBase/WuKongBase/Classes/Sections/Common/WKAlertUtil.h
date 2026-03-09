//
//  WKAlertUtil.h
//  WuKongBase
//
//  Created by tt on 2020/1/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAlertUtil : NSObject

+(void) alert:(NSString*)msg;

+(void) alert:(NSString*)msg title:(NSString*)title;

+(void) alert:(NSString*)msg buttonsStatement:(NSArray<NSString*>*)arrayItems chooseBlock:(void (^)(NSInteger buttonIdx))block;

+(void) alert:(NSString*)msg targetVC:(UIViewController*)targetVC buttonsStatement:(NSArray<NSString*>*)arrayItems chooseBlock:(void (^)(NSInteger buttonIdx))block;


@end

NS_ASSUME_NONNULL_END
