//
//  WKConversationSettingVC.m
//  WuKongBase
//
//  Created by tt on 2020/1/20.
//

#import "WKConversationGroupSettingVC.h"
#import "UIView+WK.h"
#import "WKSettingMemberGridView.h"
#import "WuKongBase.h"
#import "WKConversationSettingVM.h"
#import "WKFormItemCell.h"
#import "WKResource.h"
#import "WKModelConvert.h"
#import "WKInputVC.h"
#import "WKGroupManager.h"
#import "WKMessageManager.h"
#import "WKAvatarUtil.h"
#import "WKUserAvatar.h"
#import "WKActionSheetView2.h"
#import "WKWebViewVC.h"
#import "WKMemberListVC.h"
#import "WKTextViewVC.h"
#import "WKOnlineBadgeView.h"
#import "WKExternalViewerResolver.h"
#import "WKChannelUtil.h"
#import "WKRealnamePrefetcher.h"
#import "TOCropViewController.h"
#import <SDWebImage/SDImageCache.h>

@interface WKConversationGroupSettingVC ()<WKConversationSettingDelegate,WKSettingMemberGridViewDelegate,TOCropViewControllerDelegate>


@property(nonatomic,strong) WKSettingMemberGridView *settingMemberGridView;
@property(nonatomic,strong) NSArray<WKChannelMember*> *topNMembers; // 前指定数量的成员
@property(nonatomic,assign) NSInteger limitMemberCount; // 现在的最多成员数量


@property(nonatomic,strong) UIView *headerView;



@end

@implementation WKConversationGroupSettingVC


- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKConversationSettingVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    self.viewModel.channel = self.channel;
    self.viewModel.context = self.context;
    
    [super viewDidLoad];
    
    [[WKSDK shared].channelManager fetchChannelInfo:self.channel]; // 先同步一次
    
    
    
    if( [self.viewModel isManagerOrCreatorForMe]) {
        self.limitMemberCount = 20 - 2; // 减掉+和-的icon
    }else {
        self.limitMemberCount = 20 - 1;// 减掉+的icon
    }
    
    // 获取频道成员
//    self.topNMembers = [[WKSDK shared].channelManager getMembersWithChannel:self.channel limit:self.limitMemberCount];
//    if(self.topNMembers && self.topNMembers.count<self.limitMemberCount) {
//        self.memberCount = self.topNMembers.count;
//    } else {
//        self.memberCount =  [[WKSDK shared].channelManager getMemberCount:self.channel];
//    }
//    if(self.memberCount>self.limitMemberCount) {
//        self.hasMoreMember = true;
//    }
    

    [self requestTopNMembers:self.limitMemberCount];

    
    [self refreshMembers];
    if(self.viewModel.groupType == WKGroupTypeCommon) {
        // 如果需要，则同步成员
        [self.viewModel syncMembersIfNeed];
    }
    
    self.tableView.tableHeaderView = self.headerView;
    self.tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:self.tableView];

    
    // 监听群成员更新通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memberUpdate) name:WKNOTIFY_GROUP_MEMBERUPDATE object:nil];

    // YUJ-381 实名状态预拉取回写：宫格里 topNMembers 命中时局部刷一下宫格，避免
    // 「实名状态拉到了但宫格没更新，必须打开名片才看到徽章」。
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(realnameVerifiedUpdated:) name:WKRealnameVerifiedUpdatedNotification object:nil];

}


-(void) realnameVerifiedUpdated:(NSNotification *)noti {
    NSString *uid = noti.userInfo[@"uid"];
    if(uid.length == 0) return;
    BOOL hit = NO;
    for (WKChannelMember *m in self.topNMembers) {
        if([m.memberUid isEqualToString:uid]) {
            hit = YES;
            break;
        }
    }
    if(!hit) return;
    [self.settingMemberGridView reloadData];
}


