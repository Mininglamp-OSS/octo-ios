//
// TSExpressionObjCBridge.h
//  AdaptiveCards
//
//  Created by Rahul Pinjani on 8/12/25.
//

#import "TSExpressionObjCBridge.h"
#import <AdaptiveCards/AdaptiveCards-Swift.h>

@implementation TSExpressionObjCBridge

+ (void)evaluateExpression:(NSString *)expression
                  withData:(NSDictionary * _Nullable)data
                 completion:(void (^)(id _Nullable result, NSError * _Nullable error))completion {
    [ObjCExpressionEvaluator evaluateExpression:expression withData:data completion:^(NSObject * _Nullable result, NSError * _Nullable error) {
        if (completion) {
            completion(result, error);
        }
    }];
}

+ (void)setExpressionEvalEnabled:(BOOL)enabled
{
    [ObjCExpressionEvaluator setExpressionEvalEnabled:enabled];
}

+ (BOOL)isExpressionEvalEnabled
{
    return [ObjCExpressionEvaluator isExpressionEvalEnabled];
}

@end
