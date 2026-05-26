//
//  WKConversationListCell.m
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import "WKConversationListCell.h"
#import "UIView+WK.h"
#import "WKImageView.h"
#import "WKTimeTool.h"
#import "WKBadgeView.h"
#import "WKApp.h"
#import "WKResource.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDImageCache.h>
#import "WKAvatarUtil.h"
#import <DGActivityIndicatorView/DGActivityIndicatorView.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKOnlineBadgeView.h"
#import "WKOfficialTag.h"
#import "WKConstant.h"
#import "WKCheckBox.h"
#import "WuKongBase.h"
#import "WKMessageRevokeCell.h"
#import "WKTypingManager.h"
#import "WKTypingContent.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKUserAvatar.h"
#import "WKAutoDeleteView.h"
#import "WKThreadModel.h"
#import "WKConversationGroupThreadCell.h"
#import "WKConversationListVM.h"
//#define avatarSize 56.0f
@interface WKConversationListCell ()

@property(nonatomic,strong) UILabel *titleLbl; // 名称
@property(nonatomic,strong) WKUserAvatar *avatarImgView; // 头像
@property(nonatomic,strong) UIImageView *statusImgView; // 消息状态image
@property(nonatomic,strong) UILabel *lastContentLbl; // 最后一条消息内容
@property(nonatomic,strong) UILabel *lastMsgTimeLbl; // 最后一条消息时间
@property(nonatomic,strong) DGActivityIndicatorView *typingIndicatorView;

@property(nonatomic,strong) WKBadgeView *badgeView;

@property(nonatomic,strong) WKConversationWrapModel *model;

@property(nonatomic,strong) WKOnlineBadgeView *onlineBadgeView;

@property(nonatomic,strong) UIImageView *muteIcon;

@property(nonatomic,strong) WKOfficialTag *officialTag; // 官方图标

@property(nonatomic,copy) NSString *revokeTip; // 撤回消息tip

@property(nonatomic,strong) UIView *contextContainerView;

@property(nonatomic,strong) WKAutoDeleteView *autoDeleteView; // 自动删除

@property(nonatomic,strong) UILabel *botBadgeLbl; // Bot标识

@property(nonatomic,strong) UILabel *threadCountLbl; // 子区数量提示

@property(nonatomic,strong) UILabel *hashTagLbl; // 群组 # 标识（替代头像）

@property(nonatomic,strong) UIButton *threadToggleBtn; // 子区预览展开按钮

@property(nonatomic,strong) UILabel *externalGroupTagLbl; // 外部群 Tag（仅 WK_GROUP 的 is_external_group==1 会话）

@property(nonatomic,strong) UIImageView *threadAvatarOverlay; // 子区头像右下角的 hash 角标（仅 recentTabContext + 子区行）
@property(nonatomic,strong) UIImageView *threadTitleIcon; // 子区名前的 hash 小图标（仅 recentTabContext + 子区行）
@property(nonatomic,strong) UILabel *threadSourceLbl; // 子区行 title 上方的父群名，仅最近 tab + 子区显示

@property(nonatomic,copy) NSString *lastAvatarChannelId; // 上一次 refreshAvatar 对应的 channelId，用于判断 cell 是否被复用到不同会话
@property(nonatomic,copy) NSString *lastAppliedAvatarURL; // 上一次 applyAvatarURL: 实际下发的 URL —— 复用判定用

@end

/// 静音判定与 WKConversationListVM.isChannelMuted: 同款：channelInfo.mute（SDK 权威源）优先,
/// 缺失时回退 WKConversationWrapModel.mute（即 self.c.mute，DB 快照）。
/// 之前 cell 直接读 model.mute 会被 setConversation: 覆盖成新 conv 默认 NO，导致冷启 / 收新消息时
/// 偶发"已静音会话不显示静音样式"，且与 follow / recent badge 不同源（badge 走 isChannelMuted）。
static BOOL WKCellIsMuted(WKConversationWrapModel *model) {
    if (!model || !model.channel) return NO;
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:model.channel];
    if (info) return info.mute;
    return model.mute;
}

@implementation WKConversationListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        
        self.contextContainerView = [[UIView alloc] init];
        [self.contentView addSubview:self.contextContainerView];
        
        self.titleLbl = [[UILabel alloc] init];
        [self.titleLbl setFont:[[WKApp shared].config appFontOfSizeMedium:17.0f]];
        [self.contextContainerView addSubview:self.titleLbl];
        
        
        self.avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 52.0f, 52.0f)];
        [self.contextContainerView addSubview:self.avatarImgView];
        // 最后一条消息内容
        self.lastContentLbl = [[UILabel alloc] init];
        [self.lastContentLbl setFont:[[WKApp shared].config appFontOfSize:15.0f]];
        [self.lastContentLbl setTextColor:[UIColor colorWithRed:179.0f/255.0f green:179.0f/255.0f blue:179.0f/255.0f alpha:1.0f]];
        self.lastContentLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        self.lastContentLbl.numberOfLines = 1;
        [self.contextContainerView addSubview:self.lastContentLbl];
        // 最后一条消息时间
        self.lastMsgTimeLbl = [[UILabel alloc] init];
        [self.lastMsgTimeLbl setFont:[[WKApp shared].config appFontOfSize:11.0f]];
        [self.lastMsgTimeLbl setTextColor:[UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f]];
        [self.contextContainerView addSubview:self.lastMsgTimeLbl];
        // 红点
        self.badgeView = [WKBadgeView viewWithoutBadgeTip];
        [self.contextContainerView addSubview:self.badgeView];
        // 消息状态
        [self.contextContainerView addSubview:self.statusImgView];
        // 正在输入
        [self.contextContainerView addSubview:self.typingIndicatorView];
        // 在线状态
        [self.contextContainerView addSubview:self.onlineBadgeView];
        // 免打扰图标
        [self.contextContainerView addSubview:self.muteIcon];
        // 官方图标
        [self.contextContainerView addSubview:self.officialTag];
        // 自动删除图标
        [self.contextContainerView addSubview:self.autoDeleteView];
        // Bot标识
        [self.contextContainerView addSubview:self.botBadgeLbl];
        // 子区数量提示
        [self.contextContainerView addSubview:self.threadCountLbl];
        // 群组 # 标识
        [self.contextContainerView addSubview:self.hashTagLbl];
        // 子区展开按钮
        [self.contextContainerView addSubview:self.threadToggleBtn];
        // 外部群 Tag
        [self.contextContainerView addSubview:self.externalGroupTagLbl];

        // 子区头像右下角 hash 角标（最近 tab 子区行专用，默认隐藏）
        self.threadAvatarOverlay = [[UIImageView alloc] init];
        self.threadAvatarOverlay.contentMode = UIViewContentModeScaleAspectFit;
        self.threadAvatarOverlay.hidden = YES;
        self.threadAvatarOverlay.layer.cornerRadius = 11.0f; // size 22 时刚好圆
        self.threadAvatarOverlay.layer.masksToBounds = NO;
        self.threadAvatarOverlay.layer.borderWidth = 1.5f;
        if (@available(iOS 13.0, *)) {
            self.threadAvatarOverlay.backgroundColor = [UIColor systemBackgroundColor];
            self.threadAvatarOverlay.layer.borderColor = [UIColor systemBackgroundColor].CGColor;
        } else {
            self.threadAvatarOverlay.backgroundColor = [UIColor whiteColor];
            self.threadAvatarOverlay.layer.borderColor = [UIColor whiteColor].CGColor;
        }
        [self.contextContainerView addSubview:self.threadAvatarOverlay];

        // 子区名前的 hash 小图标（最近 tab 子区行专用，默认隐藏）
        self.threadTitleIcon = [[UIImageView alloc] init];
        self.threadTitleIcon.contentMode = UIViewContentModeScaleAspectFit;
        self.threadTitleIcon.hidden = YES;
        [self.contextContainerView addSubview:self.threadTitleIcon];

        // 子区行的父群名小标题（最近 tab 专用，关注 tab 隐藏）
        self.threadSourceLbl = [[UILabel alloc] init];
        self.threadSourceLbl.font = [[WKApp shared].config appFontOfSize:11.0f];
        self.threadSourceLbl.textColor = [UIColor colorWithRed:148.0f/255.0f green:152.0f/255.0f blue:168.0f/255.0f alpha:1.0f];
        self.threadSourceLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        self.threadSourceLbl.numberOfLines = 1;
        self.threadSourceLbl.hidden = YES;
        [self.contextContainerView addSubview:self.threadSourceLbl];

    }
    return self;
}