-(void) requestTopNMembers:(NSInteger)limitMemberCount {
    __weak typeof(self) weakSelf = self;
    NSInteger limit = limitMemberCount + 1;
    [[WKGroupManager shared] searchMembers:self.channel keyword:nil limit:limit complete:^(WKChannelMemberCacheType cacheType, NSArray<WKChannelMember *> * _Nonnull members) {
        if(members.count >= limit) {
            weakSelf.topNMembers = [members subarrayWithRange:NSMakeRange(0, members.count-1)];
            weakSelf.settingMemberGridView.hasMore = true;
        }else {
            weakSelf.topNMembers = members;
            weakSelf.settingMemberGridView.hasMore = false;
        }
        NSMutableArray<NSString*> *memberUIDs = [NSMutableArray array];
        if(weakSelf.topNMembers && weakSelf.topNMembers.count>0) {
            for (WKChannelMember *member in weakSelf.topNMembers) {
                [memberUIDs addObject:member.memberUid];
            }
            [weakSelf.viewModel onlineMembers:memberUIDs].then(^{
                [weakSelf refreshMembers];
            });
        }
        [weakSelf refreshMembers];
        [weakSelf reloadData];
    }];
}

- (void)dealloc {
    // 销毁监听群成员更新通知
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_GROUP_MEMBERUPDATE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKRealnameVerifiedUpdatedNotification object:nil];
}


// 群成员更新
-(void) memberUpdate {
    if(self.viewModel.groupType == WKGroupTypeSuper) {
        return;
    }
   self.topNMembers = [[WKChannelMemberDB shared] getMembersWithChannel:self.channel limit:self.limitMemberCount];
    self.viewModel.memberOfMe = nil; // 将我在群成员的数据置空，让其重新获取
    [self refreshMembers];
    [self reloadData];
}



#define memberGridViewTop 20.0f
-(void) refreshMembers {
    [self.settingMemberGridView reloadData];
    self.headerView.lim_height = [self.settingMemberGridView viewHeight] + memberGridViewTop;
    [self.tableView reloadData];
    
    self.title = [NSString stringWithFormat:LLang(@"聊天信息(%lu)"),self.viewModel.memberCount];
}
//
//- (UITableView *)tableView{
//    if (!_tableView) {
//        _tableView = [[UITableView alloc] initWithFrame:[self visibleRect] style:UITableViewStyleGrouped];
//        _tableView.dataSource = self;
//        _tableView.delegate = self;
//        UIEdgeInsets separatorInset = _tableView.separatorInset;
//        separatorInset.right          = 0;
//        _tableView.separatorInset = separatorInset;
//        _tableView.backgroundColor=[UIColor clearColor];
//        _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(-0.1f, 0.0f, 0.0f, 0.0f); // TODO: 这里必须要-0.1 要不然滚动条不能滚到顶部 why？？
//        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
//        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
//        _tableView.sectionHeaderHeight = 0.0f;
//        _tableView.sectionFooterHeight = 0.0f;
//
//        _tableView.tableHeaderView = self.headerView;
//        _tableView.tableFooterView = [[UIView alloc] init];
//
//        [_tableView.tableHeaderView setBackgroundColor:[UIColor clearColor]];
//
//
//    }
//    return _tableView;
//}

- (UIView *)headerView {
    if(!_headerView) {
        _headerView = [[UIView alloc] init];
        _headerView.lim_width = self.view.lim_width;
        [_headerView addSubview:self.settingMemberGridView];
        self.settingMemberGridView.lim_top = memberGridViewTop;
    }
    return _headerView;
}

- (WKSettingMemberGridView *)settingMemberGridView {
    if(!_settingMemberGridView) {
        _settingMemberGridView = [WKSettingMemberGridView initWithMaxWidth:self.view.lim_width -  10.0f numberOfLine:5 hasMore:false];
        _settingMemberGridView.delegate = self;
        _settingMemberGridView.lim_left = 5.0f;
        __weak typeof(self) weakSelf = self;
        [_settingMemberGridView setOnMore:^{
            [weakSelf showMoreMembers];
        }];
    }
    return _settingMemberGridView;
}

-(void) showMoreMembers {
    
    WKMemberListVC *vc = [WKMemberListVC new];
    vc.channel = self.channel;
    [WKNavigationManager.shared pushViewController:vc animated:YES];
    
}

#pragma mark - WKSettingMemberGridViewDelegate

-(UIView*) settingMemberGridView:(WKSettingMemberGridView*)settingMemberGridView size:(CGSize)size atIndex:(NSInteger)index{
    if(index< self.topNMembers.count) {
        WKChannelMember *member = self.topNMembers[index];
        return [self memberAvatarView:size member:member];
    }
    if(index == self.topNMembers.count) {
        return [self memberAddOrSubView:size isSub:false];
    }
    if(index == self.topNMembers.count + 1) {
        return [self memberAddOrSubView:size isSub:true];
    }
    return nil;
}

