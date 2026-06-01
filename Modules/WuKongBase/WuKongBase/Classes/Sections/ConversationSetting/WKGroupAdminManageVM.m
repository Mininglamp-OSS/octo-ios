//
//  WKGroupAdminManageVM.m
//  WuKongBase
//

#import "WKGroupAdminManageVM.h"
#import "WuKongBase.h"

@interface WKGroupAdminManageVM ()
@property(nonatomic, assign, readwrite) BOOL loading;
@property(nonatomic, strong, readwrite, nullable) WKChannelMember *creator;
@property(nonatomic, strong, readwrite) NSArray<WKChannelMember*> *managers;
@property(nonatomic, strong, readwrite) NSArray<WKChannelMember*> *botAdmins;
@property(nonatomic, strong, readwrite) NSArray<NSString*> *ownerAndManagerUids;
@property(nonatomic, strong, readwrite) NSArray<NSString*> *botAdminUids;
@property(nonatomic, strong, readwrite) NSArray<NSString*> *robotUids;
@property(nonatomic, strong, readwrite) NSArray<NSString*> *nonRobotUids;
@end

@implementation WKGroupAdminManageVM

- (instancetype)init {
    if (self = [super init]) {
        _managers = @[];
        _botAdmins = @[];
        _ownerAndManagerUids = @[];
        _botAdminUids = @[];
        _robotUids = @[];
        _nonRobotUids = @[];
    }
    return self;
}

- (void)reload {
    if (!self.channel) {
        return;
    }
    self.loading = YES;

    // 管理员管理对数据新鲜度要求高（增删后必须立刻看到结果），统一走网络拉取，
    // 避免 DB-only 策略命中本地未同步的成员快照。
    WKRequestStrategy strategy = WKRequestStrategyOnlyNetwork;

    __weak typeof(self) weakSelf = self;
    [WKGroupManager.shared searchMembers:self.channel
                                  keyword:nil
                                     page:1
                                    limit:200
                          requestStrategy:strategy
                                 complete:^(WKChannelMemberCacheType cacheType, NSArray<WKChannelMember *> *members) {
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;

        WKChannelMember *creator = nil;
        NSMutableArray<WKChannelMember*> *managers = [NSMutableArray array];
        NSMutableArray<WKChannelMember*> *botAdmins = [NSMutableArray array];
        NSMutableArray<NSString*> *ownerMgrUids = [NSMutableArray array];
        NSMutableArray<NSString*> *botAdminUids = [NSMutableArray array];
        NSMutableArray<NSString*> *robotUids = [NSMutableArray array];
        NSMutableArray<NSString*> *nonRobotUids = [NSMutableArray array];

        for (WKChannelMember *m in members) {
            if (m.role == WKMemberRoleCreator) {
                creator = m;
                if (m.memberUid) [ownerMgrUids addObject:m.memberUid];
            } else if (m.role == WKMemberRoleManager) {
                [managers addObject:m];
                if (m.memberUid) [ownerMgrUids addObject:m.memberUid];
            }
            BOOL isBotAdmin = m.robot && [m.extra[@"bot_admin"] integerValue] == 1;
            if (isBotAdmin) {
                [botAdmins addObject:m];
                if (m.memberUid) [botAdminUids addObject:m.memberUid];
            }
            if (m.memberUid) {
                if (m.robot) {
                    [robotUids addObject:m.memberUid];
                } else {
                    [nonRobotUids addObject:m.memberUid];
                }
            }
        }

        self_.creator = creator;
        self_.managers = managers;
        self_.botAdmins = botAdmins;
        self_.ownerAndManagerUids = ownerMgrUids;
        self_.botAdminUids = botAdminUids;
        self_.robotUids = robotUids;
        self_.nonRobotUids = nonRobotUids;
        self_.loading = NO;

        if ([self_.delegate respondsToSelector:@selector(groupAdminReload)]) {
            [self_.delegate groupAdminReload];
        }
    }];
}

@end
