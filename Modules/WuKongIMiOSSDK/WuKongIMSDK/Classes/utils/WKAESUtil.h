//
//  WKAESUtil.h
//  WuKongIMSDK
//
//  Created by tt on 2021/2/25.
//

#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
 
/**
 * AES工具类
 */
@interface WKAESUtil : NSObject
 
/**
 * AES加密
 */
+ (NSString *)aesEncrypt:(NSString *)sourceStr key:(NSString*)key iv:(NSString*)iv;
 
/**
 * AES解密
 */
+ (NSString *)aesDecrypt:(NSString *)secretStr key:(NSString*)key iv:(NSString*)iv;
 
@end