- (void)settingMemberGridView:(WKSettingMemberGridView *)settingMemberGridView didSelect:(NSInteger)index {
    if([self showMemberAddBtn] && index == self.topNMembers.count) {
        [self memberAddClick];
    }else if([self showMemberSubBtn] && index == self.topNMembers.count + 1) {
        [self memberSubClick];
    }else {
        WKChannelMember *member = self.topNMembers[index];
        [self membberAvatarClick:member];
    }
}


-(UIView*) memberAvatarView:(CGSize)size member:(WKChannelMember*)member {
    

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];

    
    // 用户头像
    WKUserAvatar *avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 54.0f,  54.0f)];
    WKChannelInfo *avatarChannelInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:member.memberUid channelType:WK_PERSON]];
    if (avatarChannelInfo && avatarChannelInfo.avatarCacheKey.length > 0) {
        NSString *fullUrl = [WKAvatarUtil getFullAvatarWIthPath:member.memberAvatar];
        NSString *separator = [fullUrl containsString:@"?"] ? @"&" : @"?";
        [avatarView setUrl:[NSString stringWithFormat:@"%@%@v=%@", fullUrl, separator, avatarChannelInfo.avatarCacheKey]];
    } else {
        [avatarView setUrl:[WKAvatarUtil getFullAvatarWIthPath:member.memberAvatar]];
    }
    
    [view addSubview:avatarView];
    avatarView.lim_left = view.lim_width/2.0f - avatarView.lim_width/2.0f;