- (UIImageView *)statusImgView {
    if(!_statusImgView) {
        _statusImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 14.0f, 14.0f)];
    }
    return _statusImgView;
}

- (WKOnlineBadgeView *)onlineBadgeView {
    if(!_onlineBadgeView) {
        _onlineBadgeView = [WKOnlineBadgeView initWithTip:nil];
    }
    return _onlineBadgeView;
}

- (WKOfficialTag *)officialTag {
    if(!_officialTag) {
        _officialTag = [WKOfficialTag new];
    }
    return _officialTag;
}

- (UIImageView *)muteIcon {
    if(!_muteIcon) {
        _muteIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 15.0f, 17.0f)];
        [_muteIcon setImage:[self imageName:@"ConversationList/Index/Mute"]];
    }
    return _muteIcon;
}

- (WKAutoDeleteView *)autoDeleteView {
    if(!_autoDeleteView) {
        _autoDeleteView = [[WKAutoDeleteView alloc] init];
    }
    return _autoDeleteView;
}

- (UILabel *)botBadgeLbl {
    if(!_botBadgeLbl) {
        _botBadgeLbl = [[UILabel alloc] init];
        _botBadgeLbl.text = @"AI";
        _botBadgeLbl.font = [[WKApp shared].config appFontOfSize:10.0f];
        _botBadgeLbl.textColor = [UIColor whiteColor];
        _botBadgeLbl.backgroundColor = [UIColor colorWithRed:136.0f/255.0f green:84.0f/255.0f blue:208.0f/255.0f alpha:1.0f];
        _botBadgeLbl.textAlignment = NSTextAlignmentCenter;
        _botBadgeLbl.layer.cornerRadius = 4.0f;
        _botBadgeLbl.layer.masksToBounds = YES;
        _botBadgeLbl.hidden = YES;
    }
    return _botBadgeLbl;
}

- (UILabel *)externalGroupTagLbl {
    if(!_externalGroupTagLbl) {
        _externalGroupTagLbl = [[UILabel alloc] init];
        _externalGroupTagLbl.text = LLang(@"外部");
        _externalGroupTagLbl.font = [[WKApp shared].config appFontOfSize:10.0f];
        _externalGroupTagLbl.textColor = [UIColor whiteColor];
        // 紫色 #722ED1（对齐 dmwork-web PR #980 Semi 紫色 Tag；Android 同色）
        _externalGroupTagLbl.backgroundColor = [UIColor colorWithRed:114.0f/255.0f green:46.0f/255.0f blue:209.0f/255.0f alpha:1.0f];
        _externalGroupTagLbl.textAlignment = NSTextAlignmentCenter;
        _externalGroupTagLbl.layer.cornerRadius = 4.0f;
        _externalGroupTagLbl.layer.masksToBounds = YES;
        _externalGroupTagLbl.hidden = YES;
    }
    return _externalGroupTagLbl;
}

// 外部群判定兜底：优先读 channelInfo.extra[is_external_group]，容忍 NSNumber / NSString。
// 策略 B（客户端兜底，不完全信任后端）：
//   - 硬门控 channelType == WK_GROUP：私聊 / 子区 / 社区不参与判定
//   - NSNull / 非数字 / 缺失 → NO（保持 legacy 行为）
+ (BOOL)shouldShowExternalGroupTag:(WKConversationWrapModel *)model {
    if(!model || !model.channel) {
        return NO;
    }
    if(model.channel.channelType != WK_GROUP) {
        return NO;
    }
    if(!model.channelInfo || !model.channelInfo.extra) {
        return NO;
    }
    id flag = model.channelInfo.extra[@"is_external_group"];
    if(!flag || flag == [NSNull null]) {
        return NO;
    }
    if([flag isKindOfClass:[NSNumber class]] || [flag isKindOfClass:[NSString class]]) {
        return [flag integerValue] == 1;
    }
    return NO;
}



- (void)prepareForReuse {
    [super prepareForReuse];
    // 不再清空 avatar image，让旧头像保留到新头像加载完成后再替换，避免刷新时出现空白/占位图闪烁。
    // 如果 cell 被复用到不同会话，SDWebImage 会在新 URL 加载完成后覆盖旧头像。
    self.hashTagLbl.hidden = YES;
    self.threadToggleBtn.hidden = YES;
    self.onToggleThreadPreview = nil;
    self.avatarImgView.hidden = NO;
    self.lastContentLbl.hidden = NO;
    self.lastMsgTimeLbl.hidden = NO;
    self.externalGroupTagLbl.hidden = YES;
}


-(void) refreshWithModel:(WKConversationWrapModel*)model{
    self.model = model;

    BOOL isGroup = (model.channel.channelType == WK_GROUP);
    // 最近 tab 上下文下群聊也按 DM 风格展示（显示时间/preview/不显示子区角标）。
    // 关注 tab 仍走原 group-summary 风格。
    BOOL renderAsGroupSummary = isGroup && !self.recentTabContext;

    BOOL hasChannelInfo  = model.channelInfo?true:false;
    if(!hasChannelInfo) {
        [model startChannelRequest];
    }

    if(renderAsGroupSummary) {
        // 群聊：显示头像，隐藏预览/时间
        self.hashTagLbl.hidden = YES;
        self.avatarImgView.hidden = NO;
        [self refreshAvatar:model];
        self.lastMsgTimeLbl.hidden = YES;
        self.statusImgView.hidden = YES;
        self.typingIndicatorView.hidden = YES;
        [self.typingIndicatorView stopAnimating];
        self.onlineBadgeView.hidden = YES;
        self.autoDeleteView.hidden = YES;
        // 关注 tab 群行的子区 # 标识：基于关注的子区数，不是全部子区数
        NSInteger followedThreadCount = [WKConversationGroupThreadCell visibleThreadCountFor:model];
        BOOL showToggle = (followedThreadCount > 0 && [WKApp shared].remoteConfig.threadOn);
        self.threadToggleBtn.hidden = !showToggle;
        if (showToggle) {
            NSInteger threadUnread = 0;
            BOOL threadHasMention = NO;
            [[WKConversationListVM shared] getThreadIndicatorForGroup:model.channel.channelId threadUnread:&threadUnread threadHasMention:&threadHasMention];
            NSInteger indicatorType = 0;
            UIColor *indicatorColor = nil;
            if (threadHasMention) {
                indicatorType = 2;
                indicatorColor = [UIColor orangeColor];
            } else if (threadUnread > 0) {
                indicatorType = 1;
                indicatorColor = WKCellIsMuted(model)
                    ? [UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f]
                    : [UIColor redColor];
            }
            UIImage *icon = [WKConversationGroupThreadCell threadToggleIconWithSize:CGSizeMake(28, 28)
                                                                         baseColor:[WKApp shared].config.themeColor
                                                                     indicatorType:indicatorType
                                                                    indicatorColor:indicatorColor];
            [self.threadToggleBtn setImage:icon forState:UIControlStateNormal];
        }

        // 检查是否有 @我 的提醒
        BOOL hasMention = NO;
        if (model.simpleReminders && model.simpleReminders.count > 0) {
            for (WKReminder *r in model.simpleReminders) {
                if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
            }
        }
        if (hasMention) {
            self.lastContentLbl.hidden = NO;
            self.lastContentLbl.attributedText = [self getLastContent:model];
            self.lastContentLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        } else {
            self.lastContentLbl.hidden = YES;
        }
    } else {
        // 私聊：正常显示
        self.hashTagLbl.hidden = YES;
        self.avatarImgView.hidden = NO;
        self.threadToggleBtn.hidden = YES;
        self.lastContentLbl.hidden = NO;
        self.lastMsgTimeLbl.hidden = NO;
        [self refreshAvatar:model];
        // 最后一次消息时间。timestamp == 0 表示当前空间无可显示的最近消息（system bot 跨空间过滤后），
        // 直接清空时间标签，避免 WKTimeTool 把 0 渲染成 "1970..."。
        if(model.lastMsgTimestamp <= 0) {
            self.lastMsgTimeLbl.text = @"";
        } else {
            self.lastMsgTimeLbl.text = [WKTimeTool getTimeStringAutoShort2:[NSDate dateWithTimeIntervalSince1970:model.lastMsgTimestamp] mustIncludeTime:true];
        }
        // 刷新在线状态
        [self refreshOnlineStatus:model];
        // 刷新最后一条消息
        [self refreshLastMessage:model];
        // 刷新输入中
        [self refreshTyping:model];
        // 刷新消息状态
        [self refreshStatus:model];
        // 自动删除
        [self refreshAutoDeleteIfNeed:model];
    }

    // 刷新标题
    [self refreshTitle:model];

    // 子区行的"来源:父群名"小标题（仅最近 tab 显示）
    [self refreshThreadSource:model];

    // 刷新未读数
    [self refreshUnread:model];

    // 刷新设置
    [self refreshSetting:model];

    // 刷新官方tag
    [self refreshOfficialTag:model];

    // 刷新外部群 Tag（仅 WK_GROUP 显示，私聊 / 子区 / 社区自动跳过）
    [self refreshExternalGroupTag:model];

    [self layoutSubviews];
}

