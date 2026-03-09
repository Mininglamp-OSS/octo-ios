//
//  WKChannelUtil.m
//  WuKongBase
//
//  Created by tt on 2021/8/4.
//

#import "WKChannelUtil.h"
#import "WKApp.h"
@implementation WKChannelUtil

+ (WKChannelInfo *)toChannelInfo2:(NSDictionary*)resultDict {
    WKChannelInfo *channelInfo = [WKChannelInfo new];
    NSDictionary *channelDict = resultDict[@"channel"];
    if(channelDict) {
        channelInfo.channel = [[WKChannel alloc] initWith:channelDict[@"channel_id"] channelType:[channelDict[@"channel_type"] intValue]];
    }
    
    NSDictionary *parentChannelDict = resultDict[@"parent_channel"];
    if(parentChannelDict && parentChannelDict[@"channel_id"] && ![parentChannelDict[@"channel_id"] isEqualToString:@""]) {
        channelInfo.parentChannel = [[WKChannel alloc] initWith:parentChannelDict[@"channel_id"] channelType:[parentChannelDict[@"channel_type"] intValue]];
    }
    
    channelInfo.name = resultDict[@"name"]?:@"";
    channelInfo.logo = resultDict[@"logo"]?:@"";
    if([channelInfo.logo isEqualToString:@""]) {
        if(channelInfo.channel.channelType == WK_PERSON) {
            channelInfo.logo = [NSString stringWithFormat:@"users/%@/avatar",channelInfo.channel.channelId];
        }else if(channelInfo.channel.channelType == WK_GROUP) {
            channelInfo.logo = [NSString stringWithFormat:@"groups/%@/avatar",channelInfo.channel.channelId];
        }
    }
    channelInfo.remark = resultDict[@"remark"]?:@"";
    channelInfo.status = resultDict[@"status"]? [resultDict[@"status"] integerValue]:0;
    
    channelInfo.online = resultDict[@"online"]?[resultDict[@"online"] boolValue]:false;
    channelInfo.lastOffline = [resultDict[@"last_offline"] integerValue];
    if(resultDict[@"device_flag"]) {
        channelInfo.deviceFlag = [resultDict[@"device_flag"] integerValue];
    }
    
    channelInfo.receipt = resultDict[@"receipt"]?[resultDict[@"receipt"] boolValue]:false;
    channelInfo.robot = resultDict[@"robot"]?[resultDict[@"robot"] boolValue]:false;
    channelInfo.category = resultDict[@"category"]?:@"";
    channelInfo.stick = resultDict[@"stick"]?[resultDict[@"stick"] boolValue]:false;
    channelInfo.mute = resultDict[@"mute"]?[resultDict[@"mute"] boolValue]:false;
    channelInfo.showNick =resultDict[@"show_nick"]?[resultDict[@"show_nick"] boolValue]:false;
    channelInfo.follow = resultDict[@"follow"]?[resultDict[@"follow"] integerValue]:WKChannelInfoFollowStrange;
    
    channelInfo.beBlacklist = resultDict[@"be_blacklist"]?[resultDict[@"be_blacklist"] boolValue]:false;
    channelInfo.beDeleted = resultDict[@"be_deleted"]?[resultDict[@"be_deleted"] boolValue]:false;
    
    channelInfo.notice = resultDict[@"notice"]?:@"";
    channelInfo.save = resultDict[@"save"]?[resultDict[@"save"] boolValue]:false;
    channelInfo.forbidden = resultDict[@"forbidden"]?[resultDict[@"forbidden"] boolValue]:false;
    channelInfo.invite = resultDict[@"invite"]?[resultDict[@"invite"] boolValue]:false;
    
    channelInfo.flame = resultDict[@"flame"]?[resultDict[@"flame"] boolValue]:false;
    channelInfo.flameSecond = resultDict[@"flame_second"]?[resultDict[@"flame_second"] integerValue]:0;
    
    NSDictionary *extra =  resultDict[@"extra"];
    if(extra && extra != [NSNull null]) {
        channelInfo.extra = [NSMutableDictionary dictionaryWithDictionary:extra];
    }
    
    return channelInfo;
}

