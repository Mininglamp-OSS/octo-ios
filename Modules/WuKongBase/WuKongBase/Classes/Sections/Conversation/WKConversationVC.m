//
//  WKConversationVC.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKConversationVC.h"
#import "WKMessageListView.h"
#import "WuKongBase.h"
#import "WKMessageListDataProviderImp.h"
#import "WKConversationChannelHeader.h"
#import "WKConversationListVM.h"
#import "WKConversationView.h"
#import "NSString+WK.h"
#import "WKConversationView+Robot.h"
#import "WKMessageListView+Position.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import "Svg.h"
#import "WKThemeUtil.h"
@interface WKConversationVC ()<WKChannelManagerDelegate>

@property(nonatomic,strong) WKConversationView *conversationView;

@property(nonatomic,strong) WKConversationChannelHeader *channelHeader;

@property(nonatomic,copy) videoCallSupportInvoke videocallInvoke; // 是否支持视频通话

@property(nonatomic,strong) UIButton *cancelMutipleBtn; // 取消多选的按钮

@property(nonatomic,strong) WKChannelInfo *channelInfo;

@property(nonatomic,assign) BOOL firstLoad; // 是否第一次加载

@property(nonatomic,strong) UIImageView *backgroundView;

@end

@implementation WKConversationVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.firstLoad = true;
    [self.view addSubview:self.backgroundView];
    
    [self addDelegates];
    
    [self setupChatBackground];
   
    self.videocallInvoke = [[WKApp shared] invoke:WKPOINT_VIDEOCALL_SUPPORT_FNC param:@{@"channel":self.channel,@"context":self.conversationView.conversationContext}];
    
  
    [self.navigationBar addSubview:self.channelHeader];
    [self.view addSubview:self.conversationView];
    [self.view bringSubviewToFront:self.navigationBar]; // 将导航栏放到最顶层
    
    __weak typeof(self) weakSelf = self;
    
    self.conversationView.channel = self.channel;
    self.conversationView.locationAtOrderSeq = self.locationAtOrderSeq;
    self.conversationView.conversationVM.onMemberUpdate = ^{
        [weakSelf refreshTitle];
        [weakSelf.conversationView setGroupForbiddenIfNeed];
        [weakSelf.conversationView syncRobot:[weakSelf getMemberRobotIDs]];
        WKChannelMember *memberOfMe = weakSelf.conversationView.conversationVM.memberOfMe;
        if(memberOfMe) {
            if(weakSelf.videocallInvoke!=nil) {
                [weakSelf showVideoCall:memberOfMe.status == WKMemberStatusNormal];
            }
        }
        
    };
    [self.conversationView viewDidLoad];
     
   
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if(!weakSelf) {
            return;
        }
        [weakSelf requestLoadChannelInfoIfNeed];
        [weakSelf markFlameMessages];
    });
    
    
    // 获取注入的顶部面板
   UIView *topPanel = [WKApp.shared invoke:WKPOINT_CONVERSATION_TOP_PANEL param:@{@"channel":self.channel,@"context":self.conversationView.conversationContext}];
    self.conversationView.topView.hidden = YES;
    self.conversationView.topView.lim_top = -self.conversationView.topView.lim_height;
    if(topPanel) {
        self.conversationView.topView.lim_height = topPanel.lim_height;
        [self.conversationView.topView addSubview:topPanel];
    }
}


-(void) addDelegates {
    [[WKSDK shared].channelManager addDelegate:self]; // 频道数据监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateChatBackground) name:WKNOTIFY_CHATBACKGROUND_CHANGE object:nil];
}
-(void) removeDelegates {
    [[WKSDK shared].channelManager removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_CHATBACKGROUND_CHANGE object:nil];
}


// 标记阅后即焚的消息（如果超时则删除）
-(void) markFlameMessages {
    NSArray<WKMessage*> *messages = [WKFlameManager.shared getMessagesOfNeedFlame];
    if(messages && messages.count>0) {
        NSMutableArray<WKMessageModel*> *messageModels = [NSMutableArray array];
        for (WKMessage *message in messages) {
            [messageModels addObject:[[WKMessageModel alloc] initWithMessage:message]];
        }
        [WKMessageManager.shared deleteMessages:messageModels];
    }
}

// 获取机器人成员
-(NSArray<NSString*>*) getMemberRobotIDs {
    NSMutableArray *robots = [NSMutableArray array];
    for (WKChannelMember *channelMember in self.conversationView.conversationVM.members) {
        if(channelMember.robot) {
            [robots addObject:channelMember.memberUid];
        }
    }
    return robots;
}