-(void) refreshAutoDeleteIfNeed:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    if(!hasChannelInfo) {
        self.autoDeleteView.hidden = YES;
        return;
    }
    NSInteger msgAutoDelete = 0;
    if(model.channelInfo.extra[@"msg_auto_delete"]) {
        msgAutoDelete = [model.channelInfo.extra[@"msg_auto_delete"] integerValue];
    }
    if(msgAutoDelete>0) {
        self.autoDeleteView.hidden = NO;
        self.autoDeleteView.second = msgAutoDelete;
        if(model.channelInfo.online) {
            self.autoDeleteView.hidden = YES;
        }else {
            self.onlineBadgeView.hidden  = YES;
        }
    }else{
        self.autoDeleteView.hidden = YES;
    }
    
 
    
}

-(NSString*) formatSecond:(NSInteger)second {
    if(second < 60 * 60 * 24) {
        return @"";
    }
    NSInteger day = second / (60 * 60 * 24);
    NSInteger week = day / 7;
    NSInteger month = day / 30;
    NSInteger year = month / 12;
    
    if(year>0) {
        return [NSString stringWithFormat:@"%ldy",(long)year];
    }
    if(month>0) {
        return [NSString stringWithFormat:@"%ldm",(long)month];
    }
    if(week>0) {
        return [NSString stringWithFormat:@"%ldw",(long)week];
    }
    if(day>0) {
        return [NSString stringWithFormat:@"%ldd",(long)day];
    }
    return @"";
}

-(void) refreshTitle:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    
    [self.titleLbl setTextColor:[WKApp shared].config.defaultTextColor];
    
    
    if(!hasChannelInfo) {
        // 如果没有频道信息触发频道信息获取
//        [[[WKSDK shared] channelManager] fetchChannelInfo:model.channel];
        if(model.channel.channelType == WK_PERSON) {
             self.titleLbl.text = LLang(@"无");
        }else if(model.channel.channelType == WK_GROUP){
            self.titleLbl.text = LLang(@"群聊");
        }else if(model.channel.channelType == WK_Community) {
            self.titleLbl.text = LLang(@"社区");
        }else {
            self.titleLbl.text = LLang(@"聊天");
        }
    }else {
        self.titleLbl.text = model.channelInfo.displayName;
        if(model.channel.channelType == WK_PERSON) {
            if([model.channel.channelId isEqualToString:[WKApp shared].config.systemUID]) {
                self.titleLbl.text = LLang(@"系统通知");
                if(model.channelInfo.remark && ![model.channelInfo.remark isEqualToString:@""]) {
                    self.titleLbl.text = model.channelInfo.remark;
                }
            }else if([model.channel.channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
                self.titleLbl.text = LLang(@"文件传输助手");
                if(model.channelInfo.remark && ![model.channelInfo.remark isEqualToString:@""]) {
                    self.titleLbl.text = model.channelInfo.remark;
                }
            }
        }
        
    }
    
    if(!self.titleLbl.text || [self.titleLbl.text isEqualToString:@""]) {
        self.titleLbl.text = LLang(@"无");
    }

    // Bot标识
    BOOL isBot = hasChannelInfo && model.channelInfo.robot;
    self.botBadgeLbl.hidden = !isBot;
    if(isBot) {
        [self.botBadgeLbl sizeToFit];
        CGRect frame = self.botBadgeLbl.frame;
        frame.size.width += 8.0f;
        frame.size.height += 4.0f;
        self.botBadgeLbl.frame = frame;
    }

    // 子区数量提示已统一由 threadToggleBtn 展示，不再内联显示
    self.threadCountLbl.hidden = YES;
}

