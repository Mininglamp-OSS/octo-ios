//
//  WKConversationChannelHeader.m
//  WuKongBase
//
//  Created by tt on 2021/8/20.
//

#import "WKConversationChannelHeader.h"
#import "WKOnlineStatusManager.h"
#import "WKAutoDeleteView.h"
#import "WKOfficialTag.h"
#import "WKConstant.h"
#import "WKChannelUtil.h"
#import "WKRealnamePrefetcher.h"
@interface WKConversationChannelHeader ()

@property(nonatomic,strong) UIButton *infoBoxBtn;

@property(nonatomic,strong) WKUserAvatar *avatarImgView;

@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UILabel *subtitleLbl;

@property(nonatomic,strong) WKAutoDeleteView *autoDeleteView;

@property(nonatomic,strong) UIImageView *botBadgeLbl; // Bot标识（AI 图标）

@property(nonatomic,strong) WKOfficialTag *officialTag; // 官方图标

// / Phase A —— 私聊顶部实名 ✓ 徽章
// 12×12pt 蓝勾，紧贴 titleLbl 右侧，节奏与 botBadgeLbl 对齐。
@property(nonatomic,strong) UIImageView *realnameVerifiedImgView;

@end

@implementation WKConversationChannelHeader

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
//    [self setBackgroundColor:[UIColor redColor]];
    
    [self addSubview:self.infoBoxBtn];
    [self.infoBoxBtn addSubview:self.avatarImgView];
    [self.infoBoxBtn addSubview:self.titleLbl];
    [self.infoBoxBtn addSubview:self.subtitleLbl];
    [self.infoBoxBtn addSubview:self.botBadgeLbl];
    [self.infoBoxBtn addSubview:self.officialTag];
    [self.infoBoxBtn addSubview:self.realnameVerifiedImgView];
    [self addSubview:self.voiceCallBtn];
    [self addSubview:self.videoCallBtn];
    [self addSubview:self.moreDotsBtn];
    [self.avatarImgView addSubview:self.autoDeleteView];

    [self.infoBoxBtn addTarget:self action:@selector(infoPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.voiceCallBtn addTarget:self action:@selector(voiceCallPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.videoCallBtn addTarget:self action:@selector(videoCallPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.moreDotsBtn addTarget:self action:@selector(moreDotsPressed) forControlEvents:UIControlEventTouchUpInside];
    
    [WKApp.shared addChannelAvatarUpdateNotify:self selector:@selector(channelAvatarUpdate:)];
    
}

-(void) channelAvatarUpdate:(NSNotification*)notify {
    WKChannel *channel = notify.object;
    if(self.channelInfo && channel && [channel isEqual:self.channelInfo.channel]) {
        [self setChannelInfo:self.channelInfo]; // 重新刷新频道信息
    }
    
}

-(void) infoPressed {
    if(self.onInfo) {
        self.onInfo();
    }
}

-(void) voiceCallPressed {
    if(self.onVoiceCall) {
        self.onVoiceCall();
    }
}

-(void) videoCallPressed {
    if(self.onVideoCall) {
        self.onVideoCall();
    }
}

-(void) moreDotsPressed {
    if(self.onInfo) {
        self.onInfo(); // 与点击标题/头像打开群组设置相同
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.avatarImgView.lim_left = 0.0f;
    self.avatarImgView.lim_centerY_parent = self;

    // 三个点按钮在最右侧
    self.moreDotsBtn.lim_left = self.lim_width - self.moreDotsBtn.lim_width;
    self.moreDotsBtn.lim_centerY_parent = self;

    // 右侧按钮的左边界（三个点按钮左侧）
    CGFloat rightEdge = self.moreDotsBtn.hidden ? self.lim_width : self.moreDotsBtn.lim_left - 8.0f;

    self.videoCallBtn.lim_left = rightEdge - self.videoCallBtn.lim_width;
    self.videoCallBtn.lim_centerY_parent = self;

    if(self.videoCallBtn.hidden) {
        self.voiceCallBtn.lim_left = rightEdge - self.voiceCallBtn.lim_width;
        self.voiceCallBtn.lim_centerY_parent = self;
    }else {
        self.voiceCallBtn.lim_left = self.videoCallBtn.lim_left - self.voiceCallBtn.lim_width - 15.0f;
        self.voiceCallBtn.lim_centerY_parent = self;
    }

    self.infoBoxBtn.lim_height = self.lim_height;
    if(self.voiceCallBtn.hidden) {
        CGFloat infoRight = self.moreDotsBtn.hidden ? (self.lim_width - 10.0f) : (self.moreDotsBtn.lim_left - 8.0f);
        self.infoBoxBtn.lim_width = infoRight;
    }else{
        self.infoBoxBtn.lim_width = self.voiceCallBtn.lim_left;
    }
   
    CGFloat avatarRightSpace = 5.0f;
    
    CGFloat subtitleTop = 0.0f;
    CGFloat titleRightSpace = 5.0f;
    self.titleLbl.lim_width = self.infoBoxBtn.lim_width - self.avatarImgView.lim_right - avatarRightSpace - titleRightSpace;
//    [self.titleLbl setBackgroundColor:[UIColor redColor]];
    
    self.titleLbl.lim_left = self.avatarImgView.lim_right + avatarRightSpace;

    CGFloat contentHeight = self.titleLbl.lim_height + subtitleTop + self.subtitleLbl.lim_height;
    if(self.subtitleLbl.hidden) {
        contentHeight = self.titleLbl.lim_height;
    }
    
    self.titleLbl.lim_top = self.lim_height/2.0f - contentHeight/2.0f;
    
    self.subtitleLbl.lim_left = self.titleLbl.lim_left;
    self.subtitleLbl.lim_top = self.titleLbl.lim_bottom + subtitleTop;
    
    self.autoDeleteView.lim_left = self.avatarImgView.lim_width - self.autoDeleteView.lim_width + 4.0f;
    self.autoDeleteView.lim_top = self.avatarImgView.lim_height - self.autoDeleteView.lim_height + 2.0f;

    // 标题右侧标识（实名 + 官方 + Bot）
    [self.titleLbl sizeToFit];
    CGFloat badgesWidth = 0;
    if(!self.realnameVerifiedImgView.hidden) {
        badgesWidth += 12.0f + 6.0f;
    }
    if(!self.officialTag.hidden) {
        badgesWidth += self.officialTag.lim_width + 4.0f;
    }
    if(!self.botBadgeLbl.hidden) {
        badgesWidth += self.botBadgeLbl.lim_width + 6.0f;
    }
    CGFloat maxTitleWidth = self.infoBoxBtn.lim_width - self.avatarImgView.lim_right - avatarRightSpace - titleRightSpace - badgesWidth;
    if(self.titleLbl.lim_width > maxTitleWidth) {
        self.titleLbl.lim_width = maxTitleWidth;
    }

    CGFloat nextLeft = self.titleLbl.lim_left + self.titleLbl.lim_width;
    if(!self.realnameVerifiedImgView.hidden) {
        self.realnameVerifiedImgView.lim_width = 12.0f;
        self.realnameVerifiedImgView.lim_height = 12.0f;
        self.realnameVerifiedImgView.lim_left = nextLeft + 6.0f;
        self.realnameVerifiedImgView.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.realnameVerifiedImgView.lim_height) / 2.0f;
        nextLeft = self.realnameVerifiedImgView.lim_right;
    }
    if(!self.officialTag.hidden) {
        self.officialTag.lim_left = nextLeft + 4.0f;
        self.officialTag.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.officialTag.lim_height) / 2.0f;
        nextLeft = self.officialTag.lim_right;
    }
    if(!self.botBadgeLbl.hidden) {
        self.botBadgeLbl.lim_left = nextLeft + 6.0f;
        self.botBadgeLbl.lim_top = self.titleLbl.lim_top + (self.titleLbl.lim_height - self.botBadgeLbl.lim_height) / 2.0f;
    }
}

- (void)setChannelInfo:(WKChannelInfo *)channelInfo {
    _channelInfo = channelInfo;
    if(!_channelInfo) {
        return;
    }
    WKChannel *channel = channelInfo.channel;
    // 子区：使用子区图标作为默认头像
    if(channel.channelType == WK_COMMUNITY_TOPIC) {
        self.avatarImgView.avatarImgView.image = [self imageName:@"Conversation/Index/ThreadIcon"];
        self.titleLbl.text = channelInfo.displayName;
        self.subtitleLbl.hidden = YES;
        self.autoDeleteView.hidden = YES;
        self.officialTag.hidden = YES;
        self.botBadgeLbl.hidden = YES;
        self.realnameVerifiedImgView.hidden = YES;
        return;
    }
    self.titleLbl.text = channelInfo.displayName;
    if(channel.channelType == WK_PERSON) {
        if([channel.channelId isEqualToString:[WKApp shared].config.systemUID]) {
            self.titleLbl.text = LLang(@"系统通知");
            if(channelInfo.remark && ![channelInfo.remark isEqualToString:@""]) {
                self.titleLbl.text = channelInfo.remark;
            }
        }else if([channelInfo.channel.channelId isEqualToString:[WKApp shared].config.fileHelperUID]) {
            self.titleLbl.text = LLang(@"文件传输助手");
            if(channelInfo.remark && ![channelInfo.remark isEqualToString:@""]) {
                self.titleLbl.text = channelInfo.remark;
            }
        }
    }
   
    self.subtitleLbl.hidden = NO;
    if(channelInfo && (channelInfo.channel.channelType == WK_PERSON || channelInfo.channel.channelType == WK_CustomerService)) {
        
        NSString *onlineTip = [WKOnlineStatusManager.shared onlineStatusDetailTip:channelInfo];
        if(onlineTip) {
            self.subtitleLbl.text = onlineTip;
        }else {
            self.subtitleLbl.hidden = YES;
        }
        [self.subtitleLbl sizeToFit];
        {
            // 个人频道：始终拼接 ?v=cacheKey，cacheKey变化时SDWebImage自动重新下载
            NSString *key = (channelInfo.avatarCacheKey.length > 0) ? channelInfo.avatarCacheKey : @"0";
            NSString *baseUrl;
            if(channelInfo.logo && ![channelInfo.logo isEqualToString:@""]) {
                baseUrl = [WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo];
            }else{
                baseUrl = [WKAvatarUtil getAvatar:channelInfo.channel.channelId];
            }
            self.avatarImgView.url = [NSString stringWithFormat:@"%@?v=%@", baseUrl, key];
        }
        
    }else {
     
        if(channelInfo.logo && ![channelInfo.logo isEqualToString:@""]) {
            NSString *avatarURL = [WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo];
            NSString *key = (channelInfo.avatarCacheKey.length > 0) ? channelInfo.avatarCacheKey : @"0";
            NSString *separator = [avatarURL containsString:@"?"] ? @"&" : @"?";
            avatarURL = [NSString stringWithFormat:@"%@%@v=%@", avatarURL, separator, key];
            self.avatarImgView.url = avatarURL;
        }else{
            self.avatarImgView.url = [WKAvatarUtil getGroupAvatar:channelInfo.channel.channelId cacheKey:channelInfo.avatarCacheKey];
        }
    }
    NSInteger msgAutoDelete = 0;
    if(channelInfo.extra[@"msg_auto_delete"]) {
        msgAutoDelete = [channelInfo.extra[@"msg_auto_delete"] integerValue];
    }
    self.autoDeleteView.hidden = YES;
    if(msgAutoDelete>0) {
        self.autoDeleteView.hidden = NO;
        self.autoDeleteView.second = msgAutoDelete;
    }

    // 官方图标
    self.officialTag.hidden = YES;
    NSString *category = channelInfo.category;
    // 系统通知直接判断为官方
    if ([channel.channelId isEqualToString:[WKApp shared].config.systemUID]) {
        category = WKChannelCategoryService;
    }
    if(category && ![category isEqualToString:@""]) {
        if([category isEqualToString:WKChannelCategoryService]) {
            self.officialTag.frame = CGRectMake(0.0f, 0.0f, 18.0f, 18.0f);
            self.officialTag.hidden = NO;
            self.officialTag.image = [self imageName:@"ConversationList/Index/Official"];
        } else if([category isEqualToString:WKChannelCategoryVisitor]) {
            self.officialTag.frame = CGRectMake(0.0f, 0.0f, 35.0f, 18.0f);
            self.officialTag.hidden = NO;
            self.officialTag.image = [self imageName:@"ConversationList/Index/Visitor"];
        }
    }

    // Bot标识
    BOOL isBot = channelInfo.robot;
    self.botBadgeLbl.hidden = !isBot;
    if(isBot) {
        CGFloat h = 16.0f;
        CGFloat w = h;
        UIImage *img = self.botBadgeLbl.image;
        if(img && img.size.height > 0.0f) {
            w = h * img.size.width / img.size.height;
        }
        CGRect frame = self.botBadgeLbl.frame;
        frame.size = CGSizeMake(w, h);
        self.botBadgeLbl.frame = frame;
    }

    // 实名 ✓ 徽章：仅私聊（且非系统/文件助手/机器人）展示。
    BOOL canShowRealname = channel.channelType == WK_PERSON
        && ![channel.channelId isEqualToString:[WKApp shared].config.systemUID]
        && ![channel.channelId isEqualToString:[WKApp shared].config.fileHelperUID]
        && !isBot;
    BOOL realnameVerified = NO;
    if(canShowRealname) {
        NSNumber *flag = [WKChannelUtil isRealnameVerifiedFromExtra:channelInfo.extra];
        realnameVerified = flag.boolValue;
    }
    self.realnameVerifiedImgView.hidden = !realnameVerified;
    // 不打开名片也能补：未确认已实名时，后台拉一次 /users/<uid>，
    // 拉到后 channelInfoUpdate 触发 conversationVC.refreshTitle 重新进 setChannelInfo。
    if(canShowRealname && !realnameVerified) {
        [WKRealnamePrefetcher ensureFetched:channel.channelId];
    }
    [self setNeedsLayout];
}


- (void)setSubtitleText:(NSString *)subtitleText {
    _subtitleText = subtitleText;
    if (subtitleText.length > 0) {
        self.subtitleLbl.text = subtitleText;
        self.subtitleLbl.hidden = NO;
        [self.subtitleLbl sizeToFit];
        [self setNeedsLayout];
    }
}

- (void)setMemberCount:(NSInteger)memberCount {
    if(self.channelInfo && self.channelInfo.channel.channelType != WK_PERSON && self.channelInfo.channel.channelType != WK_CustomerService && self.channelInfo.channel.channelType != WK_COMMUNITY_TOPIC) {
        self.subtitleLbl.text = [NSString stringWithFormat:LLang(@"%ld个成员"),memberCount];
    }
    [self.subtitleLbl sizeToFit];

}

- (UIButton *)infoBoxBtn {
    if(!_infoBoxBtn) {
        _infoBoxBtn = [[UIButton alloc] init];
    }
    return _infoBoxBtn;
}

- (WKUserAvatar *)avatarImgView {
    if(!_avatarImgView) {
        _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 38.0f, 38.0f)];
        _avatarImgView.userInteractionEnabled = NO;
    }
    return _avatarImgView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [[WKApp shared].config appFontOfSizeSemibold:17.0f];
        _titleLbl.lim_height = 19.0f;
        _titleLbl.textColor = [WKApp shared].config.navBarTitleColor;
        _titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _titleLbl;
}

