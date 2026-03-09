//
//  WKLoginVM.m
//  WuKongLogin
//
//  Created by tt on 2019/12/1.
//

#import "WKLoginVM.h"
#import <WuKongBase/WuKongBase.h>
@implementation WKLoginResp

+(WKModel*) fromMap:(NSDictionary*)dictory type:(ModelMapType)type{
    WKLoginResp *loginResp = [WKLoginResp new];
    loginResp.uid = dictory[@"uid"];
    loginResp.shortNo = dictory[@"short_no"]?:@"";
    loginResp.name = dictory[@"name"];
    loginResp.sex = dictory[@"sex"]?:@(0);
    loginResp.zone = dictory[@"zone"]?:@"";
    loginResp.phone = dictory[@"phone"]?:@"";
    loginResp.token = dictory[@"token"];
    loginResp.imToken = dictory[@"im_token"];
    loginResp.avatar = dictory[@"avatar"];
    loginResp.shortStatus = dictory[@"short_status"]?:@(0);
    loginResp.serverID = dictory[@"server_id"]?:@(1);
    loginResp.chatPwd = dictory[@"chat_pwd"]?:@"";
    loginResp.lockScreenPwd = dictory[@"lock_screen_pwd"]?:@"";
    loginResp.lockAfterMinute = dictory[@"lock_after_minute"]?:@(0);
    if(dictory[@"setting"]) {
        loginResp.setting = dictory[@"setting"];
    }
    loginResp.rsaPublicKey = dictory[@"rsa_public_key"];
    return loginResp;
}

//-(NSDictionary*) toMap:(ModelMapType)type{
//    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
//    dic[@"uid"] = self.uid;
//    dic[@"name"] = self.name;
//    dic[@"token"] = self.token;
//    dic[@"avatar"] = self.avatar;
//    return dic;
//}

@end
@implementation WKLoginVM

-(AnyPromise*) login:(NSString*) username password:(NSString*)password {
    
    return  [[WKAPIClient sharedClient] POST:@"user/login" parameters:@{@"username":username,@"password":password,@"device":@{@"device_id":[UIDevice getUUID],@"device_name":[UIDevice getDeviceName],@"device_model":[UIDevice getDeviceModel]}} model:WKLoginResp.class];
   
}

+(void) handleLoginData:(WKLoginResp*)resp isSave:(BOOL)isSave{
    [WKApp shared].loginInfo.token = resp.token;
    if(resp.imToken) {
        [WKApp shared].loginInfo.imToken = resp.imToken;
    }else {
        [WKApp shared].loginInfo.imToken = resp.token;
    }
    [WKApp shared].loginInfo.uid = resp.uid;
    [WKApp shared].loginInfo.extra[@"name"] = resp.name;
    [WKApp shared].loginInfo.extra[@"zone"] = resp.zone;
    [WKApp shared].loginInfo.extra[@"phone"] = resp.phone;
    [WKApp shared].loginInfo.extra[@"short_no"] = resp.shortNo;
    [WKApp shared].loginInfo.extra[@"short_status"] = resp.shortStatus;
    [WKApp shared].loginInfo.extra[@"sex"] = resp.sex;
    [WKApp shared].loginInfo.extra[@"server_id"] = resp.serverID;
    [WKApp shared].loginInfo.extra[@"chat_pwd"] = resp.chatPwd;
    if(resp.lockScreenPwd && ![resp.lockScreenPwd isEqualToString:@""]) {
        [WKApp shared].loginInfo.extra[@"lock_screen_pwd"] = resp.lockScreenPwd;
        [WKApp shared].loginInfo.extra[@"lock_after_minute"] = resp.lockAfterMinute?:@(0);
    }else {
        [[WKApp shared].loginInfo.extra removeObjectForKey:@"lock_screen_pwd"];
        [[WKApp shared].loginInfo.extra removeObjectForKey:@"lock_after_minute"];
    }
    
    if(resp.rsaPublicKey) {
        [WKApp shared].loginInfo.extra[@"rsa_public_key"] = resp.rsaPublicKey;
    }
    
   
    if(resp.setting) {
        [WKApp shared].loginInfo.extra[@"setting"] = resp.setting;
    }
    if(resp.avatar && ![resp.avatar isEqualToString:@""]) {
        [WKApp shared].loginInfo.extra[@"avatar"] = resp.avatar;
    }else{
        NSString *avatarURL = [WKAvatarUtil getAvatar:resp.uid];
        [WKApp shared].loginInfo.extra[@"avatar"] = avatarURL;
    }
    if(isSave) {
        [[WKApp shared].loginInfo save];
    }
}
@end


