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
    groupModel.revokeRemind = dictory[@"revoke_remind"]?[dictory[@"revoke_remind"] boolValue]:false;
    groupModel.joinGroupRemind = dictory[@"join_group_remind"]?[dictory[@"join_group_remind"] boolValue]:false;
    groupModel.invite = dictory[@"invite"]?[dictory[@"invite"] boolValue]:false;
    groupModel.chatPwdOn = dictory[@"chat_pwd_on"]?[dictory[@"chat_pwd_on"] boolValue]:false;
    groupModel.allowViewHistoryMsg = dictory[@"allow_view_history_msg"]?[dictory[@"allow_view_history_msg"] boolValue]:false;
    groupModel.receipt =  dictory[@"receipt"]?[dictory[@"receipt"] boolValue]:false;
    if(dictory[@"version"]) {
        groupModel.version = [dictory[@"version"] longValue];
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
    
    return channelMember;
}


@end


