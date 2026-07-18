//
//  SwiftAdaptiveCardParserBridge.h
//  AdaptiveCards
//
//  Created by Hugo Gonzalez on 2/4/25.
//  Copyright © 2025 Microsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SwiftAdaptiveCardParseResult;

@interface SwiftAdaptiveCardObjcBridge : NSObject

+ (NSMutableArray *_Nullable)getWarningsFromParseResult:(id _Nullable )parseResult useSwift:(BOOL)useSwift;

+ (BOOL)isSwiftParserEnabled;
+ (void)setSwiftParserEnabled:(BOOL)enabled;
+ (SwiftAdaptiveCardParseResult * _Nonnull)parseWithPayload:(NSString *_Nonnull)payload;
+ (BOOL)isParseResultSuccessful:(SwiftAdaptiveCardParseResult *_Nonnull)result;
@end
