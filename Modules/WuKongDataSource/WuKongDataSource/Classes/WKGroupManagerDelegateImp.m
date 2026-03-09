//
//  WKGroupManagerDelegateImp.m
//  WuKongDataSource
//
//  Created by tt on 2020/1/19.
//

#import "WKGroupManagerDelegateImp.h"
#import "WKDataSourceModel.h"
@implementation WKGroupManagerDelegateImp


// 创建群聊
- (void)groupManager:(nonnull WKGroupManager *)manager createGroup:(nonnull NSArray<NSString *> *)members object:(id _Nullable)object complete:(void (^ _Nullable)(NSString * groupNo,NSError *error))complete {
    
    NSMutableArray *names = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] POST:@"group/create" parameters:@{@"members":members?:@[],@"member_names":names} model:WKGroupModel.class].then(^(WKGroupModel *groupModel){
        if(complete) {
            [weakSelf updateChannelInfoByGroupModel:groupModel];
            complete(groupModel.groupNo,nil);
            
            [WKSDK.shared.channelManager fetchChannelInfo:[WKChannel groupWithChannelID:groupModel.groupNo]];
        }
    }).catch(^(NSError *error){
        if(complete) {
            complete(nil,error);
        }
    });
}

// 添加群成员
- (void)groupManager:(nonnull WKGroupManager *)manager groupNo:(nonnull NSString *)groupNo membersOfAdd:(nonnull NSArray<NSString *> *)members object:(id _Nullable)object complete:(void (^ _Nullable)(NSError * __nullable))complete {
    NSMutableArray *names = [NSMutableArray array];
    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"groups/%@/members",groupNo] parameters:@{@"members":members?:@[],@"names":names}].then(^{
        if(complete) {
            complete(nil);
        }
    }).catch(^(NSError *error){
        if(complete) {
            complete(error);
        }
    });
}

// 删除群成员
- (void)groupManager:(nonnull WKGroupManager *)manager groupNo:(nonnull NSString *)groupNo membersOfDelete:(nonnull NSArray<NSString *> *)members object:(id _Nullable)object complete:(void (^ _Nullable)(NSError * __nullable))complete {
    NSMutableArray *names = [NSMutableArray array];
    [[WKAPIClient sharedClient] DELETE:[NSString stringWithFormat:@"groups/%@/members",groupNo] parameters:@{@"members":members?:@[],@"names":names}].then(^{
        if(complete) {
            complete(nil);
        }
    }).catch(^(NSError *error){
        if(complete) {
            complete(error);
        }
    });
}

// 同步群成员
- (void)groupManager:(nonnull WKGroupManager *)manager syncMemebers:(nonnull NSString *)groupNo complete:(void (^ _Nullable)(NSInteger syncMemberCount,NSError * __nullable error))complete {
    NSInteger limit = 10000;
    __block NSInteger memberCount = 0;
    [self requestSyncMembers:groupNo limit:limit maxRetryCount:50 complete:^(NSArray<WKChannelMember *> *members, NSError *error) {
        if(error) {
            WKLogError(@"群[%@]同步成员失败！->%@",groupNo,error);
            return;
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[WKSDK shared].channelManager addOrUpdateMembers:members];
        });
        memberCount+= members.count;
                   
    } finish:^{
        if(complete) {
            complete(memberCount,nil);
        }
    }];
    
    
}

-(void) requestSyncMembers:(NSString*)groupNo limit:(NSInteger)limit  maxRetryCount:(NSInteger)maxRetryCount complete:(void(^)(NSArray<WKChannelMember*>*members,NSError *error))complete finish:(void(^)(void))finish{
    __weak typeof(self) weakSelf = self;
    NSString *syncKey = [[WKSDK shared].channelManager getMemberLastSyncKey:[[WKChannel alloc] initWith:groupNo channelType:WK_GROUP]];
    [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"groups/%@/membersync",groupNo] parameters:@{@"version":syncKey?:@"",@"limit":@(limit)} model:WKGroupMemberModel.class].then(^(NSArray<WKGroupMemberModel*> *members){
        NSLog(@"同步到成员数量[%ld]",members.count);
        if(members && members.count>0) {
            NSMutableArray<WKChannelMember*> *channelMembers = [NSMutableArray array];
            for (WKGroupMemberModel *groupMember in members) {
                [channelMembers addObject:[groupMember toChannelMember]];
            }
            if(complete) {
                complete(channelMembers,nil);
            }
            if(members.count >= limit && maxRetryCount>0) {
                [weakSelf requestSyncMembers:groupNo limit:limit  maxRetryCount:maxRetryCount-1 complete:complete finish:finish];
            }else {
                if(finish) {
                    finish();
                }
            }
            if(maxRetryCount<=0) {
                WKLogError(@"同步群[%@]成员已超过最大次数！",groupNo);
            }
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                [[WKSDK shared].channelManager addOrUpdateMembers:channelMembers];
//                if(complete) {
//                    complete(channelMembers,nil);
//                }
//            });
        }else {
            if(finish) {
                finish();
            }
        }
    }).catch(^(NSError *error){
        NSLog(@"同步群成员失败！->%@",error);
        if(complete) {
            complete(nil,error);
        }
        if(finish) {
            finish();
        }
    });
}

