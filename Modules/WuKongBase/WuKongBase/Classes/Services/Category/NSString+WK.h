//
//  NSString+WK.h
//  WuKongBase
//
//  Created by tt on 2021/8/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (WK)

- (NSString *)limitedStringForMaxBytesLength:(NSUInteger)maxLength;

@end

NS_ASSUME_NONNULL_END
