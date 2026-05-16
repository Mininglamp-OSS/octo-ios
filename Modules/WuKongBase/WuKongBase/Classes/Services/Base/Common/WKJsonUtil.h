//
//  WKJsonUtil.h
//  WuKongBase
//
//  Created by tt on 2020/7/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKJsonUtil : NSObject

+ (NSString *)toJson:(id)obj;

+ (NSDictionary *)toDic:(NSString *)jsonStr;

+(NSArray*) toArray:(NSString*)jsonStr;

@end

NS_ASSUME_NONNULL_END