-(void) groupManager:(WKGroupManager*)manager searchMembers:(NSString*)groupNo keyword:(NSString*)keyword page:(NSInteger)page  limit:(NSInteger)limit complete:(void(^__nullable)(NSError * __nullable error,NSArray<WKChannelMember*>*members))complete {
    [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"groups/%@/members",groupNo] parameters:@{@"keyword":keyword?:@"",@"limit":@(limit),@"page":@(page)} model:WKGroupMemberModel.class].then(^(NSArray<WKGroupMemberModel*> *members){
        NSMutableArray<WKChannelMember*> *channelMembers = [NSMutableArray array];
        if(members && members.count>0) {
            for (WKGroupMemberModel *groupMember in members) {
                [channelMembers addObject:[groupMember toChannelMember]];
            }
        }
        if(complete) {
            complete(nil,channelMembers);
        }
    }).catch(^(NSError *error){
        if(complete) {
            complete(error,nil);
        }
    });
}

-(void) updateChannelInfoByGroupModel:(WKGroupModel*)groupModel {
    WKChannelInfo *channelInfo = [[WKChannelInfo alloc] init];
    channelInfo.channel = [[WKChannel alloc] initWith:groupModel.groupNo channelType:WK_GROUP];
    channelInfo.name = groupModel.name;
    channelInfo.notice = groupModel.notice;
    channelInfo.mute = groupModel.mute;
    channelInfo.stick = groupModel.stick;
    channelInfo.showNick = groupModel.showNick;
    channelInfo.save = groupModel.save;
    channelInfo.forbidden = groupModel.forbidden;
    channelInfo.invite = groupModel.invite;
    channelInfo.receipt = groupModel.receipt;
    if(groupModel.avatar) {
        channelInfo.logo = groupModel.avatar;
    }else {
        channelInfo.logo = [NSString stringWithFormat:@"groups/%@/avatar",groupModel.groupNo];
    }
    [channelInfo setSettingValue:groupModel.forbiddenAddFriend forKey:WKChannelExtraKeyForbiddenAddFriend];
    [channelInfo setSettingValue:groupModel.screenshot forKey:WKChannelExtraKeyScreenshot];
    [channelInfo setSettingValue:groupModel.joinGroupRemind forKey:WKChannelExtraKeyJoinGroupRemind];
    [channelInfo setSettingValue:groupModel.revokeRemind forKey:WKChannelExtraKeyRevokeRemind];
    [channelInfo setSettingValue:groupModel.chatPwdOn forKey:WKChannelExtraKeyChatPwd];
    [channelInfo setSettingValue:groupModel.allowViewHistoryMsg forKey:WKChannelExtraKeyAllowViewHistoryMsg];
    
    [[WKSDK shared].channelManager addOrUpdateChannelInfo:channelInfo];
}

// 更新群信息
- (void)groupManager:(nonnull WKGroupManager *)manager syncGroupInfo:(nonnull NSString *)groupNo complete:(void (^ _Nullable)(NSError *error,bool notifyBefore))complete {
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:[NSString stringWithFormat:@"groups/%@",groupNo] parameters:nil model:WKGroupModel.class].then(^(WKGroupModel *groupModel){
        if(complete) {
            complete(nil,true);
        }
        [weakSelf updateChannelInfoByGroupModel:groupModel];
        if(complete) {
            complete(nil,false);
        }
    }).catch(^(NSError *error){
        if(complete) {
            complete(error,false);
        }
    });
}

- (NSURLSessionDataTask*)taskGroupManager:(nonnull WKGroupManager *)manager syncGroupInfo:(nonnull NSString *)groupNo complete:(void (^ _Nullable)(NSError *error,bool notifyBefore))complete {
    __weak typeof(self) weakSelf = self;
    return [[WKAPIClient sharedClient] taskGET:[NSString stringWithFormat:@"groups/%@",groupNo] parameters:nil model:WKGroupModel.class callback:^(NSError * _Nullable error, WKGroupModel *groupModel) {
        if(error) {
            if(complete) {
                complete(error,false);
            }
            return;
        }
        if(complete) {
            complete(nil,true);
        }
        [weakSelf updateChannelInfoByGroupModel:groupModel];
        if(complete) {
            complete(nil,false);
        }
    }];
}



