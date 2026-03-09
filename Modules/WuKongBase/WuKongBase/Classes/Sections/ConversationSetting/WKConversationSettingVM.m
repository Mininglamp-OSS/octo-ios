//
//  WKConversationSettingVM.m
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import "WKConversationSettingVM.h"
#import "WuKongBase.h"
#import "WKFormItemModel.h"
#import "WKFormSection.h"
#import "WKLabelItemCell.h"
#import "WKSwitchItemCell.h"
#import "WKIconItemCell.h"
#import "WKResource.h"
#import "WKGroupManager.h"
#import "WKButtonItemCell.h"
#import "WKMultiLabelItemCell.h"
#import "WKTableSectionUtil.h"
#import "WKGroupQRCodeVC.h"
#import "WKGlobalSearchResultController.h"

@interface WKConversationSettingVM ()<WKChannelManagerDelegate>

@property(nonatomic,strong) WKChannelInfo *_channelInfo;

@end

@implementation WKConversationSettingVM

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[WKSDK shared].channelManager addDelegate:self];
        
    }
    return self;
}

- (void)dealloc {
    [[WKSDK shared].channelManager removeDelegate:self];
}

-(void) syncMembersIfNeed{
    if(self.channel.channelType == WK_GROUP) {
        [[WKGroupManager shared] syncMemebers:self.channel.channelId];
    }
    
}


- (NSArray<NSDictionary *> *)tableSectionMaps {
    BOOL isCreatorOrManager = [self isManagerOrCreatorForMe];
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    param[@"channel"] = self.channel;
    param[@"is_creator_or_manager"] = @(isCreatorOrManager);
    if(self.channelInfo) {
        param[@"channel_info"] = self.channelInfo;
    }
    param[@"refresh"] = ^ {
        [self reloadData];
    };
    param[@"context"] = self.context;
    [self registerSections];
    NSArray *items = [WKApp.shared invokes:WKPOINT_CATEGORY_CHANNELSETTING param:param];
    return items;
}

//-(NSArray<WKFormSection*>*) settingSections {
//    if(!_settingSections) {
//        if(self.channel.channelType == WK_GROUP) {
//             _settingSections = [WKTableSectionUtil toSections:[self groupSettingItems]];
//        }else {
//             _settingSections = [WKTableSectionUtil toSections:[self personSettingItems]];
//        }
//       
//    }
//    return _settingSections;
//}

- (WKChannelMember *)memberOfMe {
    if(!_memberOfMe) {
        _memberOfMe = [[WKSDK shared].channelManager getMember:self.channel uid:[WKApp shared].loginInfo.uid];
    }
    return _memberOfMe;
}

-(BOOL) isManagerForMe {
    return self.memberOfMe && self.memberOfMe.role == WKMemberRoleManager;
}

-(BOOL) isCreatorForMe {
    return self.memberOfMe && self.memberOfMe.role == WKMemberRoleCreator;
}

-(BOOL) isManagerOrCreatorForMe {
    return [self isManagerForMe] || [self isCreatorForMe];
}


- (NSInteger)memberCount {
    if(self.groupType == WKGroupTypeSuper) {
        return [self memberCount:self.channelInfo];
    }else {
        return [[WKSDK shared].channelManager getMemberCount:self.channel];
    }
    return 0;
}

-(NSInteger) memberCount:(WKChannelInfo*)channelInfo {
    if(channelInfo && channelInfo.extra[@"member_count"]) {
        return [channelInfo.extra[@"member_count"] integerValue];
    }
    return 0;
}

- (WKMemberRole)memberRole {
    if(self.groupType == WKGroupTypeSuper) {
        if(self.channelInfo && self.channelInfo.extra[@"role"]) {
            return [self.channelInfo.extra[@"role"] integerValue];
        }
    }else {
        WKChannelMember *memberOfMe = self.memberOfMe;
        if(memberOfMe) {
            return  memberOfMe.role;
        }
    }
    return WKMemberRoleCommon;
}

-(WKGroupType) groupType {
    
    return [self groupType:self.channelInfo];
}

