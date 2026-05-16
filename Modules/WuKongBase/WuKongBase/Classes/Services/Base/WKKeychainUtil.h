//
//  WKKeychainUtil.h
//  WuKongBase
//
//  Created by tt on 2020/10/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKKeychainUtil : NSObject


+ (NSData*)searchKeychainCopyMatchingIdentifier:(NSString*)identifier;

+ (BOOL)createKeychainValue:(NSString*)password forIdentifier:(NSString*)identifier;

+ (BOOL)updateKeychainValue:(NSString*)password forIdentifier:(NSString*)identifier;

+ (void)deleteKeychainValueForIdentifier:(NSString*)identifier;

@end

NS_ASSUME_NONNULL_END