- (UILabel *)subtitleLbl {
    if(!_subtitleLbl) {
        _subtitleLbl = [[UILabel alloc] init];
        _subtitleLbl.font = [[WKApp shared].config appFontOfSizeMedium:12.0f];
        _subtitleLbl.textColor = [WKApp shared].config.navBarSubtitleColor;
    }
    return _subtitleLbl;
}

- (UIButton *)voiceCallBtn {
    if(!_voiceCallBtn) {
        _voiceCallBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIImage *img;
        if (@available(iOS 13.0, *)) {
            img =  [[self imageName:@"Conversation/Index/VoiceCall"] imageWithTintColor:[WKApp shared].config.navBarButtonColor renderingMode:UIImageRenderingModeAlwaysTemplate];
           
        } else {
            img = [[self imageName:@"Conversation/Index/VoiceCall"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        [_voiceCallBtn setImage:img forState:UIControlStateNormal];
        [_voiceCallBtn setTintColor:[WKApp shared].config.navBarButtonColor];
    }
    return _voiceCallBtn;
}

- (WKAutoDeleteView *)autoDeleteView {
    if(!_autoDeleteView) {
        _autoDeleteView = [[WKAutoDeleteView alloc] init];
    }
    return _autoDeleteView;
}

- (WKOfficialTag *)officialTag {
    if(!_officialTag) {
        _officialTag = [WKOfficialTag new];
    }
    return _officialTag;
}

- (UIImageView *)botBadgeLbl {
    if(!_botBadgeLbl) {
        _botBadgeLbl = [[UIImageView alloc] init];
        _botBadgeLbl.image = [self imageName:@"Common/Index/IconAIBadge"];
        _botBadgeLbl.contentMode = UIViewContentModeScaleAspectFit;
        _botBadgeLbl.hidden = YES;
    }
    return _botBadgeLbl;
}

// ：私聊顶部实名 ✓ 徽章
- (UIImageView *)realnameVerifiedImgView {
    if(!_realnameVerifiedImgView) {
        _realnameVerifiedImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 12.0f, 12.0f)];
        _realnameVerifiedImgView.contentMode = UIViewContentModeScaleAspectFit;
        _realnameVerifiedImgView.image = [self imageName:@"Common/ic_realname_verified_mini"];
        _realnameVerifiedImgView.hidden = YES;
    }
    return _realnameVerifiedImgView;
}

- (UIButton *)moreDotsBtn {
    if(!_moreDotsBtn) {
        _moreDotsBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIImage *img;
        if (@available(iOS 13.0, *)) {
            img = [[self imageName:@"Conversation/Index/MoreDots"] imageWithTintColor:[WKApp shared].config.navBarButtonColor renderingMode:UIImageRenderingModeAlwaysTemplate];
        } else {
            img = [[self imageName:@"Conversation/Index/MoreDots"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        [_moreDotsBtn setImage:img forState:UIControlStateNormal];
        [_moreDotsBtn setTintColor:[WKApp shared].config.navBarButtonColor];
        _moreDotsBtn.hidden = YES; // 默认隐藏，由外部控制显示
    }
    return _moreDotsBtn;
}

- (UIButton *)videoCallBtn {
    if(!_videoCallBtn) {
        _videoCallBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        UIImage *img;
        if (@available(iOS 13.0, *)) {
            img =  [[self imageName:@"Conversation/Index/VideoCall"] imageWithTintColor:[WKApp shared].config.navBarButtonColor renderingMode:UIImageRenderingModeAlwaysTemplate];
           
        } else {
            img = [[self imageName:@"Conversation/Index/VideoCall"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        [_videoCallBtn setImage:img forState:UIControlStateNormal];
        [_videoCallBtn setTintColor:[WKApp shared].config.navBarButtonColor];
    }
    return _videoCallBtn;
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    if(type == WKViewConfigChangeTypeStyle) {
        self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
        self.subtitleLbl.textColor = [WKApp shared].config.tipColor;
    }
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
