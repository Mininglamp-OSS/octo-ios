//
//  WKBackoffBuilder.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/30.
//

#import "WKBackoffBuilder.h"

@interface WKBackoffBuilder ()
@end

@implementation WKBackoffBuilder

+ (instancetype)builderWithBlock:(WKBackoffBuilderBlock)block; {
    return [[self alloc] initWithBlock:block];
}

- (id)initWithBlock:(WKBackoffBuilderBlock)block; {
    NSParameterAssert(block);
    
    self = [super init];
    if (self) {
        _base = 100;
        _factor = 2;
        _jitter = 0;
        _cap = LONG_MAX;
        block(self);
    }
    
    return self;
}

@end