//    avatarView.backgroundColor = [UIColor orangeColor];
    
   
    
    // 在线状态
    WKOnlineBadgeView *onlineBadgeView = [WKOnlineBadgeView initWithTip:nil];
    [avatarView addSubview:onlineBadgeView];
    onlineBadgeView.hidden = YES;
    WKUserOnlineResp *onlineResp = [self.viewModel memberOnline:member.memberUid];
    if(onlineResp) {
        onlineBadgeView.hidden = NO;
        if(onlineResp.online) {
            onlineBadgeView.tip = nil;
        }else{
            if ([[NSDate date] timeIntervalSince1970] - onlineResp.lastOffline<60) {
                onlineBadgeView.tip = LLang(@"刚刚");
            }else if( onlineResp.lastOffline+60*60>[[NSDate date] timeIntervalSince1970]) {
                onlineBadgeView.tip =[NSString stringWithFormat:LLang(@"%0.0f分钟"),([[NSDate date] timeIntervalSince1970]-onlineResp.lastOffline)/60];
            }else {
                onlineBadgeView.hidden = YES;
            }
        }
    }
    if(onlineResp && onlineResp.online) {
        onlineBadgeView.lim_left = avatarView.lim_right - onlineBadgeView.lim_width - 12.0f;
    }else{
        onlineBadgeView.lim_left = avatarView.lim_right - onlineBadgeView.lim_width;
    }
   
    onlineBadgeView.lim_top = 0.0f;

    // 名字
     UILabel *nameLbl = [UILabel new];
     NSString *displayName = nil;
     if(member.memberRemark && ![member.memberRemark isEqualToString:@""]) {
          displayName = member.memberRemark;
     }else {
          displayName = member.memberName;
     }
    WKChannelInfo *memberChannelInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:member.memberUid channelType:WK_PERSON]];
    if(memberChannelInfo && memberChannelInfo.remark && ![memberChannelInfo.remark isEqualToString:@""]) {
        displayName = memberChannelInfo.remark; // 有好友备注，优先显示好友备注
    }

    nameLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    [nameLbl setTextColor:[WKApp shared].config.defaultTextColor];
     [nameLbl setTextAlignment:NSTextAlignmentCenter];
     nameLbl.lim_width = avatarView.lim_width;
     nameLbl.lim_height = 17.0f;

    // v2 外部群后缀（YUJ-93）：viewer-relative 判定外部时 name 后拼接「 @SpaceName」
    // 使用 attributedText 以便后缀用浅灰色，与 Android AllMembersAdapter 一致。
    NSString *viewerSpaceId = [WKExternalViewerResolver currentViewerSpaceId];
    WKExternalResolveResult *ext = [WKExternalViewerResolver resolveFromExtras:member.extra
                                                                 viewerSpaceId:viewerSpaceId];
    if (ext.isExternal && ext.sourceSpaceName.length > 0) {
        NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:displayName ?: @""
                                                                                attributes:@{NSFontAttributeName: nameLbl.font,
                                                                                             NSForegroundColorAttributeName: nameLbl.textColor ?: [UIColor blackColor]}];
        UIColor *suffixColor = [UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f];
        [attr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" @%@", ext.sourceSpaceName]
                                                                     attributes:@{NSFontAttributeName: nameLbl.font,
                                                                                  NSForegroundColorAttributeName: suffixColor}]];
        nameLbl.attributedText = attr;
        nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    } else {
        nameLbl.text = displayName;
    }

     [view addSubview:nameLbl];
     nameLbl.lim_top = avatarView.lim_bottom + 5.0f;
     nameLbl.lim_left = view.lim_width/2.0f - nameLbl.lim_width/2.0f;

    // YUJ-381 实名 ✓ 徽章：宫格 cell 昵称后内联 10×10 蓝勾。
    // 设计原则：实名标识优先 —— 长名时强制 ... 截断保住徽章可见。
    NSNumber *memberFlag = [WKChannelUtil isRealnameVerifiedFromExtra:member.extra];
    BOOL realnameVerified = NO;
    if (memberFlag != nil) {
        realnameVerified = memberFlag.boolValue;
    } else {
        WKChannelInfo *personInfo = [[WKSDK shared].channelManager getChannelInfo:[[WKChannel alloc] initWith:member.memberUid channelType:WK_PERSON]];
        NSNumber *personFlag = [WKChannelUtil isRealnameVerifiedFromExtra:personInfo.extra];
        realnameVerified = personFlag.boolValue;
    }
    if (realnameVerified) {
        const CGFloat kBadgeW = 10.0f;
        const CGFloat kBadgeGap = 2.0f;
        const CGFloat kSidePad = 2.0f; // cell 左右安全留白

        nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        nameLbl.numberOfLines = 1;
        nameLbl.textAlignment = NSTextAlignmentLeft;

        // 文本实际像素宽度
        CGFloat textW = 0.0f;
        if (nameLbl.attributedText.length > 0) {
            textW = [nameLbl.attributedText size].width;
        } else if (nameLbl.text.length > 0 && nameLbl.font) {
            textW = [nameLbl.text sizeWithAttributes:@{NSFontAttributeName: nameLbl.font}].width;
        }
        // 关键差异：可用宽度按 cell 宽 (view.lim_width) 算，不再卡死在 avatar.lim_width
        // —— avatar 是 54pt，cell 一般 ~73pt，给名字多留 ~17pt 让正常昵称不被截断。
        CGFloat usableW = view.lim_width - kSidePad * 2;
        CGFloat maxNameW = usableW - kBadgeGap - kBadgeW;
        if (maxNameW < 0) maxNameW = 0;
        CGFloat usedW = MIN(textW, maxNameW);
        // 名字 + 徽章 整体居中于 cell
        CGFloat totalW = usedW + kBadgeGap + kBadgeW;
        nameLbl.lim_width = usedW;
        nameLbl.lim_left = view.lim_width/2.0f - totalW/2.0f;
        if (nameLbl.lim_left < kSidePad) nameLbl.lim_left = kSidePad; // 安全 clamp

        UIImageView *badge = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kBadgeW, kBadgeW)];
        badge.contentMode = UIViewContentModeScaleAspectFit;
        badge.image = [WKApp.shared loadImage:@"Common/ic_realname_verified_mini" moduleID:@"WuKongBase"];
        [view addSubview:badge];
        badge.lim_left = nameLbl.lim_left + nameLbl.lim_width + kBadgeGap;
        badge.lim_top = nameLbl.lim_top + (nameLbl.lim_height - kBadgeW) / 2.0f;
        // 兜底：如果某种边缘场景下徽章右沿超过了 cell，强制贴右边界（保「徽章必出」）。
        CGFloat maxBadgeLeft = view.lim_width - kSidePad - kBadgeW;
        if (badge.lim_left > maxBadgeLeft) {
            badge.lim_left = maxBadgeLeft;
            // 同时收缩名字到不和徽章重叠
            CGFloat nameMaxRight = badge.lim_left - kBadgeGap;
            if (nameLbl.lim_left + nameLbl.lim_width > nameMaxRight) {
                nameLbl.lim_width = MAX(0, nameMaxRight - nameLbl.lim_left);
            }
        }
    } else if (member.memberUid.length > 0) {
        // 没拿到 @YES：可能 person 缓存还没补上，触发预拉取。回写后会发
        // WKRealnameVerifiedUpdatedNotification，VC 命中本 cell 的 uid 时
        // 会 reloadData 把宫格重新排一次。
        [WKRealnamePrefetcher ensureFetched:member.memberUid];
    }

    UIView *roleView = [self getRoleView:member.role];
    if(roleView) {
        [avatarView addSubview:roleView];
        roleView.lim_centerX_parent = avatarView;
        roleView.lim_top = avatarView.lim_height - roleView.lim_height;
    }
    return view;
}

