//
//  ACOAdaptiveCard.h
//  ACOAdaptiveCard
//
//  Copyright © 2017 Microsoft. All rights reserved.
//

#ifdef SWIFT_PACKAGE
/// Swift Package Imports
#import "ACOAdaptiveCardParseResult.h"
#import "ACOAuthentication.h"
#import "ACORefresh.h"
#import "ACORemoteResourceInformation.h"
#import "ACRIBaseInputHandler.h"
#else
/// Cocoapods Imports
#import <AdaptiveCards/ACOAdaptiveCardParseResult.h>
#import <AdaptiveCards/ACOAuthentication.h>
#import <AdaptiveCards/ACORefresh.h>
#import <AdaptiveCards/ACORemoteResourceInformation.h>
#import <AdaptiveCards/ACRIBaseInputHandler.h>
#endif
#import <Foundation/Foundation.h>

@class SwiftAdaptiveCardParseResult;
@class ACOReference;

@interface ACOAdaptiveCard : NSObject

@property (nullable, nonatomic, strong) ACORefresh *refresh;
@property (nullable, nonatomic, strong) ACOAuthentication *authentication;
@property BOOL shouldNotRenderActions;

+ (nonnull ACOAdaptiveCardParseResult *)fromJson:(nullable NSString *)payload;
- (nullable NSData *)inputs;
- (nullable NSArray<ACRIBaseInputHandler> *)getInputs;
- (void)setInputs:(nonnull NSArray *)inputs;
- (void)appendInputs:(nonnull NSArray *)inputs;
- (nullable NSArray<ACORemoteResourceInformation *> *)remoteResourceInformation;
- (nullable NSData *)additionalProperty;
- (nullable NSArray<ACOReference *> *)references;

/// Swift Adaptive Card Bridge Layer
- (nullable SwiftAdaptiveCardParseResult *)swiftParseResult;
+ (BOOL)isSwiftParserEnabled;
+ (void)setSwiftParserEnabled:(BOOL)enabled;

/// Expression Engine Adaptive Card Bridge 
+ (BOOL)isExpressionEvalEnabled;
+ (void)setExpressionEvalEnabled:(BOOL)enabled;
+ (void)evaluateExpression:(NSString * _Nonnull)expression
                  withData:(NSDictionary * _Nullable)data
                completion:(void (^_Nullable)(id _Nullable result, NSError * _Nullable error))completion;

@end
