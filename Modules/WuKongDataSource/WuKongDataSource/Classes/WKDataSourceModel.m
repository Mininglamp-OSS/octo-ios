//
//  WKDataSourceModel.m
//  WuKongDataSource
//
//  Created by tt on 2022/12/2.
//

#import "WKDataSourceModel.h"


@implementation WKGroupModel

+(WKModel*) fromMap:(NSDictionary*)dictory type:(ModelMapType)type {
    WKGroupModel *groupModel = [WKGroupModel new];
    groupModel.groupNo = dictory[@"group_no"];
    groupModel.mute = dictory[@"mute"]?[dictory[@"mute"] boolValue]:false;
    groupModel.stick = dictory[@"top"]?[dictory[@"top"] boolValue]:false;
    groupModel.save = dictory[@"save"]?[dictory[@"save"] boolValue]:false;
    groupModel.showNick = dictory[@"show_nick"]?[dictory[@"show_nick"] boolValue]:false;
    groupModel.name = dictory[@"name"];
    if(dictory[@"avatar"] && ![dictory[@"avatar"] isEqualToString:@""]) {
        groupModel.avatar = dictory[@"avatar"];
    }
    groupModel.notice = dictory[@"notice"];
    groupModel.forbidden = dictory[@"forbidden"]?[dictory[@"forbidden"] boolValue]:false;
    groupModel.forbiddenAddFriend = dictory[@"forbidden_add_friend"]?[dictory[@"forbidden_add_friend"] boolValue]:false;
    groupModel.screenshot = dictory[@"screenshot"]?[dictory[@"screenshot"] boolValue]:false;
    groupModel.joinGroupRemind = dictory[@"join_group_remind"]?[dictory[@"join_group_remind"] boolValue]:false;
    groupModel.invite = dictory[@"invite"]?[dictory[@"invite"] boolValue]:false;
    groupModel.chatPwdOn = dictory[@"chat_pwd_on"]?[dictory[@"chat_pwd_on"] boolValue]:false;
    groupModel.allowViewHistoryMsg = dictory[@"allow_view_history_msg"]?[dictory[@"allow_view_history_msg"] boolValue]:false;
    groupModel.receipt =  dictory[@"receipt"]?[dictory[@"receipt"] boolValue]:false;
    if(dictory[@"version"]) {
        groupModel.version = [dictory[@"version"] longValue];
    }
    // ---------- 外部群 (External Group) Phase 1 字段 ----------
    // 使用 NSNumber 区分「后端返回 0」和「后端未返回」，避免增量 group_update 时把旧标记清零
    id isExternalGroupRaw = dictory[@"is_external_group"];
    if([isExternalGroupRaw isKindOfClass:[NSNumber class]] || [isExternalGroupRaw isKindOfClass:[NSString class]]) {
        groupModel.isExternalGroup = @([isExternalGroupRaw integerValue] == 1);
    }
    // allow_external: 是否允许邀请外部成员
    id allowExternalRaw = dictory[@"allow_external"];
    if([allowExternalRaw isKindOfClass:[NSNumber class]] || [allowExternalRaw isKindOfClass:[NSString class]]) {
        groupModel.allowExternal = @([allowExternalRaw integerValue] == 1);
    }
    // 群归属 space id
    id spaceIdRaw = dictory[@"space_id"];
    if([spaceIdRaw isKindOfClass:[NSString class]]) {
        groupModel.spaceId = spaceIdRaw;
    }

    return groupModel;
}

@end



@implementation WKGroupMemberModel