- (void)groupManagerSetting:(nonnull WKGroupManager *)manager groupNo:(nonnull NSString *)groupNo settingKey:(WKGroupSettingKey)key on:(BOOL)on {
    NSString *keyStr = @"";
    switch (key) {
        case WKGroupSettingKeyMute:
            keyStr = @"mute";
            break;
        case WKGroupSettingKeyStick:
            keyStr = @"top";
            break;
        case WKGroupSettingKeySave:
            keyStr = @"save";
            break;
        case WKGroupSettingKeyShowNick:
            keyStr = @"show_nick";
            break;
        case WKGroupSettingKeyInvite:
            keyStr = @"invite";
            break;
        case WKGroupSettingKeyForbidden:
            keyStr = @"forbidden";
            break;
        case WKGroupSettingKeyForbiddenAddFriend:
            keyStr = @"forbidden_add_friend";
            break;
        case WKGroupSettingKeyScreenshot:
            keyStr = @"screenshot";
            break;
        case WKGroupSettingKeyRevokeRemind:
            keyStr = @"revoke_remind";
            break;
        case WKGroupSettingKeyJoinGroupRemind:
            keyStr = @"join_group_remind";
            break;
        case WKGroupSettingKeyChatPwdOn:
            keyStr = @"chat_pwd_on";
            break;
        case WKGroupSettingKeyReceipt:
            keyStr = @"receipt";
            break;
        case WKGroupSettingKeyAllowViewHistoryMsg:
            keyStr = @"allow_view_history_msg";
            break;
        case WKGroupSettingKeyFlame:
            keyStr = @"flame";
            break;
        default:
            break;
    }
    if([keyStr isEqualToString:@""]) {
        NSLog(@"key不能为空！");
        return;
    }
    // 调用群设置更新接口
    [self groupManagerSetting:manager groupNo:groupNo key:keyStr value:@(on?1:0)];
}

- (void)groupManagerSetting:(WKGroupManager *)manager groupNo:(NSString *)groupNo key:(NSString*)key value:(id)value {
    NSMutableDictionary *settingDict = [NSMutableDictionary dictionary];
    [settingDict setObject:value forKey:key];
    
    [[WKAPIClient sharedClient] PUT:[NSString stringWithFormat:@"groups/%@/setting",groupNo] parameters:settingDict].then(^{
//        if(settingDict[@"top"]) {
//            settingDict[@"stick"] = settingDict[@"top"];
//        }
//        WKChannel *channel = [[WKChannel alloc] initWith:groupNo channelType:WK_GROUP];
//        WKChannelInfo *channelInfo =  [[WKSDK shared].channelManager getChannelInfo:channel];
//        if(channelInfo) {
//            for (NSString *key in settingDict.allKeys) {
//                if([key isEqualToString:@"mute"]) { // 免打扰
//                    channelInfo.mute = [settingDict[key] boolValue];
//                }else if([key isEqualToString:@"stick"]) { // 置顶
//                    channelInfo.stick = [settingDict[key] boolValue];
//                } else if([key isEqualToString:@"show_nick"]) { // 置顶
//                    channelInfo.showNick = [settingDict[key] boolValue];
//                } else if([key isEqualToString:@"save"]) { // 保存
//                    channelInfo.save = [settingDict[key] boolValue];
//                } else if([key isEqualToString:@"invite"]) { // 确认邀请
//                    channelInfo.invite = [settingDict[key] boolValue];
//                }else if([key isEqualToString:@"forbidden"]) { // 禁言
//                    channelInfo.forbidden = [settingDict[key] boolValue];
//                }else if([key isEqualToString:@"receipt"]) { // 消息回执
//                    channelInfo.receipt = [settingDict[key] boolValue];
//                }else if([key isEqualToString:@"flame"]) { // 阅后即焚
//                    channelInfo.flame = [settingDict[key] boolValue];
//                }else {
//                    channelInfo.extra[key] = settingDict[key];
//                }
//            }
//            [[WKSDK shared].channelManager updateChannelInfo:channelInfo];
//        }
        
    });
}

