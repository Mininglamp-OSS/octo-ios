//
//  WKMoneyUtil.m
//  WuKongBase
//
//  Created by tt on 2020/8/30.
//

#import "WKMoneyUtil.h"

@implementation WKMoneyUtil


+ (NSString *)penny2YuanFormat:(NSNumber *)penny {
  NSNumber *number = [WKMoneyUtil penny2Yuan:penny];
  NSString *str = number.stringValue;
  if ([str rangeOfString:@"."].length == 0) {
    str = [str stringByAppendingString:@".00"];
  } else {

    NSRange range = [str rangeOfString:@"."];

    if (str.length - range.location - 1 == 2) {
    } else {
      str = [str stringByAppendingString:@"0"];
    }
  }
  return str;
}

// 分转元
+ (NSNumber *)penny2Yuan:(NSNumber *)penny {
  NSDecimalNumberHandler *roundUp = [NSDecimalNumberHandler
      decimalNumberHandlerWithRoundingMode:NSRoundBankers
                                     scale:2
                          raiseOnExactness:NO
                           raiseOnOverflow:NO
                          raiseOnUnderflow:NO
                       raiseOnDivideByZero:YES];
  NSDecimalNumber *pennyNumber =
      [NSDecimalNumber decimalNumberWithString:penny.stringValue];
  NSDecimalNumber *number100 = [NSDecimalNumber decimalNumberWithString:@"100"];

  return [pennyNumber decimalNumberByDividingBy:number100 withBehavior:roundUp];
}

//元转分
+ (NSNumber *)yuan2Penny:(NSNumber *)yuan {
  NSDecimalNumber *yuanNumber =
      [NSDecimalNumber decimalNumberWithString:yuan.stringValue];
  NSDecimalNumber *number100 = [NSDecimalNumber decimalNumberWithString:@"100"];

  return [yuanNumber decimalNumberByMultiplyingBy:number100];
}

@end
