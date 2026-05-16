//
//  NSString+WK.m
//  WuKongBase
//
//  Created by tt on 2021/8/4.
//

#import "NSString+WK.h"

@implementation NSString (WK)

//ascii算一个 中文算2个 emoji算2个(不标准的做法，根据substringRange可以计算出准确的字节长度)
- (NSString *)limitedStringForMaxBytesLength:(NSUInteger)maxLength {
    __block NSUInteger asciiLength = 0;
    __block NSUInteger subStringRangeLen = 0;
    [self enumerateSubstringsInRange:NSMakeRange(0, self.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
                              unichar uc = [substring characterAtIndex:0];
                              //英文和汉字length都是1
                              if (substringRange.length == 1) {
                                  //这里还有个坑， 有些空格是(uc == 0x2006)，不会被 isblank和 isspace命中
                                  //如果不允许出现空格，建议先取出string中的空格
                                  if (isblank(uc) || isspace(uc) || (uc == 0x2006)) {
                                      asciiLength += 1;
                                  } else if (isascii(uc)) {
                                      asciiLength += 1;
                                  } else {
                                      //汉字这里
                                      asciiLength += 2;
                                  }
                              } else {
                                  //表情符号这里
                                  asciiLength += 2;
                              }
                              if (asciiLength <= maxLength) {
                                  subStringRangeLen = substringRange.location + substringRange.length;
                              }
                          }];
    return [self substringWithRange:NSMakeRange(0, subStringRangeLen)];
}

@end