-(void) refreshAvatar:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    UIImage *placeholder = [self imageName:@"Common/Index/DefaultAvatar"];
    NSString *channelId = model.channel.channelId;
    // 复用判定：先记下上次的 channelId（applyAvatarURL: 需要靠它区分"同会话刷新（cacheKey
    // 变了 / 进聊天页回来）" vs "cell 被复用到不同会话"。本方法尾部再覆盖。
    NSString *prevChannelId = self.lastAvatarChannelId;

    // 最近 tab 的子区行：右下角 hash 角标（参考 web）。头像本身不再 override —
    // 服务端在子区 channelInfo.logo 里通常已经填了父群头像 URL，原有 hasChannelInfo
    // 分支能正确加载；之前手动查父群结果父群没缓存就回退占位图，反而把原本能显示
    // 的群头像盖掉。这里只负责显示 overlay，URL 加载交给下面的通用逻辑。
    BOOL isThreadInRecent = self.recentTabContext
                          && model.channel.channelType == WK_COMMUNITY_TOPIC;
    if (isThreadInRecent) {
        UIImage *hashIcon = [WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(18, 18)
                                                                              color:[WKApp shared].config.themeColor];
        self.threadAvatarOverlay.image = hashIcon;
        self.threadAvatarOverlay.hidden = NO;

        UIImage *titleHashIcon = [WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(14, 14)
                                                                                  color:[UIColor colorWithRed:148.0f/255.0f green:152.0f/255.0f blue:168.0f/255.0f alpha:1.0f]];
        self.threadTitleIcon.image = titleHashIcon;
        self.threadTitleIcon.hidden = NO;
    } else {
        self.threadAvatarOverlay.hidden = YES;
        self.threadTitleIcon.hidden = YES;
    }

    if([model.channel.channelId isEqualToString:[WKApp shared].config.systemUID]) {
        NSString *avatarURL = hasChannelInfo ? [WKAvatarUtil getFullAvatarWIthPath:model.channelInfo.logo] : nil;
#if DEBUG
        NSLog(@"[DEBUG] 系统通知(u_10000) logo: %@, avatarURL: %@, hasChannelInfo: %d", model.channelInfo.logo, avatarURL, hasChannelInfo);
#endif
    }
    if(hasChannelInfo) {
        NSString *avatarURL;
        if(model.channel.channelType == WK_GROUP) {
            // 群频道：始终拼接 ?v=cacheKey，避免命中旧的无参数 URL 缓存
            if([model.channelInfo.logo hasPrefix:@"http"]) {
                NSString *key = (model.channelInfo.avatarCacheKey.length > 0) ? model.channelInfo.avatarCacheKey : @"0";
                NSString *separator = [model.channelInfo.logo containsString:@"?"] ? @"&" : @"?";
                avatarURL = [NSString stringWithFormat:@"%@%@v=%@", model.channelInfo.logo, separator, key];
            } else {
                avatarURL = [WKAvatarUtil getGroupAvatar:model.channel.channelId cacheKey:model.channelInfo.avatarCacheKey];
            }
        } else if (self.recentTabContext && model.channel.channelType == WK_COMMUNITY_TOPIC) {
            // 最近 tab 的子区：直接用父群的头像 URL（getGroupAvatar 不要求 channelInfo
            // 在手，仅 groupNo 就能拼）。比依赖 thread.channelInfo.logo 的服务端填充
            // 更稳；overlay 单独叠在右下角即可。
            WKChannel *parent = [self resolveParentGroupChannelForThread:model];
            NSString *groupNo = parent.channelId ?: @"";
            WKChannelInfo *parentInfo = [self lookupParentChannelInfo:parent];
            avatarURL = [WKAvatarUtil getGroupAvatar:groupNo cacheKey:parentInfo.avatarCacheKey];
#if DEBUG
            NSLog(@"[ThreadAvatar] thread=%@ parent=%@ parentInfoCached=%d avatarURL=%@",
                  model.channel.channelId, groupNo, parentInfo != nil, avatarURL);
#endif
        } else {
            // 个人频道：和群频道一样，始终拼接 ?v=cacheKey
            NSString *key = (model.channelInfo.avatarCacheKey.length > 0) ? model.channelInfo.avatarCacheKey : @"0";
            if([model.channelInfo.logo hasPrefix:@"http"]) {
                NSString *separator = [model.channelInfo.logo containsString:@"?"] ? @"&" : @"?";
                avatarURL = [NSString stringWithFormat:@"%@%@v=%@", model.channelInfo.logo, separator, key];
            } else if(model.channelInfo.logo && ![model.channelInfo.logo isEqualToString:@""]) {
                NSString *fullUrl = [WKAvatarUtil getFullAvatarWIthPath:model.channelInfo.logo];
                avatarURL = [NSString stringWithFormat:@"%@?v=%@", fullUrl, key];
            } else {
                avatarURL = [WKAvatarUtil getAvatar:model.channel.channelId cacheKey:model.channelInfo.avatarCacheKey];
            }
        }
        // 用 helper 替换原 lim_setImageWithURL：先同步查 SDImageCache memory cache,
        // 命中直接 set 真实头像（"动态 placeholder"），miss 时按"同 URL/同 channel 保留，
        // 复用到异会话清掉"决策，彻底消除子区返回会话列表时的默认头像闪 / 进聊天详情
        // 返回时本会话头像短暂空白。
        [self applyAvatarURL:avatarURL placeholder:placeholder
               prevChannelId:prevChannelId currChannelId:channelId];
    } else {
        if (self.recentTabContext && model.channel.channelType == WK_COMMUNITY_TOPIC) {
            // 子区 channelInfo 还没加载到时，仍然用父群 URL 拼一发 — getGroupAvatar
            // 不依赖 channelInfo，能命中父群头像缓存。
            WKChannel *parent = [self resolveParentGroupChannelForThread:model];
            NSString *groupNo = parent.channelId ?: @"";
            if (groupNo.length > 0) {
                // 与 hasChannelInfo=YES 分支同款用 parentInfo.avatarCacheKey 拼 URL，让两条路径
                // 生成的 URL 完全一致 → SDWebImage memory cache 命中率最大化，避免子区 cell 复用时
                // 因 URL 不同 (cacheKey=nil vs cacheKey=hash) 触发重新下载。
                WKChannelInfo *parentInfo = [self lookupParentChannelInfo:parent];
                NSString *avatarURL = [WKAvatarUtil getGroupAvatar:groupNo cacheKey:parentInfo.avatarCacheKey];
#if DEBUG
                NSLog(@"[ThreadAvatar][noChannelInfo] thread=%@ parent=%@ parentInfoCached=%d avatarURL=%@",
                      model.channel.channelId, groupNo, parentInfo != nil, avatarURL);
#endif
                [self applyAvatarURL:avatarURL placeholder:placeholder
                       prevChannelId:prevChannelId currChannelId:channelId];
            } else {
                self.avatarImgView.avatarImgView.image = placeholder;
            }
        } else {
            self.avatarImgView.avatarImgView.image = placeholder;
        }
    }
    // 在尾部统一更新，prevChannelId 已在方法开头取走 → 复用判定不会自比对
    self.lastAvatarChannelId = channelId;
}

/// avatar 加载统一入口：先同步查 SDImageCache memory cache，命中直接用真实头像作为
/// "动态 placeholder"，避免子区头像在 cell 复用 / 返回会话列表时短暂显示默认占位图。
///
/// 私聊 / 群头像之前不闪是因为 memory cache 命中率高（DM 总数少，群 cache 常驻），
/// SDWebImage 异步加载前就同步 set 真实图。子区头像走父群 URL，memory cache 驱逐快、
/// cell pool 重组后 fresh instance image=nil → SDWebImage 默认行为先显示 placeholder
/// 再异步加载，用户看到默认头像闪一下。
///
/// 这里手动同步查 memory cache 复制 SDWebImage 内部行为：命中就用 cached 真实图替代
/// 默认 placeholder。lim_setImageWithURL 的 SDWebImageDelayPlaceholder 配合：cache miss
/// 不立即覆盖现有 image (保留复用残留 / 兜底 placeholder)，等异步加载完替换。
- (void)applyAvatarURL:(NSString *)avatarURL
           placeholder:(UIImage *)placeholder
       prevChannelId:(NSString *)prevChannelId
        currChannelId:(NSString *)currChannelId {
    UIImage *cached = avatarURL.length > 0 ? [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:avatarURL] : nil;
    // 「去 query 的 base URL」兜底：SDK addOrUpdateMembers 会调 refreshAvatarCacheKey
    // 让 avatarCacheKey 每次 fetch 都换 UUID（URL 里 ?v= 抖动），SDImageCache 按完整 URL
    // 做 key 必 miss。我们在每次成功 load 后用 base URL 当 stable key 多存一份，下次
    // miss 时拿来当占位 → 同一张图，无视觉变化。
    NSString *stableKey = [self.class _stableImageKeyForURL:avatarURL];
    UIImage *stableFallback = (cached == nil && stableKey.length > 0)
                                ? [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:stableKey]
                                : nil;
    // 复用判定：现有 image 是否能作为本次加载的"动态占位"
    //   - 同 URL：肯定能（同一张图，加载完就是它本身）
    //   - 同 channelId：同一会话，URL 变了只可能是 cacheKey bump，头像主体仍是本会话的
    //   - 都不同：cell 被复用到别的会话，旧 image 是别群/别人的 → 必须清掉
    BOOL sameURL = (self.lastAppliedAvatarURL.length > 0
                    && [self.lastAppliedAvatarURL isEqualToString:avatarURL ?: @""]);
    BOOL sameChannel = (prevChannelId.length > 0
                        && currChannelId.length > 0
                        && [prevChannelId isEqualToString:currChannelId]);
    BOOL safeToKeepImage = sameURL || sameChannel;
#if DEBUG
    BOOL hadImage = (self.avatarImgView.avatarImgView.image != nil);
    NSLog(@"[AvatarDbg][ListCell] ch=%@ prev=%@ url=%@ prevUrl=%@ sameURL=%d sameChannel=%d cacheHit=%d stableHit=%d hadImage=%d → %@",
          currChannelId, prevChannelId,
          avatarURL ?: @"<nil>", self.lastAppliedAvatarURL ?: @"<nil>",
          sameURL, sameChannel, cached != nil, stableFallback != nil, hadImage,
          cached ? @"USE_CACHED" : (stableFallback ? @"USE_STABLE" : (safeToKeepImage ? @"KEEP_OLD" : @"CLEAR")));
#endif
    if (cached) {
        // memory cache 命中：直接显示真实头像
        self.avatarImgView.avatarImgView.image = cached;
    } else if (stableFallback) {
        // 完整 URL miss 但 base URL stable key 命中：用上次的同一张图当**视觉占位**，
        // 等 SDWebImage 异步加载新 URL（极大概率拿到同款图）→ 无视觉变化。
        //
        // 不要把 stableFallback 反向喂给 SDImageCache 的「新 URL key」—— 那会让 SDWebImage
        // 把后续 sd_setImage 当 cache 命中直接 short-circuit，导致 avatarCacheKey 失效，
        // 群头像 / 用户头像被上传后（path 不变，只 bump cacheKey）永远不会刷新。
        self.avatarImgView.avatarImgView.image = stableFallback;
    } else if (!safeToKeepImage) {
        // cache 全 miss + cell 被复用到别的会话：清掉残留并立即 set 默认 placeholder。
        // 不能直接 image=nil —— SDWebImageDelayPlaceholder 下 SDWebImage 不会主动 set
        // placeholder，会让 imageView 在 async load 完成前一直空白。与两个 ThreadCell
        // 同款（GroupThreadCell.refreshAvatar / GroupThreadOnlyCell.refreshAvatar）。
        self.avatarImgView.avatarImgView.image = placeholder;
    }
    // safeToKeepImage：保留旧 image，等异步加载完替换
    self.lastAppliedAvatarURL = avatarURL ?: @"";
    NSString *stableKeyForCompletion = stableKey;
    [self.avatarImgView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:avatarURL ?: @""]
                                         placeholderImage:placeholder
                                                  options:SDWebImageDelayPlaceholder
                                                  context:@{SDWebImageContextStoreCacheType: @(SDImageCacheTypeAll)}
                                                completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        if (image && stableKeyForCompletion.length > 0) {
            // 复制一份到 stable key —— 下次 URL 抖动时兜底
            [[SDImageCache sharedImageCache] storeImageToMemory:image forKey:stableKeyForCompletion];
        }
    }];
}

