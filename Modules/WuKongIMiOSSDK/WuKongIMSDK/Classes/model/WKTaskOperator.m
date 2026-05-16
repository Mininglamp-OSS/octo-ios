//
//  WKTaskOperator.m
//  WuKongIMSDK
//
//  Created by tt on 2021/4/22.
//

#import "WKTaskOperator.h"

@implementation WKTaskOperator

+(WKTaskOperator*) cancel:(void(^)(void))cancel suspend:(void(^)(void))suspend resume:(void(^)(void))resume {
    WKTaskOperator *operator = [WKTaskOperator new];
    operator.cancel = cancel;
    operator.suspend = suspend;
    operator.resume = resume;
    return operator;
    
}

@end
