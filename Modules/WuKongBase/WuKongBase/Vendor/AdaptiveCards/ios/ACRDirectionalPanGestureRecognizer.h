//
//  ACRDirectionalPanGestureRecognizer.h
//  TeamSpaceApp
//
//  Copyright © Microsoft Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ACRDirectionalPan)
{
    ACRDirectionalPanLeft,
    ACRDirectionalPanRight,
};

@interface ACRDirectionalPanGestureRecognizer : UIPanGestureRecognizer

@property (nonatomic, assign) ACRDirectionalPan direction;

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action direction:(ACRDirectionalPan)direction;

@end

NS_ASSUME_NONNULL_END

