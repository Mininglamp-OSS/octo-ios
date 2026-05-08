//
//  WKGroupScanJoinVC.m
//  WuKongBase
//

#import "WKGroupScanJoinVC.h"
#import "WuKongBase.h"
#import "WKAvatarUtil.h"
#import "WKJoinGroupSuccessHelper.h"

@interface WKGroupScanJoinVC ()

@property(nonatomic,strong) UIView *cardView;
@property(nonatomic,strong) WKUserAvatar *avatarImgView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UILabel *memberCountLbl;
@property(nonatomic,strong) UIButton *joinBtn;

@end

@implementation WKGroupScanJoinVC

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.view addSubview:self.cardView];
    [self.cardView addSubview:self.avatarImgView];
    [self.cardView addSubview:self.nameLbl];
    [self.cardView addSubview:self.memberCountLbl];
    [self.cardView addSubview:self.joinBtn];

    // 设置数据
    NSString *avatarURL = self.groupAvatar;
    if(!avatarURL || avatarURL.length == 0) {
        avatarURL = [WKAvatarUtil getGroupAvatar:self.groupNo];
    } else {
        // 服务端返回的是相对路径，拼接完整URL
        avatarURL = [[NSURL URLWithString:avatarURL relativeToURL:[NSURL URLWithString:[WKApp shared].config.apiBaseUrl]] absoluteString];
    }
    [self.avatarImgView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:avatarURL]];

    self.nameLbl.text = self.groupName ?: @"";
    self.memberCountLbl.text = [NSString stringWithFormat:LLang(@"%ld位成员"), (long)self.memberCount];

    // 已在群内显示"进入群聊"，否则显示"加入群聊"
    if (self.isMember) {
        [self.joinBtn setTitle:LLang(@"进入群聊") forState:UIControlStateNormal];
    } else {
        [self.joinBtn setTitle:LLang(@"加入群聊") forState:UIControlStateNormal];
    }
}

- (NSString *)langTitle {
    return LLang(@"群聊信息");
}

#pragma mark - Actions

-(void) joinBtnPressed {
    // 已在群内，直接进入群聊
    if (self.isMember) {
        WKConversationVC *vc = [WKConversationVC new];
        vc.channel = [[WKChannel alloc] initWith:self.groupNo channelType:WK_GROUP];
        [[WKNavigationManager shared] replacePushViewController:vc animated:YES];
        return;
    }

    self.joinBtn.enabled = NO;
    [self.view showHUD];

    NSString *path = [NSString stringWithFormat:@"groups/%@/scanjoin?auth_code=%@", self.groupNo, self.authCode];
    __weak typeof(self) weakSelf = self;
    // YUJ-213 / YUJ-372: scanjoin 成功响应现在由后端直接返回一个 JSON object
    //   YUJ-213 (dmworkim PR#1250): { status, group_no, group_name, space_id, space_name, is_external }
    //   YUJ-372 Phase 2 (dmworkim PR#1320): 当调用者无 Space 时返回
    //     { status: "need_space", msg: "请先加入一个 Space 后再入群" }
    // 以前 `.then(^{ })` 忽略 body — 现在按 NSDictionary 接住，便于就地判断
    // status/跨 Space/is_external。若未来服务端版本不带这些字段，回退到 VC
    // 构造时由扫码/邀请链接解析器注入的 `self.targetSpaceId / Name` 字段
    // （YUJ-141 的 legacy 通道），保持旧客户端 + 新服务端 / 新客户端 + 旧服务端
    // 两个方向都不 crash。
    [[WKAPIClient sharedClient] GET:path parameters:nil].then(^(id _Nullable resp) {
        [weakSelf.view hideHud];

        NSDictionary *respDict = [resp isKindOfClass:[NSDictionary class]] ? (NSDictionary *)resp : nil;

        // YUJ-372 Phase 2: 后端契约（dmworkim PR#1320）— 调用者无 Space 时
        //   scanjoin 返回 { status: "need_space", msg: "请先加入一个 Space 后再入群" }。
        // 命中 need_space 时：
        //   1) 不入群，不走跨 Space Toast / success dialog
        //   2) 把群邀请上下文（groupNo / authCode / 扫码元信息）暂存到
        //      NSUserDefaults `pendingGroupInvite`
        //   3) 推 WKSpaceGateVC (pushViewController，保留当前栈，方便加完 Space
        //      后回到主列表再重放 scan handler 重试入群)
        // 参考：Web / Android 三端统一处理；WKLoginVC::checkSpaceBeforeEnter 是
        // 登录后首次拉起 Space Gate 的用法，此处是运行时从扫码入口触发。
        NSString *respStatus = nil;
        id statusRaw = respDict[@"status"];
        if ([statusRaw isKindOfClass:[NSString class]]) {
            respStatus = (NSString *)statusRaw;
        }
        if ([respStatus isEqualToString:@"need_space"]) {
            NSDictionary *pending = @{
                @"group_no":     weakSelf.groupNo     ?: @"",
                @"auth_code":    weakSelf.authCode    ?: @"",
                @"name":         weakSelf.groupName   ?: @"",
                @"avatar":       weakSelf.groupAvatar ?: @"",
                @"member_count": @(weakSelf.memberCount),
                @"is_member":    @(weakSelf.isMember),
                // 扫码/邀请解析器注入的 Space 上下文 — 加 Space 后重放仍然可用。
                @"space_id":     weakSelf.targetSpaceId   ?: @"",
                @"space_name":   weakSelf.targetSpaceName ?: @"",
            };
            [[NSUserDefaults standardUserDefaults] setObject:pending forKey:@"pendingGroupInvite"];
            [[NSUserDefaults standardUserDefaults] synchronize];

            // 跨 module push WKSpaceGateVC（WKSpaceGateVC 在 WuKongLogin，这里
            // 走 invoke point；mode=push 让 handler 用 pushViewController 而非
            // resetRootViewController，以便加 Space 完成后自然 pop 回来重放。
            [[WKApp shared] invoke:WKPOINT_SPACEGATE_SHOW param:@{@"mode": @"push"}];
            weakSelf.joinBtn.enabled = YES;
            return;
        }

        // -------- 响应字段优先，VC 入参（legacy）兜底 --------
        NSString *(^pickStr)(NSString *, NSString *) = ^NSString *(NSString *key, NSString *fallback) {
            id v = respDict[key];
            if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) {
                return (NSString *)v;
            }
            return fallback;
        };
        NSString *targetSpaceId   = pickStr(@"space_id",   weakSelf.targetSpaceId);
        NSString *targetSpaceName = pickStr(@"space_name", weakSelf.targetSpaceName);
        // group_name 后端可能返回 canonical 最新名 — 优先响应值，退回扫码名。
        NSString *effectiveGroupName = pickStr(@"group_name", weakSelf.groupName);

        // 硬约束：is_external=1 的外部群不走跨 Space Toast（外部群会作为当前
        // Space 下的外部会话出现在本地列表，没必要提醒"切过去"；Web/Android 对齐）。
        BOOL isExternal = NO;
        id externalRaw = respDict[@"is_external"];
        if ([externalRaw isKindOfClass:[NSNumber class]] || [externalRaw isKindOfClass:[NSString class]]) {
            isExternal = ([externalRaw integerValue] == 1);
        }

        // YUJ-141 / YUJ-213: 跨 Space 加群（非 external）— 不能直接把用户推进群，
        // 否则 iOS 会把 viewer 当前 Space 的上下文错位带进去（Web 对齐 PR#1068）。
        // 先记"跨 Space 加群成功"通知，pop 回主列表，由 WKConversationListVC
        // viewDidAppear 弹双行 Toast + 紫色「切换过去」按钮。用户显式点击才切
        // Space + 进群。硬约束：公共群/同 Space 不弹（Helper 内判定）；is_external=1
        // 不走此 Toast（本层判定）。
        // 统一 i18n key (三端一致): group_join_cross_space_notice
        BOOL crossSpaceNoticeSaved = NO;
        if (!isExternal) {
            crossSpaceNoticeSaved =
                [WKJoinGroupSuccessHelper computeAndSaveWithGroupNo:weakSelf.groupNo
                                                      targetSpaceId:targetSpaceId
                                                          groupName:effectiveGroupName
                                                          spaceName:targetSpaceName];
        }
        if (crossSpaceNoticeSaved) {
            // 不进群，直接 pop 回主列表，让 Dialog 在主页面消费。
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
            return;
        }

        // 同 Space / 无 Space 识别 / 外部群 → 维持旧行为（直接进群）。
        WKConversationVC *vc = [WKConversationVC new];
        vc.channel = [[WKChannel alloc] initWith:weakSelf.groupNo channelType:WK_GROUP];
        [[WKNavigationManager shared] replacePushViewController:vc animated:YES];
    }).catch(^(NSError *error) {
        weakSelf.joinBtn.enabled = YES;
        [weakSelf.view hideHud];
        [weakSelf.view showHUDWithHide:error.domain];
    });
}