-(UIView*) getRoleView:(WKMemberRole)role {
    
    NSString *roleName = @"";
    
    
    UIView *roleView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0f, 15.0f)];
    roleView.layer.masksToBounds = YES;
    roleView.backgroundColor = WKApp.shared.config.cellBackgroundColor;
    
    UILabel *roleNameLbl = [[UILabel alloc] init];
    roleNameLbl.font = [WKApp.shared.config appFontOfSize:8.0f];
    [roleView addSubview:roleNameLbl];
    
    if(role == WKMemberRoleManager) {
        roleName = LLang(@"管理员");
        roleNameLbl.textColor = WKApp.shared.config.themeColor;
    }else if(role == WKMemberRoleCreator) {
        roleName = LLang(@"群主");
        roleNameLbl.textColor = [UIColor orangeColor];
    }else {
        return nil;
    }
    roleNameLbl.text = roleName;
    [roleNameLbl sizeToFit];
    
    CGFloat width = MAX(roleNameLbl.lim_width+4.0f, roleView.lim_width);
    roleView.lim_width = width;
    roleView.layer.cornerRadius = roleView.lim_height/2.0f;
    
    roleNameLbl.lim_centerX_parent = roleView;
    roleNameLbl.lim_centerY_parent = roleView;
    return roleView;
}

-(UIView*) memberAddOrSubView:(CGSize)size isSub:(BOOL) isSub {
     UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    WKImageView *imgView = [[WKImageView alloc] initWithFrame:CGRectMake(0, 0, 54.0f, 54.0f)];
    imgView.lim_left = view.lim_width/2.0f - imgView.lim_width/2.0f;
    if(isSub) {
        imgView.image = [self imageName:@"Conversation/Setting/MemberDelete"];
    }else {
        imgView.image = [self imageName:@"Conversation/Setting/MemberAdd"];
    }
   
    [view addSubview:imgView];
    return view;
}


-(NSInteger) numberOfSettingMemberGridView:(WKSettingMemberGridView*)settingMemberGridView {
    return (self.topNMembers?self.topNMembers.count:0) + ([self showMemberAddBtn]?1:0) + ([self showMemberSubBtn]?1:0);
}

