//
//  WKMemberListVM.m
//  WuKongBase
//
//  Created by tt on 2022/8/31.
//

#import "WKMemberListVM.h"
#import "WuKongBase.h"
#import "WKUserOnlineResp.h"
@interface WKMemberListVM ()

@property(nonatomic,assign) NSInteger page;

@property(nonatomic,assign) NSInteger limit;



@end

@implementation WKMemberListVM

-(void) didLoad {
    self.page = 1;
    self.limit = 100;
    __weak typeof(self) weakSelf = self;
    self.loading = true;
    self.items = [NSMutableArray array];
    self.headerTitles = [NSMutableArray array];
    WKChannelInfo *channelInfo = [WKSDK.shared.channelManager getChannelInfo:self.channel];
    if(!channelInfo) {
        return;
    }
    WKGroupType groupType = [WKChannelUtil groupType:channelInfo];
    WKRequestStrategy  requestStrategy  = WKRequestStrategyOnlyDB;
    if(groupType == WKGroupTypeSuper) {
        requestStrategy = WKRequestStrategyOnlyNetwork;
    }
    
    
    
    [WKGroupManager.shared searchMembers:self.channel keyword:self.keyword page:self.page limit:self.limit requestStrategy:requestStrategy complete:^(WKChannelMemberCacheType cacheType, NSArray<WKChannelMember *> * _Nonnull members) {
        weakSelf.loading = false;
        NSMutableArray *creators = [NSMutableArray array];
        NSMutableArray *managers = [NSMutableArray array];
        NSMutableArray *commons = [NSMutableArray array];
        for (WKChannelMember *member in members) {
            if([weakSelf isHiddenUser:member.memberUid]) {
                continue;
            }
            if(member.role == WKMemberRoleCreator) {
                [creators addObject:member];
            }else if(member.role == WKMemberRoleManager) {
                [managers addObject:member];
            }else {
                [commons addObject:member];
            }
        }
        NSMutableArray *items = [NSMutableArray array];
        if(creators.count>0) {
            [items addObject:creators];
        }
        if(managers.count>0) {
            [items addObject:managers];
        }
        
        
        [items addObject:commons];
        
        NSMutableArray *headerTitles = [NSMutableArray array];
        if(creators.count>0) {
            [headerTitles addObject:LLang(@"创建者")];
        }
        if(managers.count>0) {
            [headerTitles addObject:LLang(@"管理者")];
        }
        [headerTitles addObject:LLang(@"普通成员")];
        
        weakSelf.items = items;
        weakSelf.headerTitles = headerTitles;
        
        [weakSelf.delegate reload];
        
        NSMutableArray<NSString*> *memberUIDs = [NSMutableArray array];
        for (NSArray<WKChannelMember*> *members in items) {
            for (WKChannelMember *member in members) {
                [memberUIDs addObject:member.memberUid];
            }
        }
        [weakSelf onlineMembers:memberUIDs];
    }];
   
}

-(BOOL) isHiddenUser:(NSString*)uid {
    if(!self.hiddenUsers) {
        return false;
    }
    
    return [self.hiddenUsers containsObject:uid];
}

-(void) didMore:(void(^)(BOOL more))moreBlock {
    if(self.items.count<=0 || self.loading) {
        return;
    }
    self.loading = true;
    __weak typeof(self) weakSelf = self;
    WKChannelInfo *channelInfo = [WKSDK.shared.channelManager getChannelInfo:self.channel];
    if(!channelInfo) {
        return;
    }
    
    NSMutableArray *commons = (NSMutableArray*)self.items.lastObject;
    self.page++;
    WKGroupType groupType = [WKChannelUtil groupType:channelInfo];
    WKRequestStrategy  requestStrategy  = WKRequestStrategyOnlyDB;
    if(groupType == WKGroupTypeSuper) {
        requestStrategy = WKRequestStrategyOnlyNetwork;
    }
    [WKGroupManager.shared searchMembers:self.channel keyword:self.keyword page:self.page limit:self.limit requestStrategy: requestStrategy complete:^(WKChannelMemberCacheType cacheType, NSArray<WKChannelMember *> * _Nonnull members) {
        
        weakSelf.loading = false;
        
        NSMutableArray<NSString*> *memberUIDs = [NSMutableArray array];
        if(members.count>0) {
            for (WKChannelMember *member in members) {
                [memberUIDs addObject:member.memberUid];
            }
            [weakSelf onlineMembers:memberUIDs];
        }
        
        [commons addObjectsFromArray:members];
        
        [weakSelf.delegate reload];
        BOOL hasMore = false;
        if(members && members.count>=weakSelf.limit) {
            hasMore = true;
        }
        if(moreBlock) {
            moreBlock(hasMore);
        }
        
    }];
}

-(AnyPromise*) onlineMembers:(NSArray<NSString*>*)users {
    __weak typeof(self) weakSelf = self;
  return  [WKAPIClient.sharedClient POST:@"user/online" parameters:users model:WKUserOnlineResp.class].then(^(NSArray<WKUserOnlineResp*>*onlines){
      if(onlines && onlines.count>0) {
          [weakSelf.onlineMembers addObjectsFromArray:onlines];
          [weakSelf.delegate reload];
      }
      return onlines;
    });
}

- (NSMutableArray<WKUserOnlineResp *> *)onlineMembers {
    if(!_onlineMembers) {
        _onlineMembers = [NSMutableArray array];
    }
    return _onlineMembers;
}

-(WKUserOnlineResp*) onlineMember:(NSString*)uid {
    for (WKUserOnlineResp *onlineResp in self.onlineMembers) {
        if([onlineResp.uid isEqualToString:uid]) {
            return onlineResp;
        }
    }
    return nil;
}

- (NSArray<NSArray<WKChannelMember *> *> *)items {
    if(!_items) {
        _items = [NSMutableArray array];
    }
    return _items;
}

- (NSArray<NSString *> *)headerTitles {
    if(!_headerTitles) {
        _headerTitles = [NSMutableArray array];
    }
    return _headerTitles;
}

- (NSMutableSet<WKChannelMember *> *)selectedMembers {
    if(!_selectedMembers) {
        _selectedMembers = [[NSMutableSet alloc] init];
    }
    return _selectedMembers;
}
-(BOOL) isChecked:(WKChannelMember*)member {

    return  [self.selectedMembers containsObject:member];
}

-(void) makeChecked:(WKChannelMember*)member {
    if([self isChecked:member]) {
        [self.selectedMembers removeObject:member];
    }else {
        [self.selectedMembers addObject:member];
    }
}

-(WKChannelMember*) memberFromSelecteds:(NSString*)uid {
    for (WKChannelMember *member in self.selectedMembers) {
        if([member.memberUid isEqualToString:uid]) {
            return member;
        }
    }
    return nil;
}

@end