/// 把头像 URL 的 query string 去掉（`?v=xxx`），作为 SDImageCache 的稳定 key。
/// 同一会话不同 cacheKey 抖动时映射到同一 key → 下次 miss 也能用同一张图兜底。
+ (NSString *)_stableImageKeyForURL:(NSString *)url {
    if (url.length == 0) return nil;
    NSRange r = [url rangeOfString:@"?"];
    if (r.location == NSNotFound) return url;
    return [url substringToIndex:r.location];
}

-(void) refreshOnlineStatus:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    // 在线状态
    self.onlineBadgeView.hidden = YES;
    if(model.channel.channelType == WK_PERSON) {
        if(hasChannelInfo) {
            if(model.channelInfo.online) {
                self.onlineBadgeView.hidden = NO;
                self.onlineBadgeView.tip = nil;
            }else if ([[NSDate date] timeIntervalSince1970] - model.channelInfo.lastOffline<60) {
                self.onlineBadgeView.hidden = NO;
                           self.onlineBadgeView.tip = LLang(@"刚刚");
            }else if( model.channelInfo.lastOffline+60*60>[[NSDate date] timeIntervalSince1970]) {
                self.onlineBadgeView.hidden = NO;
                self.onlineBadgeView.tip =[NSString stringWithFormat:LLang(@"%0.0f分钟"),([[NSDate date] timeIntervalSince1970]-model.channelInfo.lastOffline)/60];
            }
        }
    }
}

-(void) refreshLastMessage:(WKConversationWrapModel*)model {
    // 使用空间过滤后的消息做展示判断（解决BotFather跨空间预览消息问题）
    WKMessage *displayMsg = [model spaceFilteredLastMessage];
    if(displayMsg) {
        if(displayMsg.remoteExtra.revoke) {
            self.lastContentLbl.text = self.revokeTip;
        }else if(displayMsg.contentType == WK_UNKNOWN) {
            self.lastContentLbl.text = [WKApp shared].config.unkownMessageText;
        }else {
            self.lastContentLbl.attributedText =[self getLastContent:model];
            self.lastContentLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        }
    }else  {
        self.lastContentLbl.text = @"";
    }
}

-(void) refreshTyping:(WKConversationWrapModel*)model {
    // 输入中
    self.typingIndicatorView.hidden = YES;
    [self.typingIndicatorView stopAnimating];
    WKMessage *typingMessage =  [[WKTypingManager shared] getTypingMessage:model.channel];
    if(typingMessage) {
        self.typingIndicatorView.hidden = YES;
         [self.typingIndicatorView startAnimating];
        if(model.channel.channelType == WK_PERSON) {
            self.lastContentLbl.text =LLang(@"正在输入");
        }else {
            WKTypingContent *typingContent = (WKTypingContent*)typingMessage.content;
            NSString *typingName = typingContent.typingName;
            if(typingContent.typingUID) {
              WKChannelInfo *typingChannelInfo =  [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:typingContent.typingUID]];
                if(typingChannelInfo) {
                    typingName = typingChannelInfo.displayName;
                }
            }
            
            self.lastContentLbl.text = [NSString stringWithFormat:LLang(@"%@ 正在输入"),typingName];
        }
    }
}

-(void) refreshUnread:(WKConversationWrapModel*)model {
    // 未读数
    self.badgeView.hidden = YES;
    if(model.unreadCount>0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = self.model.unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld",(long)self.model.unreadCount];
        self.badgeView.lim_left = self.lim_width - 15.0f - self.badgeView.lim_width; // 这里强行执行下lim_left 因为杀掉app收离线，从无红点到有红点会向左漂移，因为layoutSubviews后执行
    }
}

