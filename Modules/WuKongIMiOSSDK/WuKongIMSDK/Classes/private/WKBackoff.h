//
//  WKBackoff.h
//  WuKongIMSDK
//
//  Created by tt on 2019/11/30.
//

#import <Foundation/Foundation.h>
#import "WKBackoffBuilder.h"

//! Project version number for Backo.
FOUNDATION_EXPORT double BackoVersionNumber;

//! Project version string for Backo.
FOUNDATION_EXPORT const unsigned char BackoVersionString[];

@interface WKBackoff : NSObject

@property(readonly) long base;
@property(readonly) int factor;
@property(readonly) double jitter;
@property(readonly) long cap;

+ (instancetype)createWithBuilder:(WKBackoffBuilderBlock)block;

+ (instancetype)create;

/** Return the duration (in milliseconds) for which you should backoff. */
- (long)backoff:(int)attempt;

/** Sleep on the current thread for the duration returned by backoff. */
- (void)sleep:(int)attempt;

@end