+ (WKModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    WKGroupMemberModel *model = [WKGroupMemberModel new];
    model._id = [dictory[@"id"] longValue];
    model.groupNo = dictory[@"group_no"];
     model.uid = dictory[@"uid"];
    model.name = dictory[@"name"];
    if(dictory[@"avatar"] && ![dictory[@"avatar"] isEqualToString:@""]) {
        model.avatar = dictory[@"avatar"];
    } else {
        model.avatar = [NSString stringWithFormat:@"users/%@/avatar",model.uid];
    }
    
    model.remark = dictory[@"remark"];
    model.role = [dictory[@"role"] integerValue];
    model.status = [dictory[@"status"] integerValue];
    model.version = dictory[@"version"];
    model.vercode = dictory[@"vercode"]?:@"";
    model.inviteUID = dictory[@"invite_uid"] ?: @"";
    model.robot = [dictory[@"robot"] integerValue]==1;
    model.isDeleted = [dictory[@"is_deleted"] integerValue]==1;
    model.createdAt = dictory[@"created_at"];
    model.updatedAt = dictory[@"updated_at"];
    if(dictory[@"forbidden_expir_time"]) {
        model.forbiddenExpirTime = [dictory[@"forbidden_expir_time"] integerValue];
    }
    // ---------- 外部群 (External Group) Phase 1 成员级字段 ----------
    // NSNull 防御：后端有可能下发 JSON null，必须用 isKindOfClass: 过滤
    id isExternalRaw = dictory[@"is_external"];
    if([isExternalRaw isKindOfClass:[NSNumber class]] || [isExternalRaw isKindOfClass:[NSString class]]) {
        model.isExternal = [isExternalRaw integerValue] == 1;
    }
    id sourceSpaceIdRaw = dictory[@"source_space_id"];
    if([sourceSpaceIdRaw isKindOfClass:[NSString class]]) {
        model.sourceSpaceId = sourceSpaceIdRaw;
    }
    id sourceSpaceNameRaw = dictory[@"source_space_name"];
    if([sourceSpaceNameRaw isKindOfClass:[NSString class]]) {
        model.sourceSpaceName = sourceSpaceNameRaw;
    }
    // home_space_id / home_space_name: viewer-relative 判定依据
    id homeSpaceIdRaw = dictory[@"home_space_id"];
    if([homeSpaceIdRaw isKindOfClass:[NSString class]]) {
        model.homeSpaceId = homeSpaceIdRaw;
    }
    id homeSpaceNameRaw = dictory[@"home_space_name"];
    if([homeSpaceNameRaw isKindOfClass:[NSString class]]) {
        model.homeSpaceName = homeSpaceNameRaw;
    }

    return model;
}


-(WKChannelMember*) toChannelMember{
    WKChannelMember *channelMember = [WKChannelMember new];
    channelMember.channelId = self.groupNo;
    channelMember.channelType = WK_GROUP;
    channelMember.memberUid = self.uid;
    channelMember.memberName = self.name;
    channelMember.memberAvatar = self.avatar;
    channelMember.memberRemark = self.remark;
    channelMember.version = self.version;
    channelMember.createdAt = self.createdAt;
    channelMember.updatedAt = self.updatedAt;
    channelMember.isDeleted = self.isDeleted;
    channelMember.role = self.role;
    channelMember.robot = self.robot;
    channelMember.status = self.status==0?1:self.status;
    if(self.vercode) {
        channelMember.extra[@"vercode"] = self.vercode;
    }
    if(self.inviteUID) {
        channelMember.extra[@"invite_uid"] = self.inviteUID;
    }
    if(self.forbiddenExpirTime>0) {
        channelMember.extra[@"forbidden_expir_time"] = @(self.forbiddenExpirTime);
    }
    // ---------- 外部群 Phase 1：外部成员标识 + 来源/归属 space 透传 ----------
    // is_external 始终透传（即使为 false 也要落一下，便于上层区分"不是外部成员"和"数据未到"）
    // 但为了避免污染历史数据和本地未知成员，只在 true 时写 flag，false 由缺省 0 语义表达
    if(self.isExternal) {
        channelMember.extra[@"is_external"] = @(1);
    }
    if(self.sourceSpaceId && self.sourceSpaceId.length > 0) {
        channelMember.extra[@"source_space_id"] = self.sourceSpaceId;
    }
    if(self.sourceSpaceName && self.sourceSpaceName.length > 0) {
        channelMember.extra[@"source_space_name"] = self.sourceSpaceName;
    }
    // home_space_*: 所有成员都可能有（viewer-relative 判断需要区分"外部成员的 home Space"和"我自己当前 Space"）
    if(self.homeSpaceId && self.homeSpaceId.length > 0) {
        channelMember.extra[@"home_space_id"] = self.homeSpaceId;
    }
    if(self.homeSpaceName && self.homeSpaceName.length > 0) {
        channelMember.extra[@"home_space_name"] = self.homeSpaceName;
    }

    return channelMember;
}


@end