// 是否显示成员添加按钮
-(BOOL) showMemberAddBtn {
    return true;
}
// 是否显示成员删除按钮
-(BOOL) showMemberSubBtn {
    return [self.viewModel isManagerOrCreatorForMe];
}
// 成员头像点击
-(void) membberAvatarClick:(WKChannelMember*) member {
    NSMutableDictionary *paramDict = [[NSMutableDictionary alloc] init];
    [paramDict setObject:member.memberUid?:@"" forKey:@"uid"];
    [paramDict setObject:member.extra[@"vercode"]?:@"" forKey:@"vercode"];
    [paramDict setObject:[[WKChannel alloc] initWith:member.channelId?:@"" channelType:member.channelType] forKey:@"channel"];
    [[WKApp shared] invoke:WKPOINT_USER_INFO param:paramDict];
}
-(void) memberAddClick {
    NSMutableArray *disableUids = [NSMutableArray array];
    NSArray<WKChannelMember*> *members = [[WKSDK shared].channelManager getMembersWithChannel:self.channel];
    if(members) {
        for (WKChannelMember *member in members) {
            [disableUids addObject:member.memberUid];
        }
    }
    __weak typeof(self) weakSelf = self;
    [[WKApp shared] invoke:WKPOINT_CONTACTS_SELECT param:@{@"on_finished":^(NSArray<NSString*>*uids){
        
       NSArray<WKChannelMember*> *blacklistMembers = [[WKChannelMemberDB shared] getBlacklistMembersWithChannel:self.channel];
        if(blacklistMembers && blacklistMembers.count>0) {
            NSMutableArray *names = [NSMutableArray array];
            for (WKChannelMember *member in blacklistMembers) {
                for (NSString *uid in uids) {
                    if([uid isEqualToString:member.memberUid]) {
                        [names addObject:member.memberName];
                    }
                }
            }
            if(names.count>0) {
                NSString *tipContent = [NSString stringWithFormat:LLang(@"%@在群黑名单中"),[names componentsJoinedByString:@"、"]];
                [WKAlertUtil alert:tipContent];
                return;
            }
        }
        
        if(![weakSelf.viewModel isManagerOrCreatorForMe] && weakSelf.viewModel.channelInfo.invite) {
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
            UIAlertController *alertController =   [UIAlertController alertControllerWithTitle:@"" message:LLang(@"群主或管理员已启用\"群聊邀请确认\"，邀请朋友进群可向群主或群管理员描述原因。") preferredStyle:UIAlertControllerStyleAlert];
            [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                textField.placeholder = LLangW(@"说明邀请理由", weakSelf);
            }];
            [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                       
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:LLang(@"发送") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [weakSelf requestGroupMemberInvite:uids remark:alertController.textFields[0].text];
            }]];
            [[WKNavigationManager shared].topViewController presentViewController:alertController animated:YES completion:nil];
            return;
        }else {
            [[WKNavigationManager shared].topViewController.view showHUD];
            [[WKGroupManager shared] groupNo:weakSelf.channel.channelId membersOfAdd:uids object:nil complete:^(NSError * _Nonnull error) {
                [[WKNavigationManager shared].topViewController.view hideHud];
                if(error) {
                    [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                    return;
                }
                [[WKNavigationManager shared] popViewControllerAnimated:YES];
            }];
        }
    },@"disables":disableUids}];
}

-(void) requestGroupMemberInvite:(NSArray<NSString*>*)uids remark:(NSString*)remark{
    __weak typeof(self) weakSelf = self;
    [self.viewModel requestGroupMemberInvite:uids remark:remark].then(^{
        [[WKNavigationManager shared].topViewController.view showMsg:LLangW(@"已发送", weakSelf)];
        return;
    }).catch(^(NSError *error){
        [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
        return;
    });
}


-(void) memberSubClick {
    
    __weak typeof(self) weakSelf = self;
    
    WKMemberListVC *vc = [WKMemberListVC new];
    vc.title = LLang(@"删除群成员");
    vc.channel = self.channel;
    vc.edit = true;
    
    NSMutableArray<NSString*> *disableUsers = [NSMutableArray array];
    if(self.viewModel.memberOfMe.role == WKMemberRoleManager) {
        NSArray<WKChannelMember*> *members = [WKChannelMemberDB.shared getManagerAndCreator:self.channel];
        if(members && members.count>0) {
            for (WKChannelMember *member in members) {
                [disableUsers addObject:member.memberUid];
            }
        }
    }
    vc.hiddenUsers = @[WKApp.shared.loginInfo.uid];
    vc.disableUsers = disableUsers;
    vc.onFinishedSelect = ^(NSArray<NSString *> * _Nonnull uids) {
        [[WKGroupManager shared] groupNo:weakSelf.channel.channelId membersOfDelete:uids object:nil complete:^(NSError * _Nonnull error) {
            if(error) {
                [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                return;
            }
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }];
    };
    [WKNavigationManager.shared pushViewController:vc animated:YES];
    
//    NSArray<WKChannelMember*> *members = [[WKSDK shared].channelManager getMembersWithChannel:self.channel];
//    if(members) {
//        NSMutableArray<WKContactsSelect*> *contactsSelects = [NSMutableArray array];
//        for (WKChannelMember *member in members) {
//            if(![[WKApp shared].loginInfo.uid isEqualToString:member.memberUid]) {
//                [contactsSelects addObject:[WKModelConvert toContactsSelect:member]];
//            }
//        }
//        [[WKApp shared] invoke:WKPOINT_CONTACTS_SELECT param:@{@"on_finished":^(NSArray<NSString*>*uids){
//            [[WKGroupManager shared] groupNo:self.channel.channelId membersOfDelete:uids object:nil complete:^(NSError * _Nonnull error) {
//                if(error) {
//                    [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
//                    return;
//                }
//                [[WKNavigationManager shared] popViewControllerAnimated:YES];
//            }];
//        },@"data":contactsSelects,@"title":LLang(@"删除群成员")}];
//    }
   
}


#pragma mark - WKConversationSettingDelegate
// 群名点击
- (void)settingOnGroupNameClick:(WKConversationSettingVM *)vm {
    WKMemberRole roleOfMe = self.viewModel.memberOfMe.role;
    if(roleOfMe != WKMemberRoleManager && roleOfMe!=WKMemberRoleCreator) {
        [WKAlertUtil alert:LLang(@"只有群主或管理员才能修改")];
        return;
    }
    WKInputVC *inputVC = [WKInputVC new];
    inputVC.title = LLang(@"修改群名称");
    inputVC.maxLength = 10;
    inputVC.placeholder = LLang(@"群名称");
    inputVC.defaultValue = self.viewModel.channelInfo.name;
    [inputVC setOnFinish:^(NSString * _Nonnull value) {
        [[WKGroupManager shared] groupUpdate:self.channel.channelId attrKey:WKGroupAttrKeyName attrValue:value complete:^(NSError * _Nonnull error) {
            if(error) {
                [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                return;
            }
             [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }];
       
    }];
    [[WKNavigationManager shared] pushViewController:inputVC animated:YES];
}
// 群头像点击
-(void) settingOnGroupAvatarClick:(WKConversationSettingVM*)vm {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *actionSheet = [WKActionSheetView2 initWithTip:nil];
    [actionSheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"拍照") onClick:^{
        [[WKPhotoService shared] getPhotoFromCamera:^(UIImage * _Nonnull image) {
            [weakSelf cropGroupAvatar:image];
        }];
    }]];
    [actionSheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"从手机相册选择") onClick:^{
        [[WKPhotoService shared] getPhotoOneFromLibrary:^(UIImage * _Nonnull image) {
            [weakSelf cropGroupAvatar:image];
        }];
    }]];
    [actionSheet show];
}

