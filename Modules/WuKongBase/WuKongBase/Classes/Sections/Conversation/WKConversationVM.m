//
//  WKConversationVM.m
//  WuKongBase
//
//  Created by tt on 2022/5/19.
//

#import "WKConversationVM.h"
#import "WuKongBase.h"

@interface WKConversationVM ()


@end

@implementation WKConversationVM

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self addListeners];
    }
    return self;
}

- (void)dealloc {
    [self removeListeners];
}

- (NSArray<WKChannelMember *> *)getAllMembers {
    return [[WKSDK shared].channelManager getMembersWithChannel:self.channel];
}


- (WKChannelMember *)memberOfMe {
    if(!_memberOfMe) {
        _memberOfMe = [[WKChannelMemberDB shared] get:self.channel memberUID:[WKApp shared].loginInfo.uid];
    }
    return _memberOfMe;
}

-(WKGroupType) groupType {
    
    return  [WKChannelUtil groupType:self.channelInfo];
}


-(void) syncMembersIfNeed{
    if(self.channel.channelType == WK_GROUP) {
        [[WKGroupManager shared] syncMemebers:self.channel.channelId];
    }
   
}

-(void) typing {
    [[WKAPIClient sharedClient] POST:@"message/typing" parameters:@{
        @"channel_id": self.channel.channelId,
        @"channel_type":@(self.channel.channelType),
    }];
}
-(void) requestMembers {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        weakSelf.members = [weakSelf getAllMembers];
        weakSelf.memberOfMe = nil;
        lim_dispatch_main_async_safe(^{
            if(weakSelf.onMemberUpdate) {
                weakSelf.onMemberUpdate();
            }
        });
        
        [weakSelf syncMembersIfNeed];
    });
    
}

- (NSInteger)memberCount {
    if(self.groupType == WKGroupTypeSuper) {
        if(self.channelInfo && self.channelInfo.extra[@"member_count"]) {
            return [self.channelInfo.extra[@"member_count"] integerValue];
        }
    }else {
        NSArray<WKChannelMember*> *members = self.members;
        return members?members.count:0;
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
- (NSInteger)forbiddenExpirTime {
    if(self.groupType == WKGroupTypeSuper) {
        if(self.channelInfo && self.channelInfo.extra[@"role"]) {
            return [self.channelInfo.extra[@"role"] integerValue];
        }
    }else {
        WKChannelMember *memberOfMe = self.memberOfMe;
        if(memberOfMe && memberOfMe.extra[@"forbidden_expir_time"]) {
            NSInteger forbiddenExpirTime = [memberOfMe.extra[@"forbidden_expir_time"] integerValue];
            return  forbiddenExpirTime;
        }
    }
    return 0;
}

-(void) addListeners {
    // 监听群成员更新
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMemberUpdate) name:WKNOTIFY_GROUP_MEMBERUPDATE object:nil];
}

-(void) removeListeners {
    // 移除监听群成员更新
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_GROUP_MEMBERUPDATE object:nil];
}

-(void) handleMemberUpdate {
    __weak typeof(self) weakSelf = self;
    self.members = [self getAllMembers];
    weakSelf.memberOfMe = nil;
    lim_dispatch_main_async_safe(^{
        if(weakSelf.onMemberUpdate) {
            weakSelf.onMemberUpdate();
        }
    });
}



@end


