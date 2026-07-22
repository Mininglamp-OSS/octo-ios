//
//  ACRStringBasedKeyValueObservation.h
//  AdaptiveCards
//
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ACRKeyValueObservationCallback)(NSString * _Nullable keyPath,
                                              NSObject * _Nullable object,
                                              NSDictionary<NSKeyValueChangeKey, id> * _Nullable change);

/// A string-based Key-Value Observation subscriber
/// Uses traditional string-based KVO approach with context pointer to uniquely identify each observer instance
/// and automatically removes the observer on deallocation
@interface ACRStringBasedKeyValueObservation : NSObject

- (instancetype)init NS_UNAVAILABLE;

/// Starts observing the specified keyPath on the given object with provided options
/// - Parameters:
///   - observableObject: The NSObject to observe
///   - observedKeyPath: The keyPath string to observe (must be KVC compliant)
///   - options: The NSKeyValueObservingOptions to specify what changes to observe
///   - callback: The block to call when a change is observed
- (instancetype)initWithObservableObject:(NSObject *)observableObject
                         observedKeyPath:(NSString *)observedKeyPath
                                 options:(NSKeyValueObservingOptions)options
                                callback:(ACRKeyValueObservationCallback)callback;

@end

NS_ASSUME_NONNULL_END