-(void) cropGroupAvatar:(UIImage*)image {
    TOCropViewController *cropController = [[TOCropViewController alloc] initWithCroppingStyle:TOCropViewCroppingStyleDefault image:image];
    cropController.delegate = self;
    cropController.aspectRatioPreset = TOCropViewControllerAspectRatioPresetSquare;
    cropController.aspectRatioPickerButtonHidden = YES;
    [self presentViewController:cropController animated:YES completion:nil];
}

#pragma mark - TOCropViewControllerDelegate

- (void)cropViewController:(TOCropViewController *)cropViewController didCropToImage:(UIImage *)image withRect:(CGRect)cropRect angle:(NSInteger)angle {
    [self dismissViewControllerAnimated:YES completion:nil];
    NSData *data = [[WKPhotoService shared] compressImageSize:image toByte:1024*50];
    NSString *path = [NSString stringWithFormat:@"groups/%@/avatar", self.channel.channelId];

    __weak typeof(self) weakSelf = self;
    [self.view showHUD:LLang(@"上传中")];
    [[WKAPIClient sharedClient] fileUpload:path data:data progress:^(NSProgress *progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.view switchHUDProgress:progress.fractionCompleted];
        });
    } completeCallback:^(id resposeObject, NSError *error) {
        if (error) {
            [weakSelf.view switchHUDSuccess:LLangW(@"上传失败", weakSelf)];
            return;
        }
        [weakSelf.view switchHUDSuccess:LLangW(@"上传成功", weakSelf)];
        [[WKSDK shared].channelManager refreshAvatarCacheKey:weakSelf.channel];
        WKChannelInfo *updatedInfo = [[WKSDK shared].channelManager getChannelInfo:weakSelf.channel];
        NSString *cacheURL = [WKAvatarUtil getGroupAvatar:weakSelf.channel.channelId cacheKey:updatedInfo.avatarCacheKey];
        [[SDImageCache sharedImageCache] storeImage:image forKey:cacheURL toDisk:YES completion:nil];
        [[WKSDK shared].channelManager fetchChannelInfo:weakSelf.channel completion:nil];
        [weakSelf reloadData];
    }];
}

