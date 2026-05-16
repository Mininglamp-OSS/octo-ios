//
//  WKBackoff.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/30.
//

#import "WKBackoff.h"

#define ARC4RANDOM_MAX      0x100000000

@implementation WKBackoff

+ (instancetype)createWithBuilder:(WKBackoffBuilderBlock)block; {
    return [[self alloc] initWithBuilder:[WKBackoffBuilder builderWithBlock:block]];
}

+ (instancetype)create; {
    return [[self alloc] initWithBuilder:[WKBackoffBuilder builderWithBlock:^(WKBackoffBuilder *configuration) {
    }]];
}

- (id)initWithBuilder:(WKBackoffBuilder *)builder; {
    self = [super init];
    
    if (self) {
        _base = builder.base;
        _factor = builder.factor;
        _jitter = builder.jitter;
        _cap = builder.cap;
    }
    
    return self;
}

long max(long x, long y) {
    return x > y ? x : y;
}

long min(long x, long y) {
    return x < y ? x : y;
}

double randomDouble() {
    return floor(((double) arc4random() / ARC4RANDOM_MAX) * 100.0f);
}

- (long)backoff:(int)attempt; {
    long duration = _base * (long) pow(_factor, attempt);
    
    if (_jitter != 0) {
        double random = randomDouble();
        
        int deviation = (int) floor(random * _jitter * duration);
        if ((((int) floor(random * 10)) & 1) == 0) {
            duration = duration - deviation;
        } else {
            duration = duration + deviation;
        }
    }
    
    if (duration < 0) {
        duration = LONG_MAX;
    }
    
    return min(max(duration, _base), _cap);
}

- (void)sleep:(int)attempt; {
    [NSThread sleepForTimeInterval:[self backoff:attempt]];
}

@end
