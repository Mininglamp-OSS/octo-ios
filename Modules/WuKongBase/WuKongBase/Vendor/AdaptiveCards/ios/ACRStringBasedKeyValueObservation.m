//
//  ACRStringBasedKeyValueObservation.m
//  AdaptiveCards
//
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import "ACRStringBasedKeyValueObservation.h"

NS_ASSUME_NONNULL_BEGIN

@interface ACRStringBasedKeyValueObservation ()
/// observable object of interest
@property (weak, nonatomic, nullable) NSObject *observableObject;
/// observed keyPath of interest used to observe the object (must match the KVC compliant property name)
@property (copy, nonatomic) NSString *observedKeyPath;
/// Callback to handle Key-Value Observing notifications
@property (copy, nonatomic) ACRKeyValueObservationCallback callback;
@end

@implementation ACRStringBasedKeyValueObservation

- (instancetype)initWithObservableObject:(NSObject *)observableObject
                         observedKeyPath:(NSString *)observedKeyPath
                                 options:(NSKeyValueObservingOptions)options
                                callback:(ACRKeyValueObservationCallback)callback {
    self = [super init];
    if (self) {
        _observableObject = observableObject;
        _observedKeyPath = [observedKeyPath copy];
        _callback = [callback copy];

        // Use self as unique context
        [observableObject addObserver:self forKeyPath:observedKeyPath options:options context:(__bridge void *)self];
    }
    return self;
}

- (void)dealloc {
    // Automatic cleanup when observer is deallocated
    if (_observableObject) {
        [_observableObject removeObserver:self forKeyPath:_observedKeyPath context:(__bridge void *)self];
    }
}

- (void)observeValueForKeyPath:(NSString * _Nullable)keyPath
                      ofObject:(id _Nullable)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> * _Nullable)change
                       context:(void * _Nullable)context {
    // Check if this notification is for this specific observer instance
    if (context == (__bridge void *)self) {
        self.callback(keyPath, object, change);
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

NS_ASSUME_NONNULL_END
