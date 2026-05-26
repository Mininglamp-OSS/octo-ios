//
//  WKSecurityManager.h
//  WuKongIMSDK
//
//  Created by tt on 2021/2/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKSecurityManager : NSObject

+ (WKSecurityManager *)shared;

@property(nonatomic,copy) NSString *sharedKey; // 共享key


/**
 生成DH密钥对
 */
-(void) generateDHPair;

/**
 获取DH的公钥
 */
-(NSString*) getDHPubKey;

/**
 通过其他的公钥获取共享密钥. 返回 NO 表示输入校验失败 (server 公钥非法 /
 本地 DH key 缺失 / 共享密钥派生失败), 调用方应断开连接, 不要继续走加密
 流程 — 否则后续 nil sharedKey 会进 strlen 崩溃.
 */
-(BOOL) generateAesKey:(NSString*)pubKey salt:(NSString*)salt;

/**
 加密数据
 */
-(NSString*) encryption:(NSString*)data;

/**
 解密
 */
-(NSString*) decryption:(NSString*)data;

- (NSString *)md5:(NSString *)input;

@end

NS_ASSUME_NONNULL_END
