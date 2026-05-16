//
//  WKBackoffBuilder.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/30.
//

#import <Foundation/Foundation.h>

#import <Foundation/Foundation.h>

/** Fluent API to construct instances of SEGBacko. */
@class WKBackoffBuilder;

typedef void(^WKBackoffBuilderBlock)(WKBackoffBuilder *builder);

@interface WKBackoffBuilder : NSObject

@property(nonatomic, readwrite) long base;
@property(nonatomic, readwrite) int factor;
@property(nonatomic, readwrite) double jitter;
@property(nonatomic, readwrite) long cap;

+ (instancetype)builderWithBlock:(WKBackoffBuilderBlock)block;

- (id)initWithBlock:(WKBackoffBuilderBlock)block NS_DESIGNATED_INITIALIZER;

@end