#pragma mark - UI Components

-(UIView*) cardView {
    if(!_cardView) {
        CGFloat width = WKScreenWidth - 80.0f;
        _cardView = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 100.0f + [self visibleRect].origin.y, width, 260.0f)];
        _cardView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _cardView.layer.cornerRadius = 10.0f;
        _cardView.layer.masksToBounds = YES;
    }
    return _cardView;
}

-(WKUserAvatar*) avatarImgView {
    if(!_avatarImgView) {
        CGFloat avatarSize = 64.0f;
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, avatarSize, avatarSize)];
        _avatarImgView.lim_left = self.cardView.lim_width / 2.0f - avatarSize / 2.0f;
        _avatarImgView.lim_top = 30.0f;
    }
    return _avatarImgView;
}

-(UILabel*) nameLbl {
    if(!_nameLbl) {
        _nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, self.avatarImgView.lim_bottom + 12.0f, self.cardView.lim_width - 40.0f, 22.0f)];
        _nameLbl.textAlignment = NSTextAlignmentCenter;
        _nameLbl.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
        _nameLbl.numberOfLines = 1;
    }
    return _nameLbl;
}

-(UILabel*) memberCountLbl {
    if(!_memberCountLbl) {
        _memberCountLbl = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, self.nameLbl.lim_bottom + 6.0f, self.cardView.lim_width - 40.0f, 18.0f)];
        _memberCountLbl.textAlignment = NSTextAlignmentCenter;
        _memberCountLbl.font = [UIFont systemFontOfSize:14.0f];
        _memberCountLbl.textColor = [UIColor grayColor];
    }
    return _memberCountLbl;
}

-(UIButton*) joinBtn {
    if(!_joinBtn) {
        CGFloat btnWidth = self.cardView.lim_width - 60.0f;
        _joinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _joinBtn.frame = CGRectMake(30.0f, self.memberCountLbl.lim_bottom + 30.0f, btnWidth, 44.0f);
        [_joinBtn setTitle:LLang(@"加入群聊") forState:UIControlStateNormal];
        [_joinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _joinBtn.titleLabel.font = [UIFont systemFontOfSize:16.0f weight:UIFontWeightMedium];
        _joinBtn.backgroundColor = [WKApp shared].config.themeColor;
        _joinBtn.layer.cornerRadius = 8.0f;
        _joinBtn.layer.masksToBounds = YES;
        [_joinBtn addTarget:self action:@selector(joinBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _joinBtn;
}

@end
