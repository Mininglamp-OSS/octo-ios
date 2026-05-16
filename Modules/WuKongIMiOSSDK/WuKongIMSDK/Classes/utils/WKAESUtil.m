//
//  WKAESUtil.m
//  WuKongIMSDK
//
//  Created by tt on 2021/2/25.
//

#import "WKAESUtil.h"

#import <Foundation/Foundation.h>
 
@interface WKAESUtil()
 
@end
 

 
@implementation WKAESUtil
 
+ (NSString *)aesEncrypt:(NSString *)sourceStr key:(NSString*)key iv:(NSString*)iv{
    if (!sourceStr) {
        return nil;
    }
    
    NSData *data = [sourceStr dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *aesData = [self AES128operation:kCCEncrypt
                                           data:data
                                            key:key
                                             iv:iv];
    return [aesData base64EncodedStringWithOptions:0];

}
 
+ (NSString *)aesDecrypt:(NSString *)secretStr key:(NSString*)key iv:(NSString*)iv{
    if (!secretStr) {
        return nil;
    }
    //先对加密的字符串进行base64解码
    NSData *decodeData = [[NSData alloc] initWithBase64EncodedString:secretStr options:0];
     
    NSData *aesData = [self AES128operation:kCCDecrypt
                                           data:decodeData
                                            key:key
                                             iv:iv];
    return  [[NSString alloc] initWithData:aesData encoding:NSUTF8StringEncoding];
}


/**
 *  AES加解密算法
 *
 *  @param operation kCCEncrypt（加密）kCCDecrypt（解密）
 *  @param data      待操作Data数据
 *  @param key       key
 *  @param iv        向量
 *
 *
 */
+ (NSData *)AES128operation:(CCOperation)operation data:(NSData *)data key:(NSString *)key iv:(NSString *)iv {
    
    char keyPtr[kCCKeySizeAES128 + 1];  //kCCKeySizeAES128是加密位数 可以替换成256位的
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    // IV
    char ivPtr[kCCBlockSizeAES128 + 1];
    bzero(ivPtr, sizeof(ivPtr));
    [iv getCString:ivPtr maxLength:sizeof(ivPtr) encoding:NSUTF8StringEncoding];
    
    size_t bufferSize = [data length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    
    // 设置加密参数
    /**
        这里设置的参数ios默认为CBC加密方式，如果需要其他加密方式如ECB，在kCCOptionPKCS7Padding这个参数后边加上kCCOptionECBMode，即kCCOptionPKCS7Padding | kCCOptionECBMode，但是记得修改上边的偏移量，因为只有CBC模式有偏移量之说
    */
    CCCryptorStatus cryptorStatus = CCCrypt(operation, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                            keyPtr, kCCKeySizeAES128,
                                            ivPtr,
                                            [data bytes], [data length],
                                            buffer, bufferSize,
                                            &numBytesEncrypted);
    
    if(cryptorStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
        
    } else {
        NSLog(@"Error");
    }
    
    free(buffer);
    return nil;
}


@end
