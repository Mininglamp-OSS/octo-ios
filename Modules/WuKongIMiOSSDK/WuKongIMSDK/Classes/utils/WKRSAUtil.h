//
//  WKRSAUtil.h
//  WuKongIMSDK
//
//  Created by tt on 2021/9/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKRSAUtil : NSObject
/**
 * -------RSA 字符串公钥加密-------
 @param plaintext 明文，待加密的字符串
 @param pubKey 公钥字符串
 @return 密文，加密后的字符串
 */
+ (NSString *)encrypt:(NSString *)plaintext PublicKey:(NSString *)pubKey;

/**
 * -------RSA 公钥文件加密-------
 @param plaintext 明文，待加密的字符串
 @param path 公钥文件路径，p12或pem格式
 @return 密文，加密后的字符串
 */
+ (NSString *)encrypt:(NSString *)plaintext KeyFilePath:(NSString *)path;

/**
 * -------RSA 私钥字符串解密-------
 @param ciphertext 密文，需要解密的字符串
 @param privKey 私钥字符串
 @return 明文，解密后的字符串
 */
+ (NSString *)decrypt:(NSString *)ciphertext PrivateKey:(NSString *)privKey;

/**
 * -------RSA 私钥文件解密-------
 @param ciphertext 密文，需要解密的字符串
 @param path 私钥文件路径，p12或pem格式(pem私钥需为pcks8格式)
 @param pwd 私钥文件的密码
 @return 明文，解密后的字符串
 */
+ (NSString *)decrypt:(NSString *)ciphertext KeyFilePath:(NSString *)path FilePwd:(NSString *)pwd;

@end

NS_ASSUME_NONNULL_END
