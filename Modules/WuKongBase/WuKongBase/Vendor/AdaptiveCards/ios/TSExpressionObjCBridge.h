//
// TSExpressionObjCBridge.h
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSExpressionObjCBridge : NSObject
+ (BOOL)isExpressionEvalEnabled;
+ (void)setExpressionEvalEnabled:(BOOL)enabled;
+ (void)evaluateExpression:(NSString *)expression
                  withData:(NSDictionary * _Nullable)data
                completion:(void (^)(id _Nullable result, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