-(AnyPromise*) groupSettingRemark:(WKGroupManager*)manager groupNo:(NSString*)groupNo remark:(NSString*)remark {
    // 调用群设置更新接口
  return  [[WKAPIClient sharedClient] PUT:[NSString stringWithFormat:@"groups/%@/setting",groupNo] parameters:@{@"remark":remark?:@""}].then(^{
        WKChannel *channel = [[WKChannel alloc] initWith:groupNo channelType:WK_GROUP];
        WKChannelInfo *channelInfo =  [[WKSDK shared].channelManager getChannelInfo:channel];
        if(channelInfo) {
            channelInfo.remark = remark;
            [[WKSDK shared].channelManager updateChannelInfo:channelInfo];
        }
    });
 
}

- (void)groupManagerUpdate:(nonnull WKGroupManager *)manager groupNo:(nonnull NSString *)groupNo attrKey:(nonnull NSString *)attrKey attrValue:(nonnull NSString *)attrValue complete:(nonnull void (^)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] PUT:[NSString stringWithFormat:@"groups/%@",groupNo] parameters:@{attrKey:attrValue}].then(^{
        if(complete) {
            complete(nil);
        }
    }).catch(^(NSError *error){
        if(complete) {
            complete(error);
        }
    });
}
// 群成员更新
- (void)groupManager:(nonnull WKGroupManager *)manager didMemberUpdateAtGroup:(nonnull NSString *)groupNo forMemberUID:(nonnull NSString *)memberUID withAttr:(nonnull NSDictionary *)attr complete:(void (^ _Nullable)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] PUT:[NSString stringWithFormat:@"groups/%@/members/%@",groupNo,memberUID] parameters:attr].then(^{
        if(complete) {
            complete(nil);
        }
    }).catch(^(NSError *error){
        if(complete) {
            complete(error);
        }
    });
}

// 退出群聊
- (void)groupManager:(WKGroupManager *)manager didGroupExit:(NSString *)groupNo complete:(void (^ _Nullable)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"groups/%@/exit",groupNo] parameters:nil].then(^{
        if(complete) {
            complete(nil);
        }
       }).catch(^(NSError *error){
           if(complete) {
               complete(error);
           }
           WKLogError(@"退出群聊失败！->%@",error);
       });
}

-(void) groupManager:(WKGroupManager*)manager didGroupDisband:(NSString*)groupNo complete:(void(^__nullable)(NSError *error))complete {
    [[WKAPIClient sharedClient] DELETE:[NSString stringWithFormat:@"groups/%@/disband",groupNo] parameters:nil].then(^{
        if(complete) {
            complete(nil);
        }
       }).catch(^(NSError *error){
           if(complete) {
               complete(error);
           }
           WKLogError(@"退出群聊失败！->%@",error);
       });
}

// 群成员设置为管理员
- (void)groupManager:(nonnull WKGroupManager *)manager groupNo:(nonnull NSString *)groupNo membersToManager:(nonnull NSArray<NSString *> *)members complete:(void (^ _Nullable)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"groups/%@/managers",groupNo] parameters:members].then(^{
           if(complete) {
               complete(nil);
           }
    }).catch(^(NSError *error){
        if(complete) {
          complete(error);
        }
        WKLogError(@"设置群管理员失败！->%@",error);
    });
}
// 将管理员设置为普通成员
- (void)groupManager:(nonnull WKGroupManager *)manager groupNo:(nonnull NSString *)groupNo managersToMember:(nonnull NSArray<NSString *> *)managers complete:(void (^ _Nullable)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] DELETE:[NSString stringWithFormat:@"groups/%@/managers",groupNo] parameters:managers].then(^{
           if(complete) {
               complete(nil);
           }
    }).catch(^(NSError *error){
        if(complete) {
          complete(error);
        }
        WKLogError(@"设置为普通成员失败！->%@",error);
    });
}

// 群禁言
- (void)groupManager:(WKGroupManager *)manager group:(NSString *)groupNo forbidden:(BOOL)forbidden complete:(void (^)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"groups/%@/forbidden/%d",groupNo,forbidden?1:0] parameters:nil].then(^{
              if(complete) {
                  complete(nil);
              }
       }).catch(^(NSError *error){
           if(complete) {
             complete(error);
           }
           WKLogError(@"设置为禁言失败！->%@",error);
       });
}

- (void)groupManager:(WKGroupManager *)manager group:(NSString *)groupNo forbiddenAddFriend:(BOOL)forbidden complete:(void (^)(NSError * _Nullable))complete {
    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"groups/%@/forbidden_add_friend/%d",groupNo,forbidden?1:0] parameters:nil].then(^{
              if(complete) {
                  complete(nil);
              }
       }).catch(^(NSError *error){
           if(complete) {
             complete(error);
           }
           WKLogError(@"设置为群内禁止加好友失败！->%@",error);
       });
}





@end
