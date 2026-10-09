//
//  WKUserInfoVM.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKUserInfoVM.h"
#import "WKLabelItemCell.h"
#import "WKTableSectionUtil.h"
#import "WKMultiLabelItemCell.h"
#import "WKForbiddenSpeakTimeSelectVC.h"
#import "WKCountdownFormItemCell.h"
#import "WKExternalViewerResolver.h"


@interface UserModel : WKModel

@property (nonatomic, strong) NSString *uid;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *zone;
@property (nonatomic, strong) NSString *phone;
@property (nonatomic, assign) BOOL mute;
@property (nonatomic, assign) BOOL top;
@property (nonatomic, assign) NSInteger sex;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, strong) NSString *shortNo;
@property (nonatomic, assign) BOOL chatPwdOn;
@property (nonatomic, assign) BOOL screenshot;
@property (nonatomic, assign) BOOL receipt;
@property (nonatomic, assign) BOOL online;
@property (nonatomic, assign) NSInteger lastOffline;
@property (nonatomic, assign) NSInteger deviceFlag;
@property (nonatomic, assign) BOOL follow;
@property (nonatomic, assign) BOOL beDeleted;
@property (nonatomic, assign) BOOL beBlacklist;
@property (nonatomic, strong) NSString *vercode;
@property (nonatomic, strong) NSString *sourceDesc;
@property (nonatomic, strong) NSString *remark;
@property (nonatomic, assign) NSInteger isUploadAvatar;
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, assign) BOOL robot;
@property (nonatomic, assign) BOOL isDestroy;
@property (nonatomic, assign) BOOL flame;
@property (nonatomic, assign) NSInteger flameSecond;
@property (nonatomic, copy) NSString *botDescription;
@property (nonatomic, copy) NSString *botCreatorName;
/// 机器人创建者 uid（来自后端 /users/<uid> 响应顶层 `bot_creator_uid`）。
/// 对齐 Android `UserInfo.bot_creator_uid`（wkuikit/.../enity/UserInfo.java:35-38）。
/// VC 用 `loginUid == botCreatorUid` 判定当前登录者是否为该 Bot 的创建者，
/// 决定是否在头像页右上角显示"修改头像"入口。
@property (nonatomic, copy) NSString *botCreatorUid;

// --- (GH#76) external-user fields ---
// homeSpaceId: 用户的归属 Space，跨 Space 判定的权威字段（来自后端
// /users/<uid> 响应里的 home_space_id）。对齐 web PR #977。
// isExternal: 老的 flag，保留做兼容 fallback；当后端未回 home_space_id
// 时才参与判定（isExternalUser helper）。
@property (nonatomic, copy) NSString *homeSpaceId;
@property (nonatomic, assign) NSInteger isExternal;

// --- / 实名认证字段 ---
// 对齐 web `orgData.realname_verified`：/users/<uid> 响应顶层下发，需要回写
// 到 person 缓存的 extra，让 WKMessageCell / WKMemberCell / WKUserInfoVC
// 的实名徽章 fallback 路径能拿到 @YES。原本 UserModel 漏字段导致
// channelInfoFromUser 构造的 WKChannelInfo 永远缺 realname_verified，
// stale member.extra=@NO 直接阻断了 fallback。
@property (nonatomic, assign) BOOL realnameVerified;
@property (nonatomic, assign) NSTimeInterval realnameVerifiedAt;

// : viewer-relative 判定「当前用户是否对观察者是外部」。
// 优先用 homeSpaceId vs 当前 viewer space；没有时 fallback 到 legacy
// is_external。注意：不做 loginInfo.uid 自我判定，调用方已在各 handler
// 头部自己过滤了 self。
- (BOOL)isExternalUser;

@end

@interface WKUserInfoVM ()<WKChannelManagerDelegate>

@property(nonatomic,strong) channelInfoCompletion completion;


@property(nonatomic,strong) NSMutableDictionary *contextDict;

@property(nonatomic,copy) NSString *introEndpointID;
@property(nonatomic,copy) NSString *botDescription;
@property(nonatomic,copy) NSString *botCreatorName;
@property(nonatomic,copy) NSString *botCreatorUid;

// : 缓存当前 uid 的 home_space_id / is_external，供
// user.info.addBlack / user.info.freeFriend handler 做同 Space 判定。
// 每次 loadPersonChannelInfo 完成后覆写一次。
@property(nonatomic,copy) NSString *userHomeSpaceId;
@property(nonatomic,assign) NSInteger userIsExternalLegacy;

// 手机号/邮箱卡片的禁用态判定专用缓存，不能复用 channelInfo.status——
// WKUserInfoVC 的拉黑/取消拉黑操作会直接覆写 channelInfo.status
// （WKChannelStatusBlacklist/WKChannelStatusNormal），这个字段已经不干净。
// 这里单独存一份 user.status 原始值；0 = 被禁用（服务端 StatusDisable）。
@property(nonatomic,assign) NSInteger userAccountStatus;

// user.is_destroy：0 正常，1 冷静期，2 已注销。channelInfoFromUser 从没把
// 这个字段搬进 channelInfo，这里单独缓存。boolValue 对非 0 值都是 YES，
// 刚好把冷静期/已注销两种状态一起收进一个布尔里，不用再拆分支。
@property(nonatomic,assign) BOOL userIsDestroy;