-(WKGroupType) groupType:(WKChannelInfo*)channelInfo {
    return [WKChannelUtil groupType:channelInfo];
}

-(void) registerSections {
    __weak typeof(self) weakSelf = self;
    
    // 是否有公告
    BOOL hasNotice  = self.channelInfo && self.channelInfo.notice && ![self.channelInfo.notice isEqualToString:@""];
    
    

    
    // 在群内的名字
    NSString *nameInGroup = self.memberOfMe.memberName;
    if(self.memberOfMe.memberRemark && ![self.memberOfMe.memberRemark isEqualToString:@""]) {
        nameInGroup = self.memberOfMe.memberRemark;
    }
    
    [[WKApp shared] setMethod:@"channelsetting.groupname" handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        if(channel.channelType != WK_GROUP) {
            return nil;
        }
        return @{
            @"height":WKSectionHeight,
            @"items": @[
                @{
                    @"class":WKLabelItemModel.class,
                    @"label":LLang(@"群聊名称"),
                    @"value":self.channelInfo&&self.channelInfo.name?self.channelInfo.name:@"",
                    @"showBottomLine":@(NO),
                    @"showTopLine":@(NO),
                    @"onClick":^{
                        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(settingOnGroupNameClick:)]) {
                            [weakSelf.delegate settingOnGroupNameClick:weakSelf];
                        }
                    }
                }
            ],
        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:90000];
    
    
    [[WKApp shared] setMethod:@"channelsetting.groupqrcode" handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        if(channel.channelType != WK_GROUP) {
            return nil;
        }
        return @{
            @"height": @(0.0f),
            @"items":@[
                @{
                    @"class":WKIconItemModel.class,
                    @"label":LLang(@"群二维码"),
                    @"icon":[self imageName:@"Conversation/Setting/IconQrcode"],
                    @"width":@(24.0f),@"height":@(24.0f),
                    @"showBottomLine":@(NO),
                    @"onClick":^{
                        WKGroupQRCodeVC *vc = [WKGroupQRCodeVC new];
                        vc.channel = weakSelf.channel;
                        [[WKNavigationManager shared] pushViewController:vc animated:YES];
                    }
                }
            ],
        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:89800];
    
    [[WKApp shared] setMethod:@"channelsetting.groupintro" handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        BOOL isCreatorOrManager = [param[@"is_creator_or_manager"] boolValue];
        if(channel.channelType != WK_GROUP) {
            return nil;
        }
        return @{
            @"height":@(0.0f),
            @"items": @[
                @{
                    @"class": hasNotice?WKMultiLabelItemModel.class:WKLabelItemModel.class,
                    @"label":LLang(@"群公告"),
                    @"value": hasNotice?self.channelInfo.notice:LLang(@"未设置"),
                    @"showBottomLine":@(NO),
                    @"bottomLeftSpace": isCreatorOrManager?[NSNull null]:@(0.0f),
                    @"onClick":^{
                        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(settingOnGroupNoticeClick:)]) {
                            [weakSelf.delegate settingOnGroupNoticeClick:weakSelf];
                        }
                    }
                }
            ]
        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:89700];
    
    
    [[WKApp shared] setMethod:@"channelsetting.hsitory" handler:^id _Nullable(id  _Nonnull param) {
        return @{
            @"height":WKSectionHeight,
            @"items":@[
                @{
                    @"class":WKLabelItemModel.class,
                    @"label":LLang(@"查找聊天内容"),
                    @"showBottomLine":@(NO),
                    @"showTopLine":@(NO),
                    @"onClick":^{
                        WKGlobalSearchResultController *vc = [WKGlobalSearchResultController new];
                        vc.channel = weakSelf.channel;
                        [[WKNavigationManager shared] pushViewController:vc animated:NO];
                    }
                }
            ]
        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:89600];
    
    
    [[WKApp shared] setMethod:@"channelsetting.mute" handler:^id _Nullable(id  _Nonnull param) {
        return @{
            @"height":WKSectionHeight,
            @"items":@[
                @{
                    @"class":WKSwitchItemModel.class,
                    @"label":LLang(@"消息免打扰"),
                    @"on":@(self.channelInfo?self.channelInfo.mute:false),
                    @"showBottomLine":@(NO),
                    @"showTopLine":@(NO),
                    @"onSwitch":^(BOOL on){
                        [[WKChannelSettingManager shared] channel:self.channel mute:on];
                    }
                }
            ]
        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:89500];
    
    [[WKApp shared] setMethod:@"channelsetting.top" handler:^id _Nullable(id  _Nonnull param) {
        return @{
            @"height":@(0.0f),
            @"items":@[
                @{
                    @"class":WKSwitchItemModel.class,
                    @"label":LLang(@"置顶聊天"),
                    @"on":@(self.channelInfo?self.channelInfo.stick:false),
                    @"showBottomLine":@(NO),
                    @"onSwitch":^(BOOL on){
                        [[WKChannelSettingManager shared] channel:self.channel stick:on];
                    }
                }
            ]
        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:89400];
    
    [[WKApp shared] setMethod:@"channelsetting.groupsave" handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        if(channel.channelType != WK_GROUP) {
            return nil;
        }
        return @{
            @"height":@(0.0f),
            @"items":@[
                @{
                    @"class":WKSwitchItemModel.class,
                    @"label":LLang(@"保存到通讯录"),
                    @"on":@(self.channelInfo?self.channelInfo.save:false),
                    @"showBottomLine":@(NO),
                    @"bottomLeftSpace":@(0.0f),
                    @"onSwitch":^(BOOL on){
                        [[WKChannelSettingManager shared] group:self.channel.channelId save:on];

                    }
                }
            ]
        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:89300];
    
    
    
   
    
    [[WKApp shared] setMethod:@"channelsetting.nameInGroup" handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        if(channel.channelType != WK_GROUP) {
            return nil;
        }
        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                @{
                    @"class":WKLabelItemModel.class,
                    @"label":LLang(@"我在本群的昵称"),
                    @"value":nameInGroup?:@"",
                    @"showBottomLine":@(NO),
                    @"showTopLine":@(NO),
                    @"onClick":^{
                        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(settingOnGroupNoticeClick:)]) {
                            [weakSelf.delegate settingOnNickNameInGroup:weakSelf];
                        }
                    }
                },
               ]

        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:89100];
    
   
    
    [[WKApp shared] setMethod:@"channelsetting.report" handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        if(channel.channelType != WK_PERSON) {
            return nil;
        }
        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                @{
                    @"class":WKLabelItemModel.class,
                    @"label":self.channelInfo && self.channelInfo.status == WKChannelStatusBlacklist?LLangW(@"拉出黑名单", weakSelf):LLangW(@"拉入黑名单", weakSelf),
                    @"value":@"",
                    @"showBottomLine":@(NO),
                    @"bottomLeftSpace":@(0.0f),
                    @"showTopLine":@(NO),
                    @"onClick":^{
                        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(settingOnBlacklist:action:)]) {
                           [weakSelf.delegate settingOnBlacklist:weakSelf action:self.channelInfo && self.channelInfo.status != WKChannelStatusBlacklist];
                       }
                    }},
               ]

        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:88800];
    
    [[WKApp shared] setMethod:@"channelsetting.report" handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        CGFloat sectionHeight = 0.0f;
        if(channel.channelType == WK_GROUP) {
            sectionHeight = WKSectionHeight.floatValue;
        }
        return  @{
            @"height":@(sectionHeight),
            @"items":@[
                @{
                    @"class":WKLabelItemModel.class,
                    @"label":LLang(@"投诉"),
                    @"value":@"",
                    @"showBottomLine":@(NO),
                    @"bottomLeftSpace":@(0.0f),
                    @"showTopLine":@(NO),
                    @"onClick":^{
                       if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(settingOnReport:)]) {
                           [weakSelf.delegate settingOnReport:weakSelf];
                       }
                    }
                },
               ]

        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:88900];
    
    [[WKApp shared] setMethod:@"channelsetting.clearchat" handler:^id _Nullable(id  _Nonnull param) {
        return  @{
            @"height":WKSectionHeight,
            @"items":@[
                @{
                    @"class":WKButtonItemModel.class,
                    @"title":LLang(@"清空聊天记录"),
                    @"showBottomLine":@(NO),
                    @"bottomLeftSpace":@(0.0f),
                    @"showTopLine":@(NO),
                    @"onClick":^{
                        if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(settingOnClearMessages:)]) {
                            [weakSelf.delegate settingOnClearMessages:weakSelf];
                        }
                    }
                },
               ]

        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:88800];
    
    [[WKApp shared] setMethod:@"channelsetting.groupexit" handler:^id _Nullable(id  _Nonnull param) {
        WKChannel *channel = param[@"channel"];
        if(channel.channelType != WK_GROUP) {
            return nil;
        }
        return  @{
            @"height":@(0.0f),
            @"items":@[
                @{
                    @"class":WKButtonItemModel.class,
                    @"title":LLang(@"删除并退出"),
                    @"showBottomLine":@(NO),
                    @"bottomLeftSpace":@(0.0f),
                    @"showTopLine":@(NO),
                    @"onClick":^{
                           if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(settingOnGroupExit:)]) {
                               [weakSelf.delegate settingOnGroupExit:weakSelf];
                           }
                    }
                },
               ]
        };
    } category:WKPOINT_CATEGORY_CHANNELSETTING sort:88700];
}