-(void) refreshSetting:(WKConversationWrapModel*)model {
    // 免打扰
    BOOL muted = WKCellIsMuted(model);
    if(muted) { // 免打扰
        if(model.unreadCount<=0) {
            self.muteIcon.hidden = NO;
        }else {
            self.muteIcon.hidden = YES;
        }

        [self.badgeView setBadgeBackgroundColor:[UIColor colorWithRed:163.0f/255.0f green:214.0/255.0f blue:237.0f/255.0f alpha:1.0]];
    }else {
        self.muteIcon.hidden = YES;
        [self.badgeView setBadgeBackgroundColor:[UIColor redColor]];
    }
    
    // 置顶 — 跨 tab 独立：仅最近 tab 显示置顶背景色。关注 tab 即便 model.stick=YES
    // 也保持普通背景（spec §0：关注 tab 不显示置顶概念）
    if(model.stick && self.recentTabContext) {
        [self setBackgroundColor:[WKApp shared].config.backgroundColor];
    }else {
        [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
    
}

-(void) refreshStatus:(WKConversationWrapModel*)model {
    // 消息状态
    self.statusImgView.hidden = YES;
    if(self.model.lastMessage && self.model.lastMessage.isSend) {
        self.statusImgView.hidden = NO;
        [self updateStatus];
    }
}

-(void) refreshOfficialTag:(WKConversationWrapModel*)model {
    BOOL hasChannelInfo  = model.channelInfo?true:false;
    // 官方图标
    self.officialTag.hidden = YES;

    NSString *category = hasChannelInfo ? model.channelInfo.category : nil;
    // 系统通知直接判断为官方
    if ([model.channel.channelId isEqualToString:[WKApp shared].config.systemUID]) {
        category = WKChannelCategoryService;
    }

    if(category && ![category isEqualToString:@""]) {
        if([category isEqualToString:WKChannelCategoryService]) {
            self.officialTag.frame = CGRectMake(0.0f, 0.0f, 18.0f, 18.0f);
            self.officialTag.hidden = NO;
            self.officialTag.image = [self imageName:@"ConversationList/Index/Official"];
        }else if([category isEqualToString:WKChannelCategoryVisitor]) {
            self.officialTag.frame = CGRectMake(0.0f, 0.0f, 35.0f, 18.0f);
            self.officialTag.hidden = NO;
            self.officialTag.image = [self imageName:@"ConversationList/Index/Visitor"];
        }
    }
}

-(void) refreshExternalGroupTag:(WKConversationWrapModel*)model {
    // 每次 bind 重新评估（Space 切换 / channelInfo 推送后会触发 refreshWithModel，继而走这里），
    // 不需要额外监听。字段走 model.channelInfo.extra[is_external_group]，
    // 由 WKGroupManagerDelegateImp 从 /groups/{no} 响应自动透传（EP1 依赖，已就位）。
    BOOL show = [WKConversationListCell shouldShowExternalGroupTag:model];
    self.externalGroupTagLbl.hidden = !show;
    if(show) {
        [self.externalGroupTagLbl sizeToFit];
        CGRect frame = self.externalGroupTagLbl.frame;
        frame.size.width += 8.0f;
        frame.size.height += 4.0f;
        self.externalGroupTagLbl.frame = frame;
    }
}


-(void) updateStatus {
    if(!self.model.lastMessage || !self.model.lastMessage.isSend) {
        self.statusImgView.image = nil;
        return;
    }
//    [self.statusImgView setBackgroundColor:[UIColor redColor]];
    WKMessage *message = self.model.lastMessage;
    if([self needLoading:message]) {
        self.statusImgView.image = [self imageName:@"ConversationList/Index/TimeWait"];
        self.statusImgView.image = [self.statusImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.statusImgView.tintColor =  [WKApp shared].config.tipColor;
    }else if(message.status == WK_MESSAGE_SUCCESS) {
        if(message.remoteExtra.readedCount>0) {
            self.statusImgView.image = [self imageName:@"ConversationList/Index/DoubleCheckmark"];
            self.statusImgView.image = [self.statusImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }else{
            self.statusImgView.image = [self imageName:@"ConversationList/Index/Checkmark"];
            self.statusImgView.image = [self.statusImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        self.statusImgView.tintColor =  [WKApp shared].config.themeColor;
    }else if(message.status == WK_MESSAGE_FAIL) {
        self.statusImgView.image = [self imageName:@"ConversationList/Index/SendError"];
        self.statusImgView.image = [self.statusImgView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.statusImgView.tintColor =  [UIColor redColor];
    }
}
-(BOOL) needLoading:(WKMessage*)message {
    if((message.status == WK_MESSAGE_WAITSEND || message.status == WK_MESSAGE_UPLOADING) && message.isSend) {
        return true;
    }
    return false;
}

- (NSString *)revokeTip {
    if(!self.model.lastMessage) {
        return @"";
    }
    return [WKMessageRevokeCell tip:self.model.lastMessage];
}


- (DGActivityIndicatorView *)typingIndicatorView {
    if(!_typingIndicatorView) {
        _typingIndicatorView = [[DGActivityIndicatorView alloc] initWithType:DGActivityIndicatorAnimationTypeThreeDots tintColor:[UIColor grayColor] size:20.0f];
        [_typingIndicatorView setFrame:CGRectMake(0.0f, 0.0f, 30.0f, 15.0f)];
    }
    return _typingIndicatorView;
}

-(NSMutableAttributedString*) getLastContent:(WKConversationWrapModel*)model{
    
    // 聊天密码
    BOOL chatPwdOn = model.channelInfo && [model.channelInfo settingForKey:WKChannelExtraKeyChatPwd defaultValue:false];
    if(chatPwdOn) {
        return  [[NSMutableAttributedString alloc] initWithString:@"* * * * * *"];
    }
    
    BOOL hasDraft = false;
    if(model.remoteExtra.draft && ![model.remoteExtra.draft isEqualToString:@""]) {
        hasDraft = true;
        // DM 频道草稿按空间隔离：只在保存时的空间显示
        NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
        if(currentSpaceId.length > 0 && model.channel.channelType == WK_PERSON) {
            NSString *draftKey = [NSString stringWithFormat:@"WKDraftSpaceId_%@_%d", model.channel.channelId, model.channel.channelType];
            NSString *draftSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:draftKey];
            if(draftSpaceId && ![draftSpaceId isEqualToString:currentSpaceId]) {
                hasDraft = false; // 草稿属于其他空间，不显示
            }
        }
    }
    
    NSMutableString *reminderStr  = [[NSMutableString alloc] init];
    if(model.simpleReminders && model.simpleReminders.count>0) {
        for (WKReminder *reminder in model.simpleReminders) {
            [reminderStr appendString:reminder.text];
        }
    }
    NSString *fullContentStr;
    NSString *content =model.content;
    if(hasDraft) {
        content = model.remoteExtra.draft;
        [reminderStr insertString:LLang(@"[草稿]") atIndex:0];
    }
    
    if(model.channel.channelType == WK_GROUP) { // 群组
        if([self showFromName:model] && !hasDraft) {
            NSString *name = [self getFromName];
            fullContentStr = [NSString stringWithFormat:@"%@%@: %@",reminderStr,name,content];
        }else {
            fullContentStr = [NSString stringWithFormat:@"%@%@",reminderStr,content];
        }

    }else { // 单聊
        fullContentStr = [NSString stringWithFormat:@"%@%@",reminderStr,content];
    }
    NSMutableAttributedString *contentAttrStr = [[NSMutableAttributedString alloc] init];
    WKRichTextParseOptions *options = [WKRichTextParseOptions new];
    options.disableLink = true;
    [contentAttrStr lim_parse:fullContentStr mentionInfo:nil options:options];
    if(reminderStr.length>0) {
        [contentAttrStr addAttribute:NSForegroundColorAttributeName value:[UIColor orangeColor] range:[fullContentStr rangeOfString:reminderStr]];
    }
    return contentAttrStr;
}

#pragma mark - Thread (recent tab) helpers

/// 解析子区的父群 channel。**始终用 channelId 的 "____" 切分**，不信
/// model.parentChannel —— iOS SDK 实测会把 parentChannel 填成 thread 自己
/// （日志里 parent == thread）。groupNo 取自 channelId 是 iOS 整个代码库的通行做法
/// （见 WKConversationListVC.m:1965、WKLocalNotificationManager.m 等多处）。
- (WKChannel *)resolveParentGroupChannelForThread:(WKConversationWrapModel *)model {
    if (model.channel.channelType != WK_COMMUNITY_TOPIC) return nil;
    NSString *cid = model.channel.channelId;
    NSRange sep = [cid rangeOfString:@"____"];
    if (sep.location == NSNotFound) return nil;
    NSString *groupNo = [cid substringToIndex:sep.location];
    if (groupNo.length == 0) return nil;
    return [WKChannel channelID:groupNo channelType:WK_GROUP];
}

/// 子区行 title 上方的"来源:父群名"小标题；仅 recentTabContext + 子区 显示。
/// 没缓存到父群 channelInfo 时触发 fetch，本帧暂回退到 channelId 的 groupNo 文本兜底。
- (void)refreshThreadSource:(WKConversationWrapModel *)model {
    BOOL shouldShow = self.recentTabContext && model.channel.channelType == WK_COMMUNITY_TOPIC;
    if (!shouldShow) {
        self.threadSourceLbl.hidden = YES;
        self.threadSourceLbl.text = nil;
        return;
    }
    WKChannel *parent = [self resolveParentGroupChannelForThread:model];
    NSString *parentName = nil;
    if (parent) {
        WKChannelInfo *parentInfo = [self lookupParentChannelInfo:parent];
        parentName = parentInfo.displayName;
    }
    if (parentName.length == 0) {
        // 名称暂不可用：本帧不显示 source 行（避免出现"来源:groupNo乱码"）。
        // 等 channelInfoUpdate 回调时 VC 会 reload 该行，下次 refresh 取得 displayName。
        self.threadSourceLbl.hidden = YES;
        self.threadSourceLbl.text = nil;
        return;
    }
    self.threadSourceLbl.text = parentName;
    self.threadSourceLbl.hidden = NO;
}

/// 父群 channelInfo 三级查找：VM wrap.channelInfo（走 c.channelInfo 反向引用 + lazy load）
/// → channelManager 内存缓存 → 都没有就触发 fetchChannelInfo，等 channelInfoUpdate 回调
/// 由 VC 把这一行 reload，下次 refresh 走 wrap 路径已是缓存命中。
- (WKChannelInfo *)lookupParentChannelInfo:(WKChannel *)parent {
    if (!parent || parent.channelId.length == 0) return nil;
    WKConversationWrapModel *parentWrap = [[WKConversationListVM shared] modelAtChannel:parent];
    WKChannelInfo *info = parentWrap.channelInfo;
    if (info) return info;
    info = [[WKSDK shared].channelManager getChannelInfo:parent];
    if (info) return info;
    [[WKSDK shared].channelManager fetchChannelInfo:parent completion:nil];
    return nil;
}


// 获取发送者名字
- (NSString*) getFromName  {
    if(!self.model.lastMessage) {
        return @"";
    }
    NSString *name;
    
   
//    if(self.model.lastMessage.fromUid && [WKApp shared].loginInfo.extra[@"name"] && [self.model.lastMessage.fromUid isEqualToString:[WKApp shared].loginInfo.uid] ) {
//        name = [WKApp shared].loginInfo.extra[@"name"];
//    }
    // 名字显示逻辑： 个人备注>群内名字>昵称
    
    if(self.model.lastMessage.from && !name) {
        if(self.model.lastMessage.from.remark && ![self.model.lastMessage.from.remark isEqualToString:@""]) {
            name = self.model.lastMessage.from.remark;
        }
    }
    if(!name) {
        if(self.model.lastMessage.memberOfFrom && self.model.lastMessage.memberOfFrom.memberRemark && ![self.model.lastMessage.memberOfFrom.memberRemark isEqualToString:@""]) {
            name = self.model.lastMessage.memberOfFrom.memberRemark;
        }
    }
    if(!name && self.model.lastMessage.from) {
        name = self.model.lastMessage.from.name;
        if([self.model.lastMessage.fromUid isEqualToString:[WKApp shared].config.systemUID]) {
            name = LLang(@"系统通知");
        }else if([self.model.lastMessage.fromUid isEqualToString:[WKApp shared].config.fileHelperUID]) {
            name = LLang(@"文件传输助手");
        }
    }
    
    if(name) {
        return name;
    }
    return @"";
    
}

-(BOOL) showFromName:(WKConversationWrapModel*)model {
    return model.lastMessage && (model.lastMessage.fromUid && ![model.lastMessage.fromUid isEqualToString:@""]) && model.lastMessage.from && ![model.lastMessage.content isKindOfClass:[WKSystemContent class]];
}

-(void) layoutSubviews {
    [super layoutSubviews];

    self.contextContainerView.frame = self.contentView.bounds;

    BOOL isGroup = (self.model.channel.channelType == WK_GROUP);
    // 最近 tab 群聊走 DM 布局（避免 group-summary 把头像放大、preview 区被压缩）
    BOOL useGroupSummaryLayout = isGroup && !self.recentTabContext;

    if(useGroupSummaryLayout) {
        BOOL showMention = !self.lastContentLbl.hidden;
        CGFloat avatarSize = 52.0f;
        CGFloat rightPadding = 15.0f;
        // 外部群 Tag 占位（与 bot/official 并列，挤占 title 宽度）
        CGFloat externalTagReserve = 0.0f;
        if(!self.externalGroupTagLbl.hidden) {
            externalTagReserve = self.externalGroupTagLbl.lim_width + 6.0f;
        }

        if (showMention) {
            // 有 @我：两行布局（标题 + 预览）
            self.avatarImgView.frame = CGRectMake(15.0f, 8.0f, avatarSize, avatarSize);

            CGFloat titleLeft = self.avatarImgView.lim_right + 10.0f;
            [self.titleLbl sizeToFit];
            CGFloat titleMaxWidth = self.lim_width - titleLeft - rightPadding - 50.0f - externalTagReserve;
            if(self.titleLbl.lim_width > titleMaxWidth) self.titleLbl.lim_width = titleMaxWidth;
            self.titleLbl.lim_left = titleLeft;
            self.titleLbl.lim_top = 10.0f;

            // @预览消息
            self.lastContentLbl.lim_left = titleLeft;
            self.lastContentLbl.lim_width = self.lim_width - titleLeft - rightPadding - 40.0f;
            self.lastContentLbl.lim_top = self.titleLbl.lim_bottom + 2.0f;
            self.lastContentLbl.lim_height = 18.0f;
        } else {
            // 无 @我：单行居中
            self.avatarImgView.frame = CGRectMake(15.0f, (self.lim_height - avatarSize) / 2.0f, avatarSize, avatarSize);

            CGFloat titleLeft = self.avatarImgView.lim_right + 10.0f;
            [self.titleLbl sizeToFit];
            CGFloat titleMaxWidth = self.lim_width - titleLeft - rightPadding - 50.0f - externalTagReserve;
            if(self.titleLbl.lim_width > titleMaxWidth) self.titleLbl.lim_width = titleMaxWidth;
            self.titleLbl.lim_left = titleLeft;
            self.titleLbl.lim_top = (self.lim_height - self.titleLbl.lim_height) / 2.0f;
        }
        // 右侧元素从右往左排列：toggle → 红点/免打扰
        CGFloat rightEdge = self.lim_width - rightPadding;

        // 子区展开按钮 - 最右侧固定位置
        if (!self.threadToggleBtn.hidden) {
            self.threadToggleBtn.frame = CGRectMake(rightEdge - 44, (self.lim_height - 44) / 2.0f, 44, 44);
            rightEdge = self.threadToggleBtn.lim_left - 2;
        }

        // 红点
        self.badgeView.lim_left = rightEdge - self.badgeView.lim_width;
        self.badgeView.lim_top = (self.lim_height - self.badgeView.lim_height) / 2.0f;

        // 免打扰图标
        self.muteIcon.lim_left = rightEdge - self.muteIcon.lim_width;
        self.muteIcon.lim_top = (self.lim_height - self.muteIcon.lim_height) / 2.0f;

        // 官方标签
        self.officialTag.lim_left = self.titleLbl.lim_right + 4.0f;
        self.officialTag.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height / 2.0f - self.officialTag.lim_height / 2.0f);

        // Bot标识
        if(!self.botBadgeLbl.hidden) {
            CGFloat botLeft = self.titleLbl.lim_right + 6.0f;
            if(!self.officialTag.hidden) {
                botLeft = self.officialTag.lim_right + 4.0f;
            }
            self.botBadgeLbl.lim_left = botLeft;
            self.botBadgeLbl.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.botBadgeLbl.lim_height) / 2.0f;
        }

        // 子区数量提示
        if(!self.threadCountLbl.hidden) {
            CGFloat tcLeft = self.titleLbl.lim_right + 4.0f;
            if(!self.botBadgeLbl.hidden) {
                tcLeft = self.botBadgeLbl.lim_right + 4.0f;
            } else if(!self.officialTag.hidden) {
                tcLeft = self.officialTag.lim_right + 4.0f;
            }
            self.threadCountLbl.lim_left = tcLeft;
            self.threadCountLbl.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.threadCountLbl.lim_height) / 2.0f;
        }

        // 外部群 Tag（只在群聊布局下可能出现；layout 路径外层已校验 isGroup）
        if(!self.externalGroupTagLbl.hidden) {
            CGFloat extLeft = self.titleLbl.lim_right + 6.0f;
            if(!self.botBadgeLbl.hidden) {
                extLeft = self.botBadgeLbl.lim_right + 4.0f;
            } else if(!self.officialTag.hidden) {
                extLeft = self.officialTag.lim_right + 4.0f;
            }
            self.externalGroupTagLbl.lim_left = extLeft;
            self.externalGroupTagLbl.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.externalGroupTagLbl.lim_height) / 2.0f;
        }

    } else {
        // ========== 私聊布局（保持原样） ==========

        // 头像（统一尺寸 42x42）
        CGFloat avatarSize = 52.0f;
        self.avatarImgView.frame = CGRectMake(15.0f, 0, avatarSize, avatarSize);
        self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
        // 子区头像右下角 hash 角标（仅最近 tab + 子区行显示）
        if (!self.threadAvatarOverlay.hidden) {
            CGFloat overlaySize = 22.0f;
            self.threadAvatarOverlay.frame = CGRectMake(
                self.avatarImgView.lim_right - overlaySize + 2.0f,
                self.avatarImgView.lim_bottom - overlaySize + 2.0f,
                overlaySize, overlaySize);
        }
        // 在线标记
        if(self.model.channelInfo && self.model.channelInfo.online) {
            self.onlineBadgeView.lim_left = self.avatarImgView.lim_right - self.onlineBadgeView.lim_width;
        }else {
            self.onlineBadgeView.lim_left = self.avatarImgView.lim_right - self.onlineBadgeView.lim_width + 4.0f;
        }
        self.onlineBadgeView.lim_top = self.avatarImgView.lim_bottom - self.onlineBadgeView.lim_height;

        self.autoDeleteView.lim_left = self.avatarImgView.lim_right - self.autoDeleteView.lim_width + 2.0f;
        self.autoDeleteView.lim_top = self.avatarImgView.lim_bottom - self.autoDeleteView.lim_height + 2.0f;
        // 名称
        CGFloat statusRightSpace = 2.0f;

        CGFloat titleLeftToAvatarSpace = 10.0f;
        self.titleLbl.lim_left = self.avatarImgView.lim_right + titleLeftToAvatarSpace;
        // 子区行多一行父群名，textBlock 高度要相应增加
        CGFloat sourceH = !self.threadSourceLbl.hidden ? 14.0f : 0.0f;
        CGFloat sourceGap = sourceH > 0 ? 1.0f : 0.0f;
        CGFloat textBlockH = sourceH + sourceGap + 20.0f + 3.0f + 24.0f; // (source + gap) + title + gap + content
        CGFloat textBlockTop = (self.lim_height - textBlockH) / 2.0f;
        if (!self.threadSourceLbl.hidden) {
            self.threadSourceLbl.lim_left = self.titleLbl.lim_left;
            self.threadSourceLbl.lim_top = textBlockTop;
            self.threadSourceLbl.lim_height = sourceH;
            self.threadSourceLbl.lim_width = self.lim_width - self.threadSourceLbl.lim_left - 15.0f;
        }
        self.titleLbl.lim_top = textBlockTop + sourceH + sourceGap;

        // 子区名前的 hash 小图标（最近 tab 子区行专用）
        CGFloat titleIconReserve = 0.0f;
        if (!self.threadTitleIcon.hidden) {
            titleIconReserve = 14.0f + 4.0f; // icon width + gap
            self.titleLbl.lim_left += titleIconReserve;
        }

        [self.lastMsgTimeLbl sizeToFit];
        CGFloat titleMaxWidth = self.lim_width - (self.avatarImgView.lim_right + 5.0f) - (self.lastMsgTimeLbl.lim_width+5.0f + 20.0f)  - 20.0f - titleIconReserve;
        if(!self.statusImgView.hidden) {
            titleMaxWidth = titleMaxWidth - (self.statusImgView.lim_width + statusRightSpace);
        }
        [self.titleLbl sizeToFit];
        if(self.titleLbl.lim_width> titleMaxWidth) {
            self.titleLbl.lim_width = titleMaxWidth;
        }

        // 子区名前的 hash 小图标定位（最近 tab 子区行专用）
        if (!self.threadTitleIcon.hidden) {
            CGFloat iconSize = 14.0f;
            self.threadTitleIcon.frame = CGRectMake(self.titleLbl.lim_left - titleIconReserve,
                                                     self.titleLbl.lim_top + (self.titleLbl.lim_height - iconSize) / 2.0f,
                                                     iconSize, iconSize);
        }

        // 最后一条消息
        self.lastContentLbl.lim_left = self.titleLbl.lim_left - titleIconReserve;
        self.lastContentLbl.lim_width = self.lim_width - self.lastContentLbl.lim_left - 10.0f;

        if(self.model.unreadCount>0 || self.model.mute) {
            self.lastContentLbl.lim_width -= 40.0f;
        }
        self.lastContentLbl.lim_top = self.titleLbl.lim_bottom + 3.0f;
        self.lastContentLbl.lim_height = 24.0f;

        // typing
        if(!self.typingIndicatorView.hidden) {
            self.typingIndicatorView.lim_left = self.titleLbl.lim_left;
            self.typingIndicatorView.lim_top = self.titleLbl.lim_bottom + 6.0f;

            self.lastContentLbl.lim_left = self.typingIndicatorView.lim_right + 2.0f;
            self.lastContentLbl.lim_width -= self.typingIndicatorView.lim_width;
        }

        // 最后一条消息时间
        self.lastMsgTimeLbl.lim_left = self.lim_width - self.lastMsgTimeLbl.lim_width - 15.0f;
        self.lastMsgTimeLbl.lim_top = self.titleLbl.lim_top+2.0f;

        // 消息状态
        self.statusImgView.lim_left = self.lastMsgTimeLbl.lim_left - self.statusImgView.lim_width - statusRightSpace;
        self.statusImgView.lim_top = self.lastMsgTimeLbl.lim_top+1.0f;

        // 红点
        self.badgeView.lim_top = self.lastMsgTimeLbl.lim_bottom + 2.0f;
        self.badgeView.lim_left = self.lim_width - 15.0f - self.badgeView.lim_width;

        // 免打扰图标
        self.muteIcon.lim_left = self.lim_width - self.muteIcon.lim_width - (self.lim_width-self.lastMsgTimeLbl.lim_left-self.lastMsgTimeLbl.lim_width);
        self.muteIcon.lim_top = self.badgeView.lim_top + 4.0f;

        self.officialTag.lim_left = self.titleLbl.lim_right+4.0f;
        self.officialTag.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height/2.0f - self.officialTag.lim_height/2.0f);
        if(self.model.channelInfo && [self.model.channelInfo.category isEqualToString:@"visitor"]) {
            self.officialTag.lim_top+=2;
        }

        // Bot标识
        if(!self.botBadgeLbl.hidden) {
            CGFloat botLeft = self.titleLbl.lim_right + 6.0f;
            if(!self.officialTag.hidden) {
                botLeft = self.officialTag.lim_right + 4.0f;
            }
            self.botBadgeLbl.lim_left = botLeft;
            self.botBadgeLbl.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.botBadgeLbl.lim_height) / 2.0f;
        }

        // 子区数量提示
        if(!self.threadCountLbl.hidden) {
            CGFloat tcLeft = self.titleLbl.lim_right + 4.0f;
            if(!self.botBadgeLbl.hidden) {
                tcLeft = self.botBadgeLbl.lim_right + 4.0f;
            } else if(!self.officialTag.hidden) {
                tcLeft = self.officialTag.lim_right + 4.0f;
            }
            self.threadCountLbl.lim_left = tcLeft;
            self.threadCountLbl.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.threadCountLbl.lim_height) / 2.0f;
        }
    }
}
- (UILabel *)hashTagLbl {
    if(!_hashTagLbl) {
        _hashTagLbl = [[UILabel alloc] init];
        _hashTagLbl.text = @"#";
        _hashTagLbl.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
        _hashTagLbl.textColor = [UIColor colorWithRed:148.0f/255.0f green:152.0f/255.0f blue:168.0f/255.0f alpha:1.0f]; // #9498A8
        _hashTagLbl.textAlignment = NSTextAlignmentCenter;
        _hashTagLbl.hidden = YES;
    }
    return _hashTagLbl;
}

