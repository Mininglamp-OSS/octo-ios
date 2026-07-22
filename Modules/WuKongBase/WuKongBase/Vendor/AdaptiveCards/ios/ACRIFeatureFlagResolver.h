//
//  ACRIFeatureFlagResolver.h
//  AdaptiveCards
//
//  Created by Abhishek on 26/08/24.
//  Copyright © 2024 Microsoft. All rights reserved.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ACRIFeatureFlagResolver <NSObject>

- (BOOL)boolForFlag:(NSString *)flag;
- (NSString * _Nullable)stringForFlag:(NSString *)flag;
- (NSNumber *_Nullable)numberForFlag:(NSString *)flag;
- (NSArray *_Nullable)arrayForFlag:(NSString *)flag;
- (NSDictionary *_Nullable)dictForFlag:(NSString *)flag;

@end

NS_ASSUME_NONNULL_END
