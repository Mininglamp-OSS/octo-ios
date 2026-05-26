//
//  WKSecurityManager.m
//  WuKongIMSDK
//
//  Created by tt on 2021/2/24.
//

#import "WKSecurityManager.h"
#import <WuKongIMSDK/WuKongIMSDK-Swift.h>
#import<CommonCrypto/CommonDigest.h>
#import "WKAESUtil.h"
@interface WKSecurityManager ()

@property(nonatomic,strong) WKECKeyPair *curve25519Key;
@property(nonatomic,copy) NSString *aesKey;
@property(nonatomic,copy) NSString *aesIV;
@end

@implementation WKSecurityManager

static WKSecurityManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKSecurityManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(void) generateDHPair {
    self.curve25519Key = [WKCurve25519 generateKeyPair];
}

-(NSString*) getDHPubKey {
    return [self.curve25519Key.publicKey base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

-(BOOL) generateAesKey:(NSString*)pubKey salt:(NSString*)salt {
    // 防御: server 传的 pubkey 非法 / 本地 DH 未生成 → 提前失败,
    // 不要让 nil sharedKey 流到 md5: 的 strlen(NULL) 崩溃.
    if (pubKey.length == 0) return NO;
    if (!self.curve25519Key) return NO;

    NSData *pubKeyData = [[NSData alloc] initWithBase64EncodedString:pubKey options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (pubKeyData.length != 32) return NO;

    NSData *sharedKeyData = [WKCurve25519 sharedSecretFromPublicKey:pubKeyData keyPair:self.curve25519Key];
    if (sharedKeyData.length == 0) return NO;

    self.sharedKey =  [sharedKeyData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];

    NSString *aesKeyFull = [self md5:self.sharedKey];
    self.aesKey = [aesKeyFull substringToIndex:16];

    if(salt && salt.length>16) {
        self.aesIV = [salt substringToIndex:16];
    }else{
        self.aesIV = salt;
    }
    return YES;
}


- (NSString *)md5:(NSString *)input{
    const char *cStr = [input UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];

    CC_MD5( cStr, (CC_LONG)strlen(cStr), digest ); // This is the md5 call

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
           [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

-(NSString*) encryption:(NSString*)data {
    return [WKAESUtil aesEncrypt:data key:self.aesKey iv:self.aesIV];
}

-(NSString*) decryption:(NSString*)data {
    return [WKAESUtil aesDecrypt:data key:self.aesKey iv:self.aesIV];
}

@end