- (UILabel *)threadCountLbl {
    if(!_threadCountLbl) {
        _threadCountLbl = [[UILabel alloc] init];
        _threadCountLbl.font = [[WKApp shared].config appFontOfSize:11.0f];
        _threadCountLbl.textColor = [UIColor colorWithRed:255.0f/255.0f green:149.0f/255.0f blue:0.0f/255.0f alpha:1.0f]; // #FF9500 橘黄色
        _threadCountLbl.textAlignment = NSTextAlignmentCenter;
        _threadCountLbl.hidden = YES;
    }
    return _threadCountLbl;
}

- (UIButton *)threadToggleBtn {
    if (!_threadToggleBtn) {
        _threadToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *icon = [WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(28, 28) color:[WKApp shared].config.themeColor];
        [_threadToggleBtn setImage:icon forState:UIControlStateNormal];
        _threadToggleBtn.contentEdgeInsets = UIEdgeInsetsMake(9, 9, 9, 9);
        _threadToggleBtn.hidden = YES;
        [_threadToggleBtn addTarget:self action:@selector(onThreadToggleTap) forControlEvents:UIControlEventTouchUpInside];
    }
    return _threadToggleBtn;
}

-(void) onThreadToggleTap {
    if (self.onToggleThreadPreview && self.model.channel.channelId.length > 0) {
        self.onToggleThreadPreview(self.model.channel.channelId);
    }
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}
@end
