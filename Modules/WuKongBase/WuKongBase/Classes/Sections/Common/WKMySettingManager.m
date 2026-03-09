//
//  WKMySettingManager.m
//  WuKongBase
//
//  Created by tt on 2021/8/18.
//

#import "WKMySettingManager.h"

@implementation WKMySettingManager

+ (instancetype)shared{
    static WKMySettingManager *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[WKMySettingManager alloc] init];
    });
    
    return _shared;
}


/// 新消息通知
/// @param on <#on description#>
- (AnyPromise *)newMsgNotice:(BOOL)on {
    return [self setting:@"new_msg_notice" on:on];
}

/// 通知是否显示详情
/// @param on <#on description#>
- (AnyPromise *)msgShowDetail:(BOOL)on{
    return [self setting:@"msg_show_detail" on:on];
}
/// 开启声音
/// @param on <#on description#>
- (AnyPromise *)voiceOn:(BOOL)on{
    return [self setting:@"voice_on" on:on];
}
/// 开启震动
/// @param on <#on description#>
- (AnyPromise *)shockOn:(BOOL)on{
    return [self setting:@"shock_on" on:on];
}

- (AnyPromise *)searchByPhone:(BOOL)on {
    return [self setting:@"search_by_phone" on:on];
}

- (AnyPromise *)searchByShort:(BOOL)on {
    return [self setting:@"search_by_short" on:on];
}

-(AnyPromise*) offlineProtection:(BOOL)on {
    return [self setting:@"offline_protection" on:on];
}

-(AnyPromise*) muteOfApp:(BOOL)on {
    return [self setting:@"mute_of_app" on:on];
}


- (BOOL)newMsgNotice {
    return [self setting:@"new_msg_notice"];
}

- (BOOL)msgShowDetail {
    return [self setting:@"msg_show_detail"];
}

- (BOOL)voiceOn {
    return [self setting:@"voice_on"];
}

- (BOOL)shockOn {
    return [self setting:@"shock_on"];
}

- (BOOL)searchByPhone {
    return [self setting:@"search_by_phone"];
}

- (BOOL)searchByShort {
    return [self setting:@"search_by_short"];
}

- (BOOL)offlineProtection {
    return [self setting:@"offline_protection"];
}

- (BOOL)muteOfApp {
    return [self setting:@"mute_of_app"];
}



-(AnyPromise*) setting:(NSString*)key on:(BOOL)on {
    __weak typeof(self) weakSelf = self;
    [weakSelf saveSetting:key on:on];
   return [[WKAPIClient sharedClient] PUT:@"user/my/setting" parameters:@{key:(on?@(1):@(0))}].then(^{
      
    }).catch(^(NSError*error){
        WKLogError(@"设置失败！->%@",error);
    });
}

-(BOOL) setting:(NSString*)key {
    NSDictionary *settingDict = [WKApp shared].loginInfo.extra[@"setting"];
    if(settingDict && settingDict[key]) {
        return [settingDict[key] boolValue];
    }
    return false;
}

-(void) saveSetting:(NSString*)key on:(BOOL)on {
   NSDictionary *settingDict = [WKApp shared].loginInfo.extra[@"setting"];
    
    NSMutableDictionary *newSettingDict;
    if(settingDict) {
        newSettingDict = [NSMutableDictionary dictionaryWithDictionary:settingDict];
    }else{
        newSettingDict = [NSMutableDictionary dictionary];
    }
    newSettingDict[key] = on?@(1):@(0);
    [WKApp shared].loginInfo.extra[@"setting"] = newSettingDict;
    [[WKApp shared].loginInfo save];
}


@end