-(AnyPromise*) addBlacklist {
    return [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"user/blacklist/%@",self.channelInfo.channel.channelId?:@""] parameters:nil];
}
-(AnyPromise*) deleteBlacklist {
    return [[WKAPIClient sharedClient] DELETE:[NSString stringWithFormat:@"user/blacklist/%@",self.channelInfo.channel.channelId?:@""] parameters:nil];
}


-(AnyPromise*) onlineMembers:(NSArray<NSString*>*)users {
    __weak typeof(self) weakSelf = self;
  return  [WKAPIClient.sharedClient POST:@"user/online" parameters:users model:WKUserOnlineResp.class].then(^(NSArray<WKUserOnlineResp*>*onlines){
      weakSelf.onlineMembers = onlines;
      return onlines;
    });
}

-(WKUserOnlineResp*) memberOnline:(NSString*)uid {
    if(!self.onlineMembers || self.onlineMembers.count == 0) {
        return nil;
    }
    for (WKUserOnlineResp *onlineResp in self.onlineMembers) {
        if([onlineResp.uid isEqualToString:uid]) {
            return onlineResp;
        }
    }
    return nil;
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

- (WKChannelInfo *)channelInfo {
    if(!self._channelInfo) {
        self._channelInfo = [[WKSDK shared].channelManager getChannelInfo:self.channel];
    }
    return self._channelInfo;
}

-(AnyPromise*) requestGroupMemberInvite:(NSArray<NSString*>*)uids remark:(NSString*)remark {
   return [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"groups/%@/member/invite",self.channel.channelId] parameters:@{@"uids":uids?:@[],@"remark":remark?:@""}];
}

#pragma mark - WKChannelManagerDelegate
- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo oldChannelInfo:(WKChannelInfo * _Nullable)oldChannelInfo{
    if(![self.channel isEqual:channelInfo.channel]) {
        return;
    }
    self._channelInfo = [[WKSDK shared].channelManager getChannelInfo:self.channel];
    [self reloadData];
    if(_delegate && [_delegate respondsToSelector:@selector(settingOnChannelUpdate:)]) {
        [_delegate settingOnChannelUpdate:self];
    }
    WKGroupType groupType = [self groupType:channelInfo];
    if(groupType == WKGroupTypeSuper) {
        if(oldChannelInfo && [self memberCount:oldChannelInfo]!=[self memberCount:channelInfo]) {
            if(_delegate && [_delegate respondsToSelector:@selector(settingOnTopNMembersUpdate:)]) {
                [_delegate settingOnTopNMembersUpdate:self];
            }
        }
     
    }
}
@end