+ (WKChannelInfo *)toChannelInfo:(NSDictionary*)resultDict {
    WKChannelInfo *channelInfo  = [WKChannelInfo new];
    channelInfo.channel = [[WKChannel alloc] initWith:resultDict[@"uid"] channelType:WK_PERSON];
    channelInfo.name = resultDict[@"name"];
    channelInfo.mute = resultDict[@"mute"]?[resultDict[@"mute"] boolValue]:false;
    channelInfo.stick = resultDict[@"top"]?[resultDict[@"top"] boolValue]:false;
    channelInfo.logo = resultDict[@"avatar"];
    if(!channelInfo.logo || [channelInfo.logo isEqualToString:@""]) {
        channelInfo.logo = [NSString stringWithFormat:@"users/%@/avatar",resultDict[@"uid"]];
    }
    channelInfo.extra[@"sex"] = resultDict[@"sex"];
    
    channelInfo.receipt = resultDict[@"receipt"]?[resultDict[@"receipt"] boolValue]:false;
    channelInfo.robot = resultDict[@"robot"]?[resultDict[@"robot"] boolValue]:false;
    
    channelInfo.online = resultDict[@"online"]?[resultDict[@"online"] boolValue]:false;
    channelInfo.lastOffline = [resultDict[@"last_offline"] integerValue];
    if(resultDict[@"device_flag"]) {
        channelInfo.deviceFlag = [resultDict[@"device_flag"] integerValue];
    }
    
    channelInfo.category = resultDict[@"category"];
    channelInfo.follow = resultDict[@"follow"]?[resultDict[@"follow"] integerValue]:WKChannelInfoFollowStrange;
    channelInfo.remark = resultDict[@"remark"]?resultDict[@"remark"]:@"";
    if(resultDict[@"chat_pwd_on"]) {
        [channelInfo setSettingValue:[resultDict[@"chat_pwd_on"] boolValue] forKey:WKChannelExtraKeyChatPwd];
    }else{
        [channelInfo setSettingValue:false forKey:WKChannelExtraKeyChatPwd];
    }
    if(resultDict[@"status"]) {
        channelInfo.status = [resultDict[@"status"] integerValue];
    }
    if(resultDict[@"short_no"]) {
        [channelInfo setExtraValue:resultDict[@"short_no"] forKey:WKChannelExtraKeyShortNo];
    }
    if(resultDict[@"source_desc"]) {
        [channelInfo setExtraValue:resultDict[@"source_desc"] forKey:WKChannelExtraKeySource];
    }
    if(resultDict[@"vercode"]) {
        [channelInfo setExtraValue:resultDict[@"vercode"] forKey:WKChannelExtraKeyVercode];
    }
    if(resultDict[@"screenshot"]) {
        [channelInfo setSettingValue:[resultDict[@"screenshot"] boolValue] forKey:WKChannelExtraKeyScreenshot];
    }
    if(resultDict[@"revoke_remind"]) {
        [channelInfo setSettingValue:[resultDict[@"revoke_remind"] boolValue] forKey:WKChannelExtraKeyRevokeRemind];
    }
    if(resultDict[@"allow_view_history_msg"]) {
        [channelInfo setSettingValue:[resultDict[@"allow_view_history_msg"] boolValue] forKey:WKChannelExtraKeyAllowViewHistoryMsg];
    }
    channelInfo.beBlacklist = resultDict[@"be_blacklist"]?[resultDict[@"be_blacklist"] boolValue]:false;
    channelInfo.beDeleted = resultDict[@"be_deleted"]?[resultDict[@"be_deleted"] boolValue]:false;
    return channelInfo;
}

+(WKGroupType) groupType:(WKChannelInfo*)channelInfo {
    if(!channelInfo) {
        return WKGroupTypeCommon;
    }
    if(channelInfo.extra[@"group_type"]) {
        return [channelInfo.extra[@"group_type"] intValue];
    }
    return WKGroupTypeCommon;
}

@end