-(void) requestLoadChannelInfoIfNeed{
    BOOL needFetch = false;
    self.channelInfo = [[WKChannelManager shared] getChannelInfo:self.channel];
    self.conversationView.conversationVM.channelInfo = self.channelInfo;
    if(self.channelInfo) {
        if(self.conversationView.conversationVM.groupType == WKGroupTypeSuper) {
            needFetch = true; // 超级群每次都获取channelInfo
        }
        __weak typeof(self) weakSelf  = self;
        lim_dispatch_main_async_safe(^{
            [weakSelf channelInfoLoadFinished];
        })
    }else {
        needFetch = true;
    }
    
    if(needFetch) {
        [[WKChannelManager shared] fetchChannelInfo:self.channel];
    }
}

- (void)dealloc {
    NSLog(@"%s",__func__);
    [self removeDelegates];
    [self markFlameMessages];
}

-(void) channelInfoLoadFinished {
    [self refreshTitle];
    [self.conversationView setGroupForbiddenIfNeed];
    if(self.channel.channelType == WK_PERSON && self.channelInfo.robot) {
        [self.conversationView syncRobot:@[self.channel.channelId]];
    }
    
    if(self.firstLoad) {
        self.firstLoad = false;
        WKGroupType groupType =  self.conversationView.conversationVM.groupType;
        if(groupType == WKGroupTypeCommon) { // 普通群
            [self commonGroupInit];
        }else if(groupType == WKGroupTypeSuper) { // 超级群
            [self superGroupInit];
        }
    }
    
    
}
// 超级群初始化
-(void) superGroupInit {
    [self refreshTitle];
}

// 普通群初始化
-(void) commonGroupInit {
    [self.conversationView.conversationVM requestMembers];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.conversationView viewWillDisappear:animated];
   
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.conversationView viewWillAppear];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.conversationView viewDidDisappear];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.conversationView viewDidAppear];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    [self.conversationView layoutSubviews];
    [self.conversationView.messageListView viewDidLayoutSubviewsOfPosition];
}

- (WKConversationView *)conversationView {
    if(!_conversationView) {
        CGFloat offset = self.navigationBar.lim_bottom;
        _conversationView = [[WKConversationView alloc] initWithFrame:CGRectMake(0.0f, offset, self.view.lim_width, self.view.lim_height - offset) channel:self.channel];
        __weak typeof(self) weakSelf = self;
        _conversationView.onMultiple = ^(BOOL on) {
            // 显示或隐藏 取消按钮
            weakSelf.navigationBar.showBackButton = !on;
            if(on) {
                [weakSelf.navigationBar addSubview:weakSelf.cancelMutipleBtn];
            }else{
                [weakSelf.cancelMutipleBtn removeFromSuperview];
            }
        };
    }
    return _conversationView;
}
-(void) refreshTitle {
    if(self.channelInfo) {
        
        self.channelHeader.channelInfo = self.channelInfo;
        self.channelHeader.memberCount = self.conversationView.conversationVM.memberCount;
        
        
        [self.channelHeader layoutSubviews];
        
        NSString *channelName = self.channelInfo.displayName;
        NSString *showChannelName = [channelName limitedStringForMaxBytesLength:20];
        if(showChannelName.length <channelName.length) {
            showChannelName = [NSString stringWithFormat:@"%@...",showChannelName];
        }
        [self.conversationView.input.textView internalTextView].placeholder=[NSString stringWithFormat:LLang(@"发送给 %@"),showChannelName];
       
    }
}

- (UIImageView *)backgroundView {
    if(!_backgroundView) {
        _backgroundView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        _backgroundView.clipsToBounds = YES;
        _backgroundView.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _backgroundView;
}

- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if(type == WKViewConfigChangeTypeStyle) {
        [self setupChatBackground];
    }
}

-(void) setChatBackgroud:(UIImage*)img {
//    self.view.layer.contents = (id)img.CGImage;
    self.backgroundView.image = img;
}

-(BOOL) hasSetChatBackgroud {
    if(self.view.layer.contents) {
        return true;
    }
    return false;
}

-(void) setupChatBackground {
    if([self hasSetChatBackgroud]) {
        return;
    }
    [self updateChatBackground];
   
}