// 手机号是否已展开（点击查看→点击复制两段式交互）。这是"每次渲染当前这张
// 卡片"要用的临时状态，不能挂在 VM 属性上读写——同一个 sid 的 handler 在
// WKApp 全局 endpoint 表里只有一份，闭包里的 weakSelf 永远绑定"最后一次
// -init 的那个 VM 实例"；同时打开两张名片（比如 A 名片进聊天再进 B 名片）
// 时，回到 A 读到的会是 B 的 phoneRevealed。改用 handler 每次调用都拿到的
// param[@"context"]（即下面 contextDict，per-VM 实例）来存取，才不会串。
@property(nonatomic,copy) NSString *userPhone;
@property(nonatomic,copy) NSString *userEmail;

@end

@implementation WKUserInfoVM

- (instancetype)init{
    self = [super init];
    if (self) {
        self.introEndpointID = @"user.info.intro";
        [[WKSDK shared].channelManager addDelegate:self];
        
        [self initItems];
        
    }
    return self;
}

-(void) initData {
    if(self.fromChannel) {
        self.memberOfMy = [[WKSDK shared].channelManager getMember:self.fromChannel uid:[WKApp shared].loginInfo.uid];
        self.memberOfUser = [[WKSDK shared].channelManager getMember:self.fromChannel uid:self.uid];
        self.fromChannelInfo = [[WKSDK shared].channelManager getChannelInfo:self.fromChannel];
        if(!self.fromChannelInfo) {
            [[WKSDK shared].channelManager fetchChannelInfo:self.fromChannel];
        }
        [self reloadData];
    }
}

- (void)dealloc{
     [[WKSDK shared].channelManager removeDelegate:self];
}

- (void)loadPersonChannelInfo:(NSString *)uid completion:(channelInfoCompletion)completion {
    self.completion = completion;
    self.uid = uid;
    
    __weak typeof(self) weakSelf = self;
    [self requestUserDetail:uid].then(^(UserModel *user){
        // 清空缓存的头像
        [[SDImageCache sharedImageCache] removeImageForKey:[WKAvatarUtil getAvatar:user.uid?:@""] withCompletion:nil];

        // 保存 Bot 信息
        weakSelf.botDescription = user.botDescription ?: @"";
        weakSelf.botCreatorName = user.botCreatorName ?: @"";
        weakSelf.botCreatorUid = user.botCreatorUid ?: @"";

        // : 缓存 home_space_id / is_external，供
        // user.info.addBlack / user.info.freeFriend handler 判同 Space。
        weakSelf.userHomeSpaceId = user.homeSpaceId ?: @"";
        weakSelf.userIsExternalLegacy = user.isExternal;
        weakSelf.userAccountStatus = user.status;
        weakSelf.userIsDestroy = user.isDestroy;

        // 手机号/邮箱只存在 VM 的临时属性里，不回写进 channelInfo.extra：
        // extra 会被整体 JSON 序列化持久化到本地 channel 表（WKChannelInfoDB
        // extraToStr:/SQL_CHANNEL_UPDATE），且是整列覆盖不是 merge——
        // 一旦落库，这两个字段就会明文留在本机数据库里，还会被其它不带
        // phone/email 的 channelInfo 刷新路径整体覆盖掉。
        // 同上，不用 `?: @""` 兜底——user.phone/user.email 从 UserModel 出来时
        // nil 和 @"" 已经区分好了，这里原样传下去，不要在这一层又抹平。
        weakSelf.userPhone = user.phone;
        weakSelf.userEmail = user.email;

        // 重新缓存用户的channelInfo
        WKChannelInfo *channelInfo = [weakSelf channelInfoFromUser:user];
        WKChannel *channel = [[WKChannel alloc] initWith:uid channelType:WK_PERSON];
        channelInfo.channel = channel;
        weakSelf.channelInfo = channelInfo;
        [[WKSDK shared].channelManager addOrUpdateChannelInfo:channelInfo];
        if(completion) {
             completion();
        }
    }).catch(^(NSError *err){
        [WKNavigationManager.shared.topViewController.view showHUDWithHide:err.domain];
    });
    
//    WKChannel *channel = [[WKChannel alloc] initWith:uid channelType:WK_PERSON];
//    WKChannelInfo *channelInfo = [[WKSDK shared].channelManager getChannelInfo:channel];
//    
//    if(channelInfo) {
//        self.channelInfo = channelInfo;
//        if(completion) {
//             completion();
//        }
//    }
//    // 远程提取频道信息
//    [[WKSDK shared].channelManager fetchChannelInfo:channel completion:^(WKChannelInfo * channelInfo) {
//        if(channelInfo) {
//            [[WKSDK shared].channelManager addOrUpdateChannelInfo:channelInfo];
//        }
//    }];
}

-(AnyPromise*) applyFriend:(NSString*)uid remark:(NSString*)remark vercode:(NSString*)vercode{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{@"to_uid":uid?:@"",@"to_name":self.channelInfo.name?:@"",@"remark":remark?:@"",@"vercode":vercode?:@""}];
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (spaceId.length > 0) {
        params[@"space_id"] = spaceId;
    }
    return [[WKAPIClient sharedClient] POST:@"friend/apply" parameters:params];
}

-(AnyPromise*) updateRemark:(NSString*)remark {
    return [[WKAPIClient sharedClient] PUT:@"friend/remark" parameters:@{@"uid":self.channelInfo.channel.channelId?:@"",@"remark":remark?:@""}];
}

-(AnyPromise*) deleteFriend {
     return [[WKAPIClient sharedClient] DELETE:[NSString stringWithFormat:@"friends/%@",self.channelInfo.channel.channelId?:@""] parameters:nil];
}