// 群公告点击
-(void) settingOnGroupNoticeClick:(WKConversationSettingVM*)vm {
    WKMemberRole roleOfMe = self.viewModel.memberOfMe.role;
    BOOL managerRole = roleOfMe == WKMemberRoleManager || roleOfMe==WKMemberRoleCreator;
//    if(!managerRole) {
//        [WKAlertUtil alert:LLang(@"只有群主或管理员才能修改")];
//        return;
//    }
    BOOL editable = managerRole;
    WKTextViewVC *textViewVC = [WKTextViewVC new];
    textViewVC.title = LLang(@"修改群公告");
    textViewVC.maxLength = 400;
    textViewVC.placeholder = [NSString stringWithFormat:LLang(@"群公告（最长输入%ld个字符）"),textViewVC.maxLength];
    textViewVC.editable = editable;
    textViewVC.defaultValue = self.viewModel.channelInfo.notice;
    if(!editable) {
        textViewVC.tip = LLang(@"----- 仅群主和管理员可编辑 -----");
    }
   
    [textViewVC setOnFinish:^(NSString * _Nonnull value) {
        [[WKGroupManager shared] groupUpdate:self.channel.channelId attrKey:WKGroupAttrKeyNotice attrValue:value complete:^(NSError * _Nonnull error) {
            if(error) {
                [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                return;
            }
             [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }];
       
    }];
    [[WKNavigationManager shared] pushViewController:textViewVC animated:YES];
}
// 频道数据更新
-(void) settingOnChannelUpdate:(WKConversationSettingVM*)vm {
    [self.tableView reloadData];
}

- (void)settingOnTopNMembersUpdate:(WKConversationSettingVM *)vm {
    if(!self.settingMemberGridView.hasMore) {
        [self requestTopNMembers:self.limitMemberCount];
    }
    [self refreshMembers];
}

// 清空消息
- (void)settingOnClearMessages:(WKConversationSettingVM *)vm {
     __weak typeof(self) weakSelf = self;
    
    WKActionSheetView2 *actionSheetView = [WKActionSheetView2 initWithTip:nil];
    [actionSheetView addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"清空聊天记录") onClick:^{
        [[WKMessageManager shared] clearMessages:weakSelf.channel];
    }]];
    [actionSheetView show];

}
// 退出群聊
- (void)settingOnGroupExit:(WKConversationSettingVM *)vm {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *actionSheetView = [WKActionSheetView2 initWithTip:LLang(@"退出后不会通知群聊中其他成员，且不会再接收此群聊消息")];
      [actionSheetView addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"确定") onClick:^{
          [[WKGroupManager shared] didGroupExit:weakSelf.channel.channelId complete:^(NSError * _Nonnull error) {
              [[WKNavigationManager shared] popToRootViewControllerAnimated:YES];
               [[WKSDK shared].conversationManager deleteConversation: weakSelf.channel];
          }];
      }]];
      [actionSheetView show];
   
}

/**
 
 在群里的昵称
 @param vm <#vm description#>
 */
-(void) settingOnNickNameInGroup:(WKConversationSettingVM*)vm {
    if(!self.viewModel.memberOfMe) {
        return;
    }
    NSString *name = self.viewModel.memberOfMe.memberName;
    if(self.viewModel.memberOfMe.memberRemark && ![self.viewModel.memberOfMe.memberRemark isEqualToString:@""]) {
        name = self.viewModel.memberOfMe.memberRemark;
    }
    WKInputVC *inputVC = [WKInputVC new];
    inputVC.title = LLang(@"我在本群的昵称");
    inputVC.placeholder = LLang(@"在这里可以设置你在这个群里的昵称。这个昵称只会在此群内显示。");
    inputVC.defaultValue = name;
    inputVC.maxLength = 10;
    [inputVC setOnFinish:^(NSString * _Nonnull value) {
        [[WKGroupManager shared] didMemberUpdateAtGroup:self.channel.channelId forMemberUID:self.viewModel.memberOfMe.memberUid withAtrr:@{@"remark":value?:@""} complete:^(NSError * _Nonnull error) {
            if(error) {
                [[WKNavigationManager shared].topViewController.view showMsg:error.domain];
                return;
            }
             [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }];
        
    }];
    [[WKNavigationManager shared] pushViewController:inputVC animated:YES];
}


- (void)settingOnReport:(WKConversationSettingVM *)vm {
    WKWebViewVC *vc = [[WKWebViewVC alloc] init];
    vc.title = LLang(@"投诉");
    vc.url = [NSURL URLWithString:[WKApp shared].config.reportUrl];
    vc.channel = self.channel;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}

@end