-(void) updateChatBackground {
    BOOL existChannelBg = [WKThemeUtil existChatBackground:self.channel];
    if(existChannelBg) {
       NSData *channelBgData = [WKThemeUtil getChatBackground:self.channel style:WKApp.shared.config.style];
        if(channelBgData) {
            [self setChatBackgroud:[UIImage imageWithData:channelBgData]];
            return;
        }
    }
    
    BOOL existDefaultBg = [WKThemeUtil existDefaultbackground];
    if(existDefaultBg) {
        NSData *defaultBgData = [WKThemeUtil getDefaultBackground:WKApp.shared.config.style];
         if(defaultBgData) {
             [self setChatBackgroud:[UIImage imageWithData:defaultBgData]];
             return;
         }
    }
    
    [self setChatBackgroud:[self imageName:@"Conversation/Index/ChatBg"]];
}

- (WKConversationChannelHeader *)channelHeader {
    if(!_channelHeader) {
        CGFloat leftSpace = 50.0f;
        CGFloat rightSpace = 10.0f;
        CGFloat statusBottom = [UIApplication sharedApplication].statusBarFrame.origin.y + [UIApplication sharedApplication].statusBarFrame.size.height;
       
        _channelHeader = [[WKConversationChannelHeader alloc] initWithFrame:CGRectMake(leftSpace, statusBottom, self.view.lim_width - leftSpace - rightSpace, self.navigationBar.lim_height - (statusBottom))];
        __weak typeof(self) weakSelf = self;
        [_channelHeader setOnInfo:^{
            [[WKApp shared] invoke:WKPOINT_CONVERSATION_SETTING param:@{@"channel":weakSelf.channel,@"context":weakSelf.conversationView.conversationContext}];
        }];
        
//        WKChannelMember *memberOfMe = weakSelf.conversationView.conversationVM.memberOfMe;
        BOOL showCall = false;
        if(self.videocallInvoke!=nil ) {
            showCall = true;
        }
        [self showVideoCall:showCall];
        
        [_channelHeader setOnVoiceCall:^{
            if(weakSelf.videocallInvoke) {
                weakSelf.videocallInvoke(weakSelf.channel,WKCallTypeAudio);
            }
        }];
        
        [_channelHeader setOnVideoCall:^{
            weakSelf.videocallInvoke(weakSelf.channel,WKCallTypeVideo);
        }];
//        [_channelHeader setBackgroundColor:[UIColor redColor]];
    }
    return _channelHeader;
}

-(void) showVideoCall:(BOOL) show {
    if(!show) {
        _channelHeader.voiceCallBtn.hidden = YES;
        _channelHeader.videoCallBtn.hidden = YES;
    }else {
        _channelHeader.voiceCallBtn.hidden = NO;
        if(self.channel.channelType == WK_GROUP) {
            _channelHeader.videoCallBtn.hidden = YES;
        }else{
            _channelHeader.videoCallBtn.hidden = NO;
        }
    }
    [_channelHeader layoutSubviews];
}


- (UIButton *)cancelMutipleBtn {
    if(!_cancelMutipleBtn) {
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        _cancelMutipleBtn = [[UIButton alloc] initWithFrame:CGRectMake(10.0f, statusHeight, 0.0f, 0.0f)];
        [_cancelMutipleBtn setTitle:LLang(@"取消") forState:UIControlStateNormal];
        [_cancelMutipleBtn.titleLabel setFont:[[WKApp shared].config appFontOfSize:16.0f]];
        [_cancelMutipleBtn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        [_cancelMutipleBtn sizeToFit];
        [_cancelMutipleBtn addTarget:self action:@selector(cancelMultiplePressed) forControlEvents:UIControlEventTouchUpInside];
        _cancelMutipleBtn.lim_top = (self.navigationBar.lim_height - statusHeight)/2.0f - _cancelMutipleBtn.lim_height/2.0f + statusHeight;
    }
    return _cancelMutipleBtn;
}

-(void) cancelMultiplePressed {
    [self.conversationView setMultipleOn:NO selectedMessage:nil];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

#pragma mark - WKChannelManagerDelegate
// 频道信息更新
-(void) channelInfoUpdate:(WKChannelInfo*)channelInfo oldChannelInfo:(WKChannelInfo * _Nullable)oldChannelInfo {
    if([self.channel isEqual:channelInfo.channel]) { // 更新的当前会话的信息
        self.channelInfo = channelInfo;
        self.conversationView.conversationVM.channelInfo = self.channelInfo;
        [self channelInfoLoadFinished];
        if(oldChannelInfo.flame!=channelInfo.flame) {
            [(id<WKConversationContext>)self.conversationView.conversationContext refreshInputView];
        }
    }
   
}
@end