-(AnyPromise*) addBlacklist {
    return [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"user/blacklist/%@",self.channelInfo.channel.channelId?:@""] parameters:nil];
}
-(AnyPromise*) deleteBlacklist {
    return [[WKAPIClient sharedClient] DELETE:[NSString stringWithFormat:@"user/blacklist/%@",self.channelInfo.channel.channelId?:@""] parameters:nil];
}


-(void) initItems {
    __weak typeof(self) weakSelf = self;
    // 手机号 / 邮箱：独立信息卡片，紧跟头部（头像/名字/短号）下方、"设置备注"
    // 这一行之上（对齐设计稿「他人名片」信息卡）。
    // 服务端 2026-09-29 合入 #919 后已经会按关系收敛（本人/好友/双方同处一个
    // 有效 Space 才下发手机号/邮箱，没权限时这两个 key 整体缺失，不是空
    // 字符串）——这里之前写的"服务端不收敛，任意 uid 都原样返回"是基于合并
    // 前的旧行为，已经不对了。客户端这层同 space 门槛（isExternalUser）先
    // 保留，作为独立的一层兜底：和服务端"好友或同 Space"的收敛口径不完全
    // 一致（服务端认好友就放行，不要求同 space），两者是否要对齐留给后续
    // 单独处理。
    // 整张卡片还受部署方管理台总开关控制：WKApp.shared.remoteConfig.
    // profileContactInfoOn，对应服务端 appconfig 的 profile_contact_info_on，
    // 默认关闭。总开关对本人/他人一视同仁——关了谁都看不到这两行。
    // 机器人账号、被禁用账号、已注销/冷静期账号，一律不展示这张卡片（机器人
    // 不区分是否本人，账号状态三项只在 !isSelf 时判——本人账号本身若处于这些
    // 状态理论上登不进来，判了也不影响自己查看自己）。
    // phone/email 从 UserModel 解析开始就不再用 `?: @""` 兜底（见
    // UserModel.fromMap: / self.userPhone/userEmail / paramDict 这三处），
    // nil 和 @"" 的区别一路保留到这里：nil = 服务端没给这个字段（没权限/
    // 取值异常，withheld），@"" = 字段给了但用户确实没填。下面按这两种值
    // 分别处理：
    //   nil        → 这一行完全不展示（不占位，不能让没权限的调用方哪怕
    //                 看到一行空壳）
    //   @""        → 展示"用户暂未添加该信息"占位，不可点
    //   非空字符串 → 原来的点击查看/点击复制逻辑
    // 两行都因为 nil 被跳过时，这张卡片本身也不展示（items.count==0 判断），
    // 不留一条空的分割线。
    // 手机号对他人是"点击查看→点击复制"两段式交互：展开状态存在
    // param[@"context"] 里（即 self.contextDict，per-VM 实例），不能挂在 VM
    // 属性上——同一个 sid 的 handler 在 WKApp 全局 endpoint 表里只有一份，
    // 闭包里的 weakSelf 永远绑定"最后一次 -init 的那个 VM 实例"，多张名片
    // 一起打开时会互相串状态。本人查看自己的手机号不走两段式，直接完整展示，
    // 点击即复制。
    [[WKApp shared] setMethod:@"user.info.phoneEmail" handler:^id _Nullable(id  _Nonnull param) {
        if(![WKApp shared].remoteConfig.profileContactInfoOn) {
            return nil;
        }
        NSString *uid = param[@"uid"];
        BOOL isSelf = [uid isEqualToString:[WKApp shared].loginInfo.uid];
        WKChannelInfo *channelInfo = param[@"channel_info"];
        if(channelInfo.robot) {
            return nil;
        }
        if(!isSelf) {
            // 这三项都从 param 里读（由 tableSectionMaps 用 self 现算好传入），
            // 不读 weakSelf——避免多张名片同时存活时，handler 的 weakSelf 绑定
            // 到"最后一次 -init 的那个 VM 实例"导致门槛判错对象。
            // 用 isExternalForViewer（不是 isExternalUser）：isExternalUser 的
            // 默认值是给 freeFriend/addBlack 那种"外部才展示该行"的场景调的
            // （非 Space 模式下默认 YES=外部，好让那两行默认可见），这里是反过来
            // "外部就隐藏整卡"的场景，极性相反，复用会导致非 Space 模式下卡片
            // 永远不展示。isExternalForViewer 非 Space 模式下默认 NO（非外部），
            // 极性和这里的用法对得上。
            if([param[@"isExternalForViewer"] boolValue]) {
                return nil;
            }
            if([param[@"userAccountStatus"] integerValue] == 0) {
                return nil;
            }
            if([param[@"userIsDestroy"] boolValue]) {
                return nil;
            }
        }
        NSString *phone = param[@"phone"];
        NSString *email = param[@"email"];
        NSMutableDictionary *context = param[@"context"];
        void(^reload)(void) = param[@"reload"];
        NSMutableArray *items = [NSMutableArray array];
        if(phone.length > 0) {
            BOOL phoneRevealed = isSelf || [context[@"phoneRevealed"] boolValue];
            [items addObject:@{
                @"class":WKLabelItemModel.class,
                @"label":LLang(@"手机号"),
                @"value": phoneRevealed ? phone : LLang(@"点击查看"),
                @"showBottomLine": @(email != nil),
                @"onClick":^{
                    if(isSelf || [context[@"phoneRevealed"] boolValue]) {
                        [UIPasteboard generalPasteboard].string = phone;
                        [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"已复制")];
                    } else {
                        context[@"phoneRevealed"] = @(YES);
                        if(reload) {
                            reload();
                        }
                    }
                }
            }];
        } else if(phone != nil) {
            [items addObject:@{
                @"class":WKLabelItemModel.class,
                @"label":LLang(@"手机号"),
                @"value": LLang(@"用户暂未添加该信息"),
                @"showBottomLine": @(email != nil),
            }];
        }
        if(email.length > 0) {
            [items addObject:@{
                @"class":WKLabelItemModel.class,
                @"label":LLang(@"邮箱"),
                @"value": email,
                @"onClick":^{
                    [UIPasteboard generalPasteboard].string = email;
                    [[WKNavigationManager shared].topViewController.view showMsg:LLang(@"已复制")];
                }
            }];
        } else if(email != nil) {
            [items addObject:@{
                @"class":WKLabelItemModel.class,
                @"label":LLang(@"邮箱"),
                @"value": LLang(@"用户暂未添加该信息"),
            }];
        }
        if(items.count == 0) {
            return nil;
        }
        return @{
            @"height":@(10.0f),
            @"items":items,
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:4010];

    // 备注
    [[WKApp shared] setMethod:@"user.info.setRemark" handler:^id _Nullable(id  _Nonnull param) {
        NSString *uid = param[@"uid"];
        if([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
            return nil;
        }
        return  @{
            @"height":@(0.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLangW(@"设置备注",weakSelf),
                        @"onClick":^{
                            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(userInfoVMUpdateRemark:)]) {
                                [weakSelf.delegate userInfoVMUpdateRemark:weakSelf];
                            }
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:4000];
    
    // 邀请信息
    [[WKApp shared] setMethod:@"user.info.inviteInfo" handler:^id _Nullable(id  _Nonnull param) {
        NSString *uid = param[@"uid"];
        if([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
            return nil;
        }
        WKChannelMember *memberOfUser = param[@"memberOfUser"];
        if(!memberOfUser) {
            return nil;
        }
        if(!memberOfUser.extra[@"invite_uid"] || [memberOfUser.extra[@"invite_uid"] isEqualToString:@""]) {
            return nil;
        }
        NSString *createdAt = memberOfUser.createdAt;
        if(createdAt.length>10) {
            createdAt = [createdAt substringToIndex:10];
        }
        WKChannelMember *memberOfInvite = [[WKSDK shared].channelManager getMember:weakSelf.fromChannel uid:memberOfUser.extra[@"invite_uid"]];
        if(!memberOfInvite) {
            return nil;
        }
        return  @{
            @"height":@(0.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLangW(@"进群方式",weakSelf),
                        @"valueFont": [[WKApp shared].config appFontOfSize:12.0f],
                        @"value": [NSString stringWithFormat:@"%@ %@邀请入群",createdAt,memberOfInvite.displayName],
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:3999];
    
    // 个人禁言
    [[WKApp shared] setMethod:@"user.info.forbidden" handler:^id _Nullable(id  _Nonnull param) {
        NSString *uid = param[@"uid"];
        if([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
            return nil;
        }
        WKChannelInfo *channelInfo = param[@"channel_info"];
        if(!channelInfo) {
            return nil;
        }
        if(!weakSelf.fromChannel || weakSelf.fromChannel.channelType == WK_PERSON) {
            return nil;
        }
        WKChannelMember *memberOfUser = weakSelf.memberOfUser;
        if(!memberOfUser) {
            return nil;
        }
        WKChannelMember *memberOfMy = weakSelf.memberOfMy;
        if(!memberOfMy) {
            return nil;
        }
        if(memberOfMy.role != WKMemberRoleManager && memberOfMy.role != WKMemberRoleCreator) {
            return nil;
        }
        NSInteger forbiddenExpirTime = 0; // 禁言失效时间
        if(memberOfUser.extra[@"forbidden_expir_time"]) {
            forbiddenExpirTime = [memberOfUser.extra[@"forbidden_expir_time"] integerValue];
        }
        
        return  @{
            @"height":@(10.0f),
            @"items":@[
                    @{
                        @"class":WKCountdownFormItemModel.class,
                        @"label":LLangW(@"群内禁言", weakSelf),
                        @"value": forbiddenExpirTime>0?LLang(@"禁言中"):@"",
                        @"second":@(forbiddenExpirTime),
                        @"onClick":^{
                            
                            WKChannelMember *member = [[WKSDK shared].channelManager getMember:weakSelf.fromChannel uid:uid];
                            if(member && member.extra[@"forbidden_expir_time"] && [member.extra[@"forbidden_expir_time"] intValue]>0) {
                                WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:nil];
                                [sheet addItem:[WKActionSheetButtonItem2 initWithTitle:LLangW(@"解除禁言", weakSelf) onClick:^{
                                    UIView *topView = [WKNavigationManager shared].topViewController.view;
                                    [topView showHUD];
                                    [[WKAPIClient sharedClient] POST:[NSString stringWithFormat:@"groups/%@/forbidden_with_member",weakSelf.fromChannel.channelId] parameters:@{
                                        @"member_uid":uid,
                                        @"action":@(0)
                                    }].then(^{
                                        [topView hideHud];
                                        [[WKNavigationManager shared] popViewControllerAnimated:YES];
                                    }).catch(^(NSError *error){
                                        [topView hideHud];
                                        [topView showHUDWithHide:error.domain];
                                    });
                                }]];
                                [sheet show];
                                return;
                            }
                            
                            WKForbiddenSpeakTimeSelectVC *vc = [WKForbiddenSpeakTimeSelectVC new];
                            vc.channel = weakSelf.fromChannel;
                            vc.uid = uid;
                            [[WKNavigationManager shared] pushViewController:vc animated:YES];
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:3990];
    
    // 解除好友关系
    [[WKApp shared] setMethod:@"user.info.freeFriend" handler:^id _Nullable(id  _Nonnull param) {
        WKChannelInfo *channelInfo = param[@"channel_info"];
        NSString *uid = param[@"uid"];
        if([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
            return nil;
        }
        // (GH#76)：同 Space 用户资料页整行隐藏「解除好友关系」。
        // 跨 Space 才允许出现此 row。判定失败（缺字段）时按 legacy
        // is_external fallback，保持老数据的旧行为。
        if(![weakSelf isExternalUser]) {
            return nil;
        }
        return  @{
            @"height":@(10.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLangW(@"解除好友关系",weakSelf),
                        @"hidden": channelInfo.follow == WKChannelInfoFollowFriend?@(false):@(true),
                        @"onClick":^{
                            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(userInfoVMFreeFriend:)]) {
                                [weakSelf.delegate userInfoVMFreeFriend:weakSelf];
                            }
                        }
                    },
            ]
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:3000];
    
    // 添加黑名单
    [[WKApp shared] setMethod:@"user.info.addBlack" handler:^id _Nullable(id  _Nonnull param) {
        WKChannelInfo *channelInfo = param[@"channel_info"];
        NSString *uid = param[@"uid"];
        if([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
            return nil;
        }
        // (GH#76)：同 Space 用户资料页整行隐藏「拉入黑名单/拉出
        // 黑名单」。对齐 web PR #977 UserInfo 同 Space 收敛。
        if(![weakSelf isExternalUser]) {
            return nil;
        }
        return  @{
            @"height":@(0.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":channelInfo && channelInfo.status == WKChannelStatusBlacklist?LLangW(@"拉出黑名单", weakSelf):LLangW(@"拉入黑名单", weakSelf),
                        @"onClick":^{
                            if(self.channelInfo.status == WKChannelStatusBlacklist) {
                                if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(userInfoVMRemoveBlacklist:)]) {
                                    [weakSelf.delegate userInfoVMRemoveBlacklist:weakSelf];
                                }
                            }else {
                                if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(userInfoVMAddBlacklist:)]) {
                                    [weakSelf.delegate userInfoVMAddBlacklist:weakSelf];
                                }
                            }
                            
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:2000];
    
    // 投诉
    [[WKApp shared] setMethod:@"user.info.report" handler:^id _Nullable(id  _Nonnull param) {
        NSString *uid = param[@"uid"];
        if([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
            return nil;
        }
        return  @{
            @"height":@(0.0f),
            @"items":@[
                    @{
                        @"class":WKLabelItemModel.class,
                        @"label":LLangW(@"投诉", weakSelf),
                        @"onClick":^{
                            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(userInfoVMReport:)]) {
                                [weakSelf.delegate userInfoVMReport:weakSelf];
                            }
                        }
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:1000];
    
    // 来源 — 群内外部成员显示 home_space_name（viewer-relative）
    // 优先级：群内 memberOfUser.extra 的 viewer-relative 判定 →
    //         个人详情的 channelInfo.extra[@"source_desc"]（旧兼容）
    // 自己查自己 / 同 Space / 没有 sourceSpaceName → 整行隐藏
    [[WKApp shared] setMethod:@"user.info.source" handler:^id _Nullable(id  _Nonnull param) {
        NSString *uid = param[@"uid"];
        if([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
            return nil;
        }
        // 群内路径优先：取 memberOfUser.extra 走 viewer-relative 判定
        WKChannelMember *memberOfUser = param[@"memberOfUser"];
        if(memberOfUser && memberOfUser.extra) {
            NSString *viewerSpaceId = [WKExternalViewerResolver currentViewerSpaceId];
            WKExternalResolveResult *ext = [WKExternalViewerResolver resolveFromExtras:memberOfUser.extra
                                                                         viewerSpaceId:viewerSpaceId];
            if(ext.isExternal && ext.sourceSpaceName.length > 0) {
                return @{
                    @"height":@(10.0f),
                    @"items":@[
                            @{
                                @"class":WKMultiLabelItemModel.class,
                                @"mode": @(WKMultiLabelItemModeLeftRight),
                                @"label":LLang(@"来源"),
                                @"value": ext.sourceSpaceName,
                            },
                    ],
                };
            }
            // 有 home_space_id 可判定但非外部（同 Space）→ 不回落到 source_desc，
            // 行为对齐 web PR #976：同 Space 整行隐藏。
            id homeSpaceIdRaw = memberOfUser.extra[WKExternalExtrasKeyHomeSpaceId];
            if([homeSpaceIdRaw isKindOfClass:[NSString class]] && [(NSString*)homeSpaceIdRaw length] > 0) {
                return nil;
            }
        }
        // 非群上下文降级到旧的 user.source_desc
        WKChannelInfo *channelInfo = param[@"channel_info"];
        if(!channelInfo || (!channelInfo.extra[@"source_desc"] || [channelInfo.extra[@"source_desc"] isEqualToString:@""])) {
            return  nil;
        }
        return  @{
            @"height":@(10.0f),
            @"items":@[
                    @{
                        @"class":WKMultiLabelItemModel.class,
                        @"mode": @(WKMultiLabelItemModeLeftRight),
                        @"label":LLang(@"来源"),
                        @"value":channelInfo.extra[@"source_desc"]?:@"",
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:900];
    
    
    // 功能介绍
    [[WKApp shared] setMethod:self.introEndpointID handler:^id _Nullable(id  _Nonnull param) {
        NSString *uid = param[@"uid"];
        
        NSString *intro;
        if([uid isEqualToString:WKApp.shared.config.fileHelperUID]) {
            intro = LLang(@"登录网页版本，向我发送消息，可以在手机与电脑间传输文字、图片、音频、视频等文件");
        }
        if([uid isEqualToString:WKApp.shared.config.systemUID]) {
            intro = [NSString stringWithFormat:@"%@官方用来发送一些通知的账号",WKApp.shared.config.appName];
        }
        if(!intro) {
            return nil;
        }
        return  @{
            @"height":@(10.0f),
            @"items":@[
                    @{
                        @"class":WKMultiLabelItemModel.class,
                        @"mode": @(WKMultiLabelItemModeLeftRight),
                        @"label":LLang(@"功能介绍"),
                        @"value":intro,
                    },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:900];

    // Bot 简介
    [[WKApp shared] setMethod:@"user.info.botDescription" handler:^id _Nullable(id  _Nonnull param) {
        WKChannelInfo *channelInfo = param[@"channel_info"];
        if (!channelInfo || !channelInfo.robot) {
            return nil;
        }
        NSString *desc = weakSelf.botDescription;
        if (!desc || [desc isEqualToString:@""]) {
            desc = LLang(@"暂无简介");
        }
        return @{
            @"height": @(10.0f),
            @"items": @[
                @{
                    @"class": WKMultiLabelItemModel.class,
                    @"mode": @(WKMultiLabelItemModeLeftRight),
                    @"label": LLang(@"简介"),
                    @"value": desc,
                },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:895];

    // Bot 创建者
    [[WKApp shared] setMethod:@"user.info.botCreator" handler:^id _Nullable(id  _Nonnull param) {
        WKChannelInfo *channelInfo = param[@"channel_info"];
        if (!channelInfo || !channelInfo.robot) {
            return nil;
        }
        NSString *creator = weakSelf.botCreatorName;
        if (!creator || [creator isEqualToString:@""]) {
            return nil;
        }
        return @{
            @"height": @(0.0f),
            @"items": @[
                @{
                    @"class": WKLabelItemModel.class,
                    @"label": LLang(@"创建者"),
                    @"value": creator,
                },
            ],
        };
    } category:WKPOINT_CATEGORY_USER_INFO_ITEM sort:890];
}


- (NSArray<NSDictionary *> *)tableSectionMaps {
    if(!self.channelInfo) {
        return nil;
    }
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *paramDict  = [NSMutableDictionary dictionaryWithDictionary:@{@"uid":self.uid?:@"",@"channel_info":self.channelInfo,@"reload":^{
        [weakSelf reloadData];
    },@"context":self.contextDict}];
    if(self.memberOfUser) {
        paramDict[@"memberOfUser"] = self.memberOfUser;
    }
    // 不用 `?: @""` 兜底：nil 表示服务端没下发（没权限/取值异常），@"" 表示
    // 下发了但用户没填，这个区分要原样带进 paramDict，再传到
    // user.info.phoneEmail handler 里按需分别处理。NSMutableDictionary 的
    // keyed subscript 赋 nil 等价于 removeObjectForKey:，所以这里 nil 不会
    // 崩，paramDict[@"phone"] 读到的就是"key 不存在"。
    paramDict[@"phone"] = self.userPhone;
    paramDict[@"email"] = self.userEmail;
    // isExternalUser/userAccountStatus/userIsDestroy 在这里用 self（不是
    // weakSelf）现算好传进 param，不要让 user.info.phoneEmail handler 里再读
    // weakSelf 取这三个值——handler 挂在 WKApp 全局 endpoint 表里只有一份，
    // weakSelf 绑定的是"最后一次 -init 的那个 VM 实例"，和 phoneRevealed 当年
    // 挂在 VM 属性上是同一类串号风险。tableSectionMaps 本身就是哪个 VM 调用
    // self 就是哪个 VM，这里取值不会认错人。
    paramDict[@"isExternalForViewer"] = @([self isExternalForViewer]);
    paramDict[@"userAccountStatus"] = @(self.userAccountStatus);
    paramDict[@"userIsDestroy"] = @(self.userIsDestroy);

    NSMutableArray<NSDictionary*> *items = [NSMutableArray array];
    
    NSArray<WKEndpoint*> *endpoints =  [WKApp.shared getEndpointsWithCategory:WKPOINT_CATEGORY_USER_INFO_ITEM];
    if(endpoints && endpoints.count>0) {
        for (WKEndpoint *endpoint in endpoints) {
            if([self isSystemAccount:self.uid] && ![endpoint.sid isEqualToString:self.introEndpointID]) {
                continue;
            }
            id result = endpoint.handler(paramDict);
            if(result) {
                [items addObject:result];
            }
        }
    }
    return items;
}

-(BOOL) isSystemAccount:(NSString*)uid {
    return [WKApp.shared isSystemAccount:uid];
}

- (NSMutableDictionary *)contextDict {
    if(!_contextDict) {
        _contextDict = [NSMutableDictionary dictionary];
    }
    return _contextDict;
}

- (BOOL)isBlacklist {
    return  self.channelInfo && self.channelInfo.status == WKChannelStatusBlacklist;
}

// (GH#76): 当前页面的 uid 对观察者是否「外部」。规则对齐
// web `resolveExternalForViewer` / android ExternalViewerResolver：
//   - 有 home_space_id 时权威：home_space_id != viewer_space_id → 外部
//   - 无 home_space_id 时 fallback：legacy is_external == 1 → 外部
//   - viewer_space_id 为空（非 Space 模式）→ 视为外部（保留老行为，
//     不隐藏解除好友 / 拉黑）
-(BOOL) isExternalUser {
    NSString *cur = [WKExternalViewerResolver currentViewerSpaceId];
    if(self.userHomeSpaceId.length > 0 && cur.length > 0) {
        return ![self.userHomeSpaceId isEqualToString:cur];
    }
    // 没有 viewer space（非 Space 模式）→ 保留旧行为（非同 Space 判定）。
    if(cur.length == 0) {
        return YES;
    }
    return self.userIsExternalLegacy == 1;
}

-(void) checkFriendRelation:(NSString*)uid completion:(void(^)(BOOL isFriend))completion {
    [[WKAPIClient sharedClient] GET:@"friend/relation" parameters:@{@"uid":uid?:@""} ].then(^(NSDictionary *result){
        BOOL isFriend = NO;
        if (result[@"is_friend"]) {
            isFriend = [result[@"is_friend"] boolValue];
        } else if (result[@"follow"]) {
            isFriend = [result[@"follow"] integerValue] == 1;
        }
        self.isActualFriend = isFriend;
        if (completion) {
            completion(isFriend);
        }
    }).catch(^(NSError *error){
        WKLogError(@"检查好友关系出错:%@", error);
        // 出错时回退到本地 follow 状态
        self.isActualFriend = self.channelInfo.follow == WKChannelInfoFollowFriend;
        if (completion) {
            completion(self.isActualFriend);
        }
    });
}

-(AnyPromise*) requestUserDetail:(NSString*)uid {
    NSString *groupNo = @"";
    if(self.fromChannel.channelType == WK_GROUP) {
        groupNo = self.fromChannel.channelId;
    }
    return [WKAPIClient.sharedClient GET:[NSString stringWithFormat:@"users/%@",uid] parameters:@{@"group_no":groupNo?:@""} model:UserModel.class];
}

- (WKChannelInfo *)channelInfoFromUser:(UserModel *)user {
    WKChannelInfo *info = [WKChannelInfo new];
    info.channel = [WKChannel personWithChannelID:user.uid];
    info.name = user.name;
    info.remark = user.remark;
    info.logo = user.vercode;  // Assuming 'vercode' is the logo
    info.stick = user.top;
    info.mute = user.mute;
    info.status = user.status;
    info.receipt = user.receipt;
    info.flame = user.flame;
    info.flameSecond = user.flameSecond;
    info.robot = user.robot;
    info.category = user.category;
    info.online = user.online;
    info.deviceFlag = user.deviceFlag;
    info.lastOffline = user.lastOffline;
    info.beDeleted = user.beDeleted;
    info.beBlacklist = user.beBlacklist;
    info.follow = user.follow;
    info.stick = user.top;
    
    info.logo = [NSString stringWithFormat:@"users/%@/avatar",user.uid];
    
    info.extra[@"sex"] = @(user.sex);

    [info setExtraValue:user.shortNo?:@"" forKey:WKChannelExtraKeyShortNo];
    [info setExtraValue:user.sourceDesc?:@"" forKey:WKChannelExtraKeySource];
    [info setExtraValue:user.vercode?:@"" forKey:WKChannelExtraKeyVercode];
    [info setSettingValue:user.screenshot forKey:WKChannelExtraKeyScreenshot];
    [info setSettingValue:user.chatPwdOn forKey:WKChannelExtraKeyChatPwd];
    // / ：把 /users/<uid> 顶层 realname_verified 回写到
    // person 缓存的 extra，保证 WKMessageCell / WKMemberCell / WKUserInfoVC 在
    // member.extra 缺失或 stale 时能 fallback 到 person 拿到正确值。
    info.extra[@"realname_verified"] = @(user.realnameVerified);
    if(user.realnameVerifiedAt > 0) {
        info.extra[@"realname_verified_at"] = @(user.realnameVerifiedAt);
    }
    // Bot 创建者 uid 回写 person 缓存的 extra：撤回菜单据此判定「自己创建的 Bot 消息可
    // 撤回」(对齐 web orgData.bot_creator_uid)。channels/{id}/{type} 接口不下发该字段，
    // 只有 /users/<uid> 顶层有，故必须在这里回写，否则长按 Bot 消息永远拿不到 creator。
    if(user.botCreatorUid.length > 0) {
        info.extra[@"bot_creator_uid"] = user.botCreatorUid;
    }
    return info;
}

#pragma mark - 事件
// 频道数据更新
-(void) channelInfoUpdate:(WKChannelInfo*)channelInfo {
    if(channelInfo.channel.channelType == WK_PERSON && [channelInfo.channel.channelId isEqualToString:self.uid] ) {
        self.channelInfo = channelInfo;
        if(self.completion) {
            self.completion();
        }
    }
}

#pragma mark - external-for-viewer

// : 公共入口。对齐 web `resolveExternalForViewer` (PR #1013/#1091)
// 和 android `ExternalViewerResolver.isExternalForViewer` (PR #135)。
// 优先级：
//   1) 群内路径：memberOfUser.extra 有 home_space_id 时权威
//   2) 个人详情缓存：userHomeSpaceId（loadPersonChannelInfo 回填）
//   3) legacy fallback：memberOfUser.extra / userIsExternalLegacy 的 is_external
// 非 Space 模式（viewerSpaceId 为空）一律视为非外部，避免单 Space 场景误伤。
-(BOOL) isExternalForViewer {
    NSString *viewerSpaceId = [WKExternalViewerResolver currentViewerSpaceId];
    // 非 Space 模式：跨 Space 判定不成立，按 Android `isExternalForViewer`
    // 行为返回 NO（按钮走原有 isFriend / follow 分支）。
    if (viewerSpaceId.length == 0) {
        return NO;
    }

    // 1) 群内路径：优先用 memberOfUser.extra
    if (self.memberOfUser && self.memberOfUser.extra) {
        id homeId = self.memberOfUser.extra[WKExternalExtrasKeyHomeSpaceId];
        if ([homeId isKindOfClass:[NSString class]] && [(NSString*)homeId length] > 0) {
            WKExternalResolveResult *ext = [WKExternalViewerResolver resolveFromExtras:self.memberOfUser.extra
                                                                         viewerSpaceId:viewerSpaceId];
            return ext.isExternal;
        }
    }

    // 2) 个人详情缓存（/users/<uid> 回填）
    if (self.userHomeSpaceId.length > 0) {
        return ![self.userHomeSpaceId isEqualToString:viewerSpaceId];
    }

    // 3) legacy fallback：member.extra 的 is_external，或 /users/<uid> 的 is_external
    if (self.memberOfUser && self.memberOfUser.extra) {
        id legacy = self.memberOfUser.extra[WKExternalExtrasKeyIsExternal];
        if (legacy) {
            WKExternalResolveResult *ext = [WKExternalViewerResolver resolveFromExtras:self.memberOfUser.extra
                                                                         viewerSpaceId:viewerSpaceId];
            return ext.isExternal;
        }
    }
    return self.userIsExternalLegacy == 1;
}

@end


@implementation UserModel

+ (UserModel *)fromMap:(NSDictionary *)dictory type:(ModelMapType)type {
    UserModel *u = [UserModel new];
    u.uid = [dictory objectForKey:@"uid"] ?: @"";
    u.name = [dictory objectForKey:@"name"] ?: @"";
    u.username = [dictory objectForKey:@"username"] ?: @"";
    // email/phone 故意不用 `?: @""` 兜底：服务端这两个字段"key 不存在"
    // (没权限/取值异常，withheld) 和"key 存在但是空串"(用户确实没填)
    // 是两种不同语义，`nil` 和 `@""` 刚好能把这个区分原样保留，一路传到
    // WKUserInfoVM 的 user.info.phoneEmail handler 里按需分别处理。
    u.email = [dictory objectForKey:@"email"];
    u.zone = [dictory objectForKey:@"zone"] ?: @"";
    u.phone = [dictory objectForKey:@"phone"];
    u.mute = [[dictory objectForKey:@"mute"] boolValue];
    u.top = [[dictory objectForKey:@"top"] boolValue];
    u.sex = [[dictory objectForKey:@"sex"] integerValue];
    u.category = [dictory objectForKey:@"category"] ?: @"";
    u.shortNo = [dictory objectForKey:@"short_no"] ?: @"";
    u.chatPwdOn = [[dictory objectForKey:@"chat_pwd_on"] boolValue];
    u.screenshot = [[dictory objectForKey:@"screenshot"] boolValue];
    u.receipt = [[dictory objectForKey:@"receipt"] boolValue];
    u.online = [[dictory objectForKey:@"online"] boolValue];
    u.lastOffline = [[dictory objectForKey:@"last_offline"] integerValue];
    u.deviceFlag = [[dictory objectForKey:@"device_flag"] integerValue];
    u.follow = [[dictory objectForKey:@"follow"] boolValue];
    u.beDeleted = [[dictory objectForKey:@"be_deleted"] boolValue];
    u.beBlacklist = [[dictory objectForKey:@"be_blacklist"] boolValue];
    u.vercode = [dictory objectForKey:@"vercode"] ?: @"";
    u.sourceDesc = [dictory objectForKey:@"source_desc"] ?: @"";
    u.remark = [dictory objectForKey:@"remark"] ?: @"";
    u.isUploadAvatar = [[dictory objectForKey:@"is_upload_avatar"] integerValue];
    u.status = [[dictory objectForKey:@"status"] integerValue];
    u.robot = [[dictory objectForKey:@"robot"] boolValue];
    u.isDestroy = [[dictory objectForKey:@"is_destroy"] boolValue];
    u.flame = [[dictory objectForKey:@"flame"] boolValue];
    u.flameSecond = [[dictory objectForKey:@"flame_second"] integerValue];
    u.botDescription = [dictory objectForKey:@"bot_description"] ?: @"";
    u.botCreatorName = [dictory objectForKey:@"bot_creator_name"] ?: @"";
    u.botCreatorUid = [dictory objectForKey:@"bot_creator_uid"] ?: @"";
    // (GH#76) external-user fields
    u.homeSpaceId = [dictory objectForKey:@"home_space_id"] ?: @"";
    u.isExternal = [[dictory objectForKey:@"is_external"] integerValue];
    // / ：解析顶层实名认证字段（对齐 web orgData.realname_verified）
    u.realnameVerified = [[dictory objectForKey:@"realname_verified"] boolValue];
    u.realnameVerifiedAt = [[dictory objectForKey:@"realname_verified_at"] doubleValue];
    return u;
}

// (GH#76): UserModel 本地判定「相对当前 viewer space 是否外部」。
// 规则与 WKUserInfoVM 上的同名 helper 保持一致，便于以后的调用方（非
// VM 上下文）复用。
-(BOOL) isExternalUser {
    NSString *cur = [WKExternalViewerResolver currentViewerSpaceId];
    if(self.homeSpaceId.length > 0 && cur.length > 0) {
        return ![self.homeSpaceId isEqualToString:cur];
    }
    if(cur.length == 0) {
        return YES;
    }
    return self.isExternal == 1;
}




@end
