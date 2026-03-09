//
//  WKConversationChannelHeader.m
//  WuKongBase
//
//  Created by tt on 2021/8/20.
//

#import "WKConversationChannelHeader.h"
#import "WKOnlineStatusManager.h"
#import "WKAutoDeleteView.h"
@interface WKConversationChannelHeader ()

@property(nonatomic,strong) UIButton *infoBoxBtn;

@property(nonatomic,strong) WKUserAvatar *avatarImgView;

@property(nonatomic,strong) UILabel *titleLbl;
@property(nonatomic,strong) UILabel *subtitleLbl;

@property(nonatomic,strong) WKAutoDeleteView *autoDeleteView;




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
    [self addSubview:self.voiceCallBtn];
    [self addSubview:self.videoCallBtn];
    [self.avatarImgView addSubview:self.autoDeleteView];
    
    [self.infoBoxBtn addTarget:self action:@selector(infoPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.voiceCallBtn addTarget:self action:@selector(voiceCallPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.videoCallBtn addTarget:self action:@selector(videoCallPressed) forControlEvents:UIControlEventTouchUpInside];
    
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

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.avatarImgView.lim_left = 0.0f;
    self.avatarImgView.lim_centerY_parent = self;
    
    self.videoCallBtn.lim_left = self.lim_width - self.videoCallBtn.lim_width;
    self.videoCallBtn.lim_centerY_parent = self;
    
    if(self.videoCallBtn.hidden) {
        self.voiceCallBtn.lim_left = self.lim_width - self.voiceCallBtn.lim_width;
        self.voiceCallBtn.lim_centerY_parent = self;
    }else {
        self.voiceCallBtn.lim_left = self.videoCallBtn.lim_left - self.voiceCallBtn.lim_width - 15.0f;
        self.voiceCallBtn.lim_centerY_parent = self;
    }
   
    
   
    self.infoBoxBtn.lim_height = self.lim_height;
    if(self.voiceCallBtn.hidden) {
        self.infoBoxBtn.lim_width = self.lim_width -  10.0f;
        
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
    
    
}

- (void)setChannelInfo:(WKChannelInfo *)channelInfo {
    _channelInfo = channelInfo;
    if(!_channelInfo) {
        return;
    }
    WKChannel *channel = channelInfo.channel;
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
        if(channelInfo.logo && ![channelInfo.logo isEqualToString:@""]) {
            self.avatarImgView.url = [WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo];
        }else{
            self.avatarImgView.url = [WKAvatarUtil getAvatar:channelInfo.channel.channelId];
        }
        
    }else {
     
        if(channelInfo.logo && ![channelInfo.logo isEqualToString:@""]) {
            self.avatarImgView.url = [WKAvatarUtil getFullAvatarWIthPath:channelInfo.logo];
        }else{
            self.avatarImgView.url = [WKAvatarUtil getGroupAvatar:channelInfo.channel.channelId];
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
}


- (void)setMemberCount:(NSInteger)memberCount {
    if(self.channelInfo && self.channelInfo.channel.channelType != WK_PERSON && self.channelInfo.channel.channelType != WK_CustomerService) {
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
