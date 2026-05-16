//
//  WKGrantLoginVM.m
//  WuKongLogin
//
//  Created by tt on 2020/4/18.
//

#import "WKGrantLoginVM.h"
#import <WuKongIMSDK/WKRSAUtil.h>
@implementation WKGrantLoginVM

+(id) initWithAuthCode:(NSString*)authCode pubkeyBase64Enc:(NSString*)pubkeyBase64Enc{
    WKGrantLoginVM *vm = [WKGrantLoginVM new];
    vm.authCode = authCode;
    vm.pubkeyBase64Enc = pubkeyBase64Enc;
    return vm;
}

-(AnyPromise*) grantLogin {
    // 通过web的公钥加密传输端对端密钥给web TODO: 这里存在安全隐患，暂时没想到更好的办法
//    WKKeyPair *keyPair = [[WKSDK shared].signalManager getLocalIdentityKeyPair];
//    uint32_t localRegistrationId = [[WKSDK shared].signalManager getLocalRegistrationId];
    
//    NSString *rsaPubkey =  self.pubkeyBase64Enc;
//    NSDictionary *param = @{
//        @"pub_key": [keyPair.publicKey base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
//        @"private_key": [keyPair.privateKey base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
//        @"registration_id": @(localRegistrationId),
//    };
//
//    NSString *paramJsonStr = [WKJsonUtil toJson:param];
//
//    NSData *pubKeyData = [[NSData alloc] initWithBase64EncodedString:rsaPubkey options:NSDataBase64DecodingIgnoreUnknownCharacters];
//
//    // pubKeyData
//    NSString *encryptStr = [WKRSAUtil encrypt:paramJsonStr PublicKey:[[NSString alloc] initWithData:pubKeyData encoding:NSUTF8StringEncoding]];
    
    return [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"user/grant_login"] parameters:@{@"auth_code":self.authCode?:@"",@"encrypt":@""}];
}

@end
