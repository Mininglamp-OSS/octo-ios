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

    // Bot 创建者 uid：服务端在顶层下发 bot_creator_uid（仅 robot 频道），存入 extra
    // 供撤回菜单判定「自己创建的 Bot 消息可撤回」(对齐 web orgData.bot_creator_uid)。
    // 放在 extra 整块赋值之后，避免被上面覆盖。
    id botCreatorUid = resultDict[@"bot_creator_uid"];
    if([botCreatorUid isKindOfClass:[NSString class]] && [(NSString*)botCreatorUid length] > 0) {
        channelInfo.extra[@"bot_creator_uid"] = botCreatorUid;
    }

    // GROUP.md 状态：优先顶层字段，兜底 extra（与 Web 端对齐）
    if (resultDict[@"has_group_md"]) {
        channelInfo.extra[@"has_group_md"] = resultDict[@"has_group_md"];
    }
    if (resultDict[@"group_md_version"]) {
        channelInfo.extra[@"group_md_version"] = resultDict[@"group_md_version"];
    }
    if (resultDict[@"has_thread_md"]) {
        channelInfo.extra[@"has_thread_md"] = resultDict[@"has_thread_md"];
    }
    if (resultDict[@"thread_md_version"]) {
        channelInfo.extra[@"thread_md_version"] = resultDict[@"thread_md_version"];
    }
    // ---------- 外部群 (External Group) Phase 1 ----------
    // 外部群标识：来自 GroupResp.is_external_group（与 Web 端对齐）。NSNull 防御：仅接受 NSNumber/NSString。
    id externalGroupRaw = resultDict[@"is_external_group"];
    if([externalGroupRaw isKindOfClass:[NSNumber class]] || [externalGroupRaw isKindOfClass:[NSString class]]) {
        channelInfo.extra[@"is_external_group"] = @([externalGroupRaw integerValue] == 1 ? 1 : 0);
    }
    // allow_external: 是否允许邀请外部成员
    id allowExternalRaw = resultDict[@"allow_external"];
    if([allowExternalRaw isKindOfClass:[NSNumber class]] || [allowExternalRaw isKindOfClass:[NSString class]]) {
        channelInfo.extra[@"allow_external"] = @([allowExternalRaw integerValue] == 1 ? 1 : 0);
    }
    // 群归属 space_id（客户端过滤兜底 — 策略 B：不完全信任后端 SetEffectiveSpaceID）
    id spaceIdRaw = resultDict[@"space_id"];
    if([spaceIdRaw isKindOfClass:[NSString class]] && [(NSString*)spaceIdRaw length] > 0) {
        channelInfo.extra[@"space_id"] = spaceIdRaw;
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

    // Bot 创建者 uid：服务端 /users/<uid> 顶层下发 bot_creator_uid（仅 robot），存入 extra
    // 供撤回菜单判定「自己创建的 Bot 消息可撤回」(对齐 web orgData.bot_creator_uid)。
    id botCreatorUid = resultDict[@"bot_creator_uid"];
    if([botCreatorUid isKindOfClass:[NSString class]] && [(NSString*)botCreatorUid length] > 0) {
        channelInfo.extra[@"bot_creator_uid"] = botCreatorUid;
    }

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

#pragma mark - 实名认证（/ Phase A）

// Tri-state：nil=字段缺失 / @YES=显式真 / @NO=显式假（P1-2）。
// 调用方用这个区分决定是否 fallback 到 person cache。
+(NSNumber *) isRealnameVerifiedFromExtra:(NSDictionary *)extra {
    if(!extra || ![extra isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id val = extra[@"realname_verified"];
    if(!val || val == [NSNull null]) {
        return nil;
    }
    if([val isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)val boolValue] ? @YES : @NO;
    }
    if([val isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)val;
        if([s isEqualToString:@"1"] || [s isEqualToString:@"true"] || [s isEqualToString:@"YES"]) {
            return @YES;
        }
        if([s isEqualToString:@"0"] || [s isEqualToString:@"false"] || [s isEqualToString:@"NO"] || s.length == 0) {
            return @NO;
        }
        // 其他字符串（未预期值）：按「字段存在但无法识别」视作 nil，让 fallback 生效
        return nil;
    }
    // 非 NSNumber / NSString 类型：视作字段缺失
    return nil;
}

@end
