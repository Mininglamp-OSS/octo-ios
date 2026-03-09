//
//  WKChannelInfo.m
//  WuKongIMSDK
//
//  Created by tt on 2019/12/23.
//

#import "WKChannelInfo.h"


@interface WKChannelInfo ()


@end

@implementation WKChannelInfo


- (NSMutableDictionary *)extra {
    if(!_extra) {
        _extra = [[NSMutableDictionary alloc] init];
    }
    return _extra;
}

- (NSString *)displayName {
    if(!self.remark || [self.remark isEqualToString:@""]) {
        return self.name;
    }
    return self.remark;
}

-(id) extraValueForKey:(WKChannelExtraKey)key {
    return [self extraValueForKey:key defaultValue:nil];
}

-(id) extraValueForKey:(WKChannelExtraKey)key defaultValue:(id)value {
    id v=  self.extra[key];
    if(v) {
        return v;
    }
    return value;
}

- (void)setExtraValue:(id)value forKey:(WKChannelExtraKey)key {
    self.extra[key] = value;
}

- (BOOL)settingForKey:(WKChannelExtraKey)key defaultValue:(BOOL)on {
    id value = [self extraValueForKey:key defaultValue:@(on)];
    if(value) {
        return [value boolValue];
    }
    return on;
}

- (void)setSettingValue:(BOOL)on forKey:(WKChannelExtraKey)key {
    [self setExtraValue:@(on) forKey:key];
}


- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    WKChannelInfo *channelInfo = [WKChannelInfo allocWithZone:zone];
    channelInfo.channel = [WKChannel channelID:self.channel.channelId channelType:self.channel.channelType];
    channelInfo.follow = self.follow;
    channelInfo.name = self.name;
    channelInfo.remark = self.remark;
    channelInfo.notice = self.notice;
    channelInfo.logo = self.logo;
    channelInfo.stick = self.stick;
    channelInfo.mute = self.mute;
    channelInfo.showNick = self.showNick;
    channelInfo.save = self.save;
    channelInfo.forbidden = self.forbidden;
    channelInfo.invite = self.invite;
    channelInfo.version = self.version;
    channelInfo.status = self.status;
    channelInfo.online = self.online;
    channelInfo.receipt = self.receipt;
    channelInfo.category = self.category;
    channelInfo.lastOffline = self.lastOffline;
    channelInfo.robot = self.robot;
    channelInfo.extra = [self.extra mutableCopy];
    return channelInfo;
}

@end
