//
//  WKConversationView.m
//  WuKongBase
//
//  Created by tt on 2022/5/18.
//

#import "WKConversationView.h"
#import "WuKongBase.h"
#import "WKMessageListDataProviderImp.h"
#import "WKConversationListVM.h"
#import "WKConversationInputPanel.h"
#import "WKMessageListView+Position.h"
#import "WKLastImgView.h"
#import "WKConversationContextImpl.h"
#import "WKStickerManager.h"
#import "WKStickerGIFContentView.h"
#import "WKEmojiContentView.h"
#import "WKUserHandleVC.h"
#import "WKMultiplePanel.h"
#import "WKConversationListSelectVC.h"
#import "WKMergeForwardContent.h"
#import "WKScreenshotContent.h"
#import "WKConversationView+Robot.h"


@interface WKConversationView ()<WKConversationInputPanelDelegate,WKMultiplePanelDelegate>

@property(nonatomic,strong) WKConversation *currentConversation; // 当前最近会话
@property(nonatomic,strong) WKMessageListDataProviderImp *dataProvider;



@property(nonatomic,assign) NSTimeInterval lastTypingTime; // 最后一次typing时间


// ---------- 多选 ----------
@property(nonatomic,assign) BOOL multipleOn; // 是否开启多选
@property(nonatomic,strong) WKMultiplePanel *multiplePanel; // 多选面板

// ---------- 禁言 ----------
@property(nonatomic,strong) UIView *forbiddenView;
@property(nonatomic,strong) UILabel *forbiddenTitleLbl;
@property(nonatomic,strong) NSTimer *forbiddenTimer; // 禁言倒计时


@end

@implementation WKConversationView

- (instancetype)initWithFrame:(CGRect)frame channel:(WKChannel*)channel
{
    self = [super initWithFrame:frame];
    if (self) {
        self.channel = channel;
        
    }
    return self;
}

- (WKConversationVM *)conversationVM {
    if(!_conversationVM) {
        _conversationVM = [[WKConversationVM alloc] init];
        _conversationVM.channel = self.channel;
    }
    return _conversationVM;
}
-(void) viewDidLoad {
    [self setupUI];
    
    [self initRobot];

    [self initMessageListParam];

    [self.messageListView viewDidLoad];
    
    [self recoveryDraft]; // 恢复草稿如果有的话
    
    [self enableWrapLineMenus]; // 启用换行菜单
    
    [self addSubview:self.forbiddenView];
}

- (void)viewDidAppear {
    [self.input addKeyboardListen];
    
}


- (UIView *)inputParentView {
    if(!_inputParentView) {
        return self;
    }
    return _inputParentView;
}

-(void) menuDidHideMenu:(NSNotification *)notification {
    [self enableWrapLineMenus];
}
-(void) wrapLineMenu:(id)sender {
    [self.input inputInsertText:@"\n"];
}
// 启用换行菜单
-(void) enableWrapLineMenus{
    UIMenuItem *menuItem = [[UIMenuItem alloc]initWithTitle:LLang(@"换行") action:@selector(wrapLineMenu:)];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setMenuItems:[NSArray arrayWithObject:menuItem]];
    [menuController setMenuVisible:NO];
}


-(void) setupUI {
    
    [self addDelegates];
    
    [self addSubview:self.messageListView];
    // input需要在tableview后添加
    [self.inputParentView addSubview:self.input];
    
    // 安装表情贴图
    [[WKStickerManager shared] setupIfNeed];
    
    [self addSubview:self.topView];
    
}



-(void) viewWillAppear {
    if(self.keepKeyboard) {
        [self.input becomeFirstResponder]; // 弹出键盘
        self.keepKeyboard = false;
    }
    // 截屏通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidTakeScreenshot) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
    if(self.inputParentView != self) {
        [self.inputParentView addSubview:self.input];
    }
    
}
- (void)viewWillDisappear:(BOOL)animated {
    
    [self.input removeKeyboardListen];
    
    // 是否保持键盘弹起
    if(self.input.keyboardHeight>0) {
        self.keepKeyboard = true;
        [self.input endEditing:YES]; // 隐藏键盘
        
    }
    
    [self.messageListView viewWillDisappear];
    
    [self saveDraftOrKeepPosition];
    
    [self requestSetUnreadIfNeed];
    if(self.inputParentView != self) {
        [self.input removeFromSuperview];
    }
    
}
-(void) viewDidDisappear {
    // 截屏通知
    if(WKApp.shared.config.takeScreenshotOn) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationUserDidTakeScreenshotNotification object:nil];
    }
   
   
}

-(void) requestMembers {
    [self.conversationVM requestMembers];
}


- (void)dealloc {
    WKLogDebug(@"%s",__func__);
    [self destoryForbiddenTimer];
    [self removeDelegates];
}


-(void) showTopView:(BOOL)show animated:(BOOL)animated{
    if(!self.topView.hidden && show) {
        return;
    }
    if(self.topView.hidden && !show) {
        return;
    }
   
    if(show) {
        self.topView.alpha = 0.0f;
    }else {
        self.topView.alpha = 1.0f;
    }
    self.topView.hidden = NO;
    
    if(animated) {
        [UIView animateWithDuration:0.2f animations:^{
            if(show) {
                self.topView.lim_top = 0.0f;
                self.topView.alpha = 1.0f;
            }else {
                self.topView.lim_top = -self.topView.lim_height;
                self.topView.alpha = 0.0f;
            }
           
            [self layoutSubviews];
        } completion:^(BOOL finished) {
            self.topView.hidden = !show;
            [self.topView layoutSubviews];
        }];
    }else {
        if(show) {
            self.topView.lim_top = 0.0f;
            self.topView.alpha = 1.0f;
        }else {
            self.topView.lim_top = -self.topView.lim_height;
            self.topView.alpha = 0.0f;
        }
        self.topView.hidden = !show;
        [self layoutSubviews];
    }
    
}

-(void) addDelegates {
    // 长按菜单隐藏(长按菜单恢复到原来状态)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHideMenu:) name:UIMenuControllerDidHideMenuNotification object:nil];
}

-(void) removeDelegates {
    // 移除长按菜单隐藏监听
    if(WKApp.shared.config.takeScreenshotOn) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIMenuControllerDidHideMenuNotification object:nil];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.forbiddenView.lim_top = self.inputParentView.lim_height;
    self.multiplePanel.lim_top = self.inputParentView.lim_height;
    
    UIView *otherPanel;
    if(!self.forbiddenView.hidden) {
        [self bringSubviewToFront:self.forbiddenView];
        otherPanel  = self.forbiddenView;
    }else if(self.multiplePanel.superview){
        otherPanel = self.multiplePanel;
    }
    if(otherPanel) {
        self.input.lim_top = self.inputParentView.lim_height;
        otherPanel.lim_top = self.inputParentView.lim_height - otherPanel.lim_height;
        if(self.topView.hidden) {
            [self.messageListView adjustTableWithOffset:otherPanel.lim_height];
        }else {
            [self.messageListView adjustTableWithOffset:otherPanel.lim_height + self.topView.lim_height];
        }
        
    }else {
        if(self.input.hidden) {
            self.input.lim_top = self.inputParentView.lim_height;
        }else {
            self.input.lim_top = self.inputParentView.lim_height - self.input.lim_height;
        }
        if(self.tableOffsetY>0) {
            if(self.topView.hidden) {
                [self.messageListView adjustTableWithOffset:self.tableOffsetY];
            }else {
                [self.messageListView adjustTableWithOffset:self.tableOffsetY + self.topView.lim_height];
            }
            
        }else {
            if(self.topView.hidden) {
                [self.messageListView adjustTableWithOffset:self.input.lim_height];
            }else {
                [self.messageListView adjustTableWithOffset:self.input.lim_height+self.topView.lim_height];
            }
           
        }
        
    }
    
    if(!self.topView.hidden) {
        self.messageListView.lim_top = self.topView.lim_height;
        self.messageListView.lim_height = self.lim_height - self.topView.lim_height;
    } else {
        self.messageListView.lim_top = 0.0f;
        self.messageListView.lim_height = self.lim_height;
    }
//   
    [self.messageListView layoutConversationPositionBarView];
    
    [self adjustRobotMenusIfNeed];
        
}


// 用户截屏
-(void) userDidTakeScreenshot {
    [self.conversationContext sendMessage:WKScreenshotContent.new];
}

-(void) requestSetUnreadIfNeed {
    WKConversation *conversation = [[WKSDK shared].conversationManager getConversation:self.channel];
    if(!conversation) {
        return;
    }
    uint32_t messageSeq = 0;
    if(self.messageListView.lastMessage) {
        messageSeq = self.messageListView.lastMessage.messageSeq;
    }
    if(self.messageListView.browseToOrderSeq == 0 && self.messageListView.newMsgCount>0) { // lastMessageSeq为0 要么就是自己发送中的消息，要么就是本地插入的消息，此时
        [[WKMessageManager shared] conversationSetUnread:self.channel unread:0 messageSeq:messageSeq complete:nil];
    }else if(conversation.unreadCount != self.messageListView.newMsgCount) {
        [[WKMessageManager shared] conversationSetUnread:self.channel unread:self.messageListView.newMsgCount messageSeq:messageSeq complete:nil];
    }else if(self.messageListView.hasRecvMsg) {
        [[WKMessageManager shared] conversationSetUnread:self.channel unread:self.messageListView.newMsgCount messageSeq:messageSeq complete:nil];
    }
}

// 保存草稿或保持位置
-(void) saveDraftOrKeepPosition {
    WKConversation *conversation = self.currentConversation;
    if(conversation) {
        WKConversationExtra *extra = conversation.remoteExtra;
        NSString *text = [self.input inputText];
        if(![text isEqualToString:@""]) {
            extra.draft = text;
        }else {
            extra.draft = @"";
        }
        if(self.messageListView.keepPosition) {
            WKConversationPosition *position = self.messageListView.keepPosition;
            extra.keepMessageSeq = [[WKSDK shared].chatManager getMessageSeq:position.orderSeq];
            extra.keepOffsetY = position.offset;
        }else {
            extra.keepMessageSeq = 0;
            extra.keepOffsetY = 0;
        }
        conversation.remoteExtra = extra;
        [[WKSDK shared].conversationManager updateOrAddExtra:extra];
    }
    
}

-(void) calcKeepPositionAndBrowseToOrderSeq {
    
    if(!self.currentConversation) {
        return;
    }
    
    NSInteger keepOffSetY = 0;
    uint32_t keepOrderSeq = 0;
    NSInteger newMsgCount = self.currentConversation.unreadCount;
    WKMessage *conversationLastMessage = self.currentConversation.lastMessage;
    if(newMsgCount>0) { // 有新消息，则定位到新消息第一条
        uint32_t lastMessageSeq = [[WKSDK shared].chatManager getOrNearbyMessageSeq:conversationLastMessage.orderSeq];
        if(lastMessageSeq>newMsgCount) {
            self.messageListView.browseToOrderSeq= [[WKSDK shared].chatManager getOrderSeq:lastMessageSeq - (uint32_t)newMsgCount];
            keepOrderSeq = self.messageListView.browseToOrderSeq;
            keepOffSetY = -120.0f;
        }
        
    }
    BOOL useKeep = false; // 是否使用保持的位置
    if(self.currentConversation.remoteExtra.keepMessageSeq>0) { // 有保持位置
        uint32_t kpOrderSeq = [[WKSDK shared].chatManager getOrderSeq:self.currentConversation.remoteExtra.keepMessageSeq];
        if(keepOrderSeq == 0 || kpOrderSeq < keepOrderSeq) {
            keepOrderSeq = kpOrderSeq;
            keepOffSetY = self.currentConversation.remoteExtra.keepOffsetY;
            useKeep = true;
        }
    }
    if(!useKeep && newMsgCount == 1) { // 如果只有一条新消息则使用预览orderSeq设置为最新的
        self.messageListView.browseToOrderSeq = self.currentConversation.lastMessage.orderSeq;
    }
    if(self.messageListView.browseToOrderSeq == 0) {
        self.messageListView.browseToOrderSeq = self.currentConversation.lastMessage.orderSeq;
    }
    if(keepOrderSeq>0) {
        self.messageListView.keepPosition =  [WKConversationPosition orderSeq:keepOrderSeq offset:(int)keepOffSetY];
    }
    
    if(self.locationAtOrderSeq!=0) { // 传过来的定位orderSeq最优先
        CGFloat offset = -self.input.lim_height - 40.0f;
        self.messageListView.needPositionReminder = true;
        self.messageListView.keepPosition = [WKConversationPosition orderSeq:self.locationAtOrderSeq offset:offset];
    }
}

-(void) initMessageListParam {
    self.messageListView.channel = self.channel;
    self.messageListView.dataProvider = self.messageListDataProviderImp;
    if(self.currentConversation) {
        self.messageListView.newMsgCount = self.currentConversation.unreadCount;
        self.messageListView.reminders = self.currentConversation.reminders;
        if(self.currentConversation.lastMessage) {
            if(self.currentConversation.lastMessage.isDeleted) {
                WKMessage *lastMsg = [[WKSDK shared].chatManager getLastMessage:self.channel];
                if(lastMsg) {
                    self.messageListView.lastMessage =  [[WKMessageModel alloc] initWithMessage:lastMsg];
                }
            }else {
                self.messageListView.lastMessage = [[WKMessageModel alloc] initWithMessage:self.currentConversation.lastMessage];
            }
            
        }
    }
    [self calcKeepPositionAndBrowseToOrderSeq]; // 计算保持位置
}

- (void)scrollToBottomOnMain:(BOOL)animation{
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.messageListView scrollToBottom:animation];
        
    });
}


- (WKConversationContextImpl*)conversationContext {
    if(!_conversationContext) {
        _conversationContext = [[WKConversationContextImpl alloc] initWithChannel:self.channel conersationView:self conversationVM:self.conversationVM];
    }
    return _conversationContext;
}


-(WKMessageListDataProviderImp*) messageListDataProviderImp {
    if(!_dataProvider) {
        WKMessageListDataProviderImp *dataProvider = [[WKMessageListDataProviderImp alloc] initWithChannel:self.channel conversationContext:self.conversationContext];
        _dataProvider = dataProvider;
    }
    return _dataProvider;
}
- (WKConversation *)currentConversation {
    if(!_currentConversation) {
        _currentConversation = [[WKSDK shared].conversationManager getConversation:self.channel];
    }
    return _currentConversation;
}


- (WKConversationTopView *)topView {
    if(!_topView) {
        _topView = [[WKConversationTopView alloc] initWithFrame:CGRectMake(0.0, 0.0f, self.lim_width, 80.0f)];
        _topView.backgroundColor =[UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.4f];
    }
    return _topView;
}

- (WKMessageListView *)messageListView {
    if(!_messageListView) {
        __weak typeof(self) weakSelf = self;
        _messageListView = [[WKMessageListView alloc] initWithFrame:CGRectMake(0.0f,0.0f,self.lim_width, self.lim_height)];
        _messageListView.onContentViewClick = ^{
            [weakSelf.conversationContext endEditing];
        };
    }
    return _messageListView;
}


// 恢复草稿
-(void) recoveryDraft {
    if(!self.currentConversation) {
        return;
    }
    if([self hasDraft]) {
        [self.conversationContext inputSetText:self.currentConversation.remoteExtra.draft];
        self.keepKeyboard = true;
    }
}
-(BOOL) hasDraft {
    if(!self.currentConversation) {
        return false;
    }
    if(self.currentConversation.remoteExtra.draft && ![self.currentConversation.remoteExtra.draft isEqualToString:@""]) {
        return true;
    }
    return false;
}

-(void) sendTyping {
    WKLogDebug(@"输入中...");
    [self.conversationVM typing];
}


- (void)setMultipleOn:(BOOL)multipleOn {
    [self setMultipleOn:multipleOn selectedMessage:nil];
}

// 设置多选模式
-(void) setMultipleOn:(BOOL)multiple selectedMessage:(WKMessageModel * _Nullable)messageModel {
    // 先取消所有选中的
    [self.messageListView setMultipleOn:multiple selectedMessage:messageModel];
    
    __weak typeof(self) weakSelf = self;
    _multipleOn = multiple;
    if(multiple) {
        [self.input endEditing];
    }
    // 隐藏输入面板
    [self.input setHidden:multiple animation:YES animationBlock:^{
        [weakSelf showMultiplePanel:multiple];
    }];
    
    if(self.onMultiple) {
        self.onMultiple(multiple);
    }
   
}


// 是否显示多选面板
-(void) showMultiplePanel:(BOOL) show{
    if(show) {
        [self addSubview:self.multiplePanel];
        [self layoutSubviews];
    }else{
        [self.multiplePanel removeFromSuperview];
        [self layoutSubviews];
       
    }
}



- (WKMultiplePanel *)multiplePanel {
    if(!_multiplePanel) {
        CGFloat safeBottom;
        if (@available(iOS 11.0, *)) {
            safeBottom = [[UIApplication sharedApplication].keyWindow safeAreaInsets].bottom;
            _multiplePanel = [[WKMultiplePanel alloc] initWithFrame:CGRectMake(0.0f, WKScreenHeight, WKScreenWidth, self.input.contentViewMinHeight+safeBottom)];
            _multiplePanel.delegate = self;
            _multiplePanel.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        }
    }
    return _multiplePanel;
}

// 禁言
-(UIView*) forbiddenView {
    if(!_forbiddenView) {
        CGFloat safeBootom =0.0f;
        if (@available(iOS 11.0, *)) {
            UIEdgeInsets safeArea = [[UIApplication sharedApplication] keyWindow].safeAreaInsets;
             safeBootom =safeArea.bottom;
            
        }
         CGFloat offsetHeight = safeBootom;
        CGFloat height = 50.0f;
        _forbiddenView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.lim_height, self.lim_width, height+safeBootom)];
        [_forbiddenView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        _forbiddenView.hidden = YES;
        self.forbiddenTitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 5.0f, _forbiddenView.lim_width - 20.0f, 34.0f)];
        self.forbiddenTitleLbl.font = [UIFont systemFontOfSize:15.0f];
        [self.forbiddenTitleLbl setTextColor:[UIColor grayColor]];
        [self.forbiddenTitleLbl setTextAlignment:NSTextAlignmentCenter];
        self.forbiddenTitleLbl.layer.borderWidth = 0.5f;
        self.forbiddenTitleLbl.layer.masksToBounds = YES;
        self.forbiddenTitleLbl.layer.cornerRadius = 6.0f;
        [self.forbiddenTitleLbl.layer setBorderColor:[WKApp shared].config.lineColor.CGColor];
        
        self.forbiddenTitleLbl.lim_top = (_forbiddenView.lim_height-safeBootom) /2.0f - self.forbiddenTitleLbl.lim_height/2.0f;
        [_forbiddenView addSubview:self.forbiddenTitleLbl];
    }
    return _forbiddenView;
}

-(void) setGroupForbidden:(BOOL)on title:(NSString*)title{
    [self.forbiddenView setHidden:!on];
    if(on) {
        self.forbiddenTitleLbl.text = title;
        [self.messageListView animateMessageWithBlock:^{
            [self layoutSubviews];
        }];
    }else {
        [self.messageListView animateMessageWithBlock:^{
            [self layoutSubviews];
        }];
    }
    
}

-(void) destoryForbiddenTimer {
    [self.forbiddenTimer invalidate];
    self.forbiddenTimer = nil;
}

-(void) setGroupForbidden:(BOOL)on{
    
    [self destoryForbiddenTimer];
   
    
    NSInteger forbiddenExpirTime = [self.conversationVM.memberOfMe.extra[@"forbidden_expir_time"] integerValue];
    if(on && forbiddenExpirTime>0) {
       
        NSInteger second = forbiddenExpirTime - [[NSDate date] timeIntervalSince1970];
        if(second<=0) {
            [self setGroupForbidden:on title:LLang(@"禁言中")];
            return;
        }
        NSString *forbidderStr = [self getForbidderStr];
        __weak typeof(self) weakSelf = self;
        self.forbiddenTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:YES block:^(NSTimer * _Nonnull timer) {
            NSString *forbiddeStr = [weakSelf getForbidderStr];
            if(![forbiddeStr isEqualToString:@""]) {
                [weakSelf setGroupForbidden:YES title:[weakSelf getForbidderStr]];
            }else {
                [timer invalidate];
                [weakSelf setGroupForbiddenIfNeed];
            }
            
        }];
        [self setGroupForbidden:on title:forbidderStr];
    }else {
        [self setGroupForbidden:on title:LLang(@"全员禁言中")];
    }
   
}

-(NSString*) getForbidderStr {
    NSInteger forbiddenExpirTime = [self.conversationVM.memberOfMe.extra[@"forbidden_expir_time"] integerValue];
    NSInteger second = forbiddenExpirTime - [[NSDate date] timeIntervalSince1970];
    if(second<=0) {
        return @"";
    }
    
   NSString *timeStr =  [WKTimeTool formatCountdownTime:forbiddenExpirTime];
    
    return [NSString stringWithFormat:LLang(@"禁言中（%@）"),timeStr];
}

-(BOOL) setGroupForbiddenIfNeed {
    if(self.conversationVM.memberRole == WKMemberRoleCreator || self.conversationVM.memberRole == WKMemberRoleManager) {
        [self setGroupForbidden:NO];
        return true;
    }else {
        if(self.conversationVM.channelInfo) {
            NSInteger forbiddenExpirTime =  self.conversationVM.forbiddenExpirTime;
            BOOL forbidden = self.conversationVM.channelInfo.forbidden || forbiddenExpirTime > 0;
            [self setGroupForbidden:forbidden];
            return true;
        }
    }
    return false;
}


#pragma mark - 输入框

-(WKConversationInputPanel*) input{
    if(!_input){
        _input = [[WKConversationInputPanel alloc] initWithConversationContext:self.conversationContext];
        _input.delegate = self;
        [_input updateAndLayoutTextViewRightView];
//        _input.conversationContext = self;
        _input.disableAutoTop = true;
        //        _input.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
//        [_input setBackgroundColor: ColorSessionMessageInputBar];
        
    }
    return _input;
}

#pragma mark -- WKConversationInputPanelDelegate

// 发送文本消息
- (void)inputPanelSend:(WKConversationInputPanel *)inputPanel text:(NSString*)text {

    [self layoutSubviews];
    [self.conversationContext sendTextMessage:text];
    [self.conversationContext hideMentionUsers];
    [self.conversationContext callConversationInputChangeDelegate];
    
    
}
// 发送消息
-(void) inputPanel:(WKConversationInputPanel *)inputPanel sendMessage:(WKMessageContent*)content {
   
    [self.conversationContext sendMessage:content];
}

- (void)inputPanelTyping:(WKConversationInputPanel *)inputPanel {
    if(self.editMessage) { // 编辑消息不发送typing消息
        return;
    }
    if( [[NSDate date] timeIntervalSince1970] - self.lastTypingTime > 5) {
         [self sendTyping];
         self.lastTypingTime = [[NSDate date] timeIntervalSince1970];
    }
   
}

// 面板弹起或收起
- (void)inputPanelUpOrDown:(WKConversationInputPanel *)inputPanel up:(BOOL)up{
    
    [self.messageListView stopScrollingAnimation];
    [self layoutSubviews];
    
   
    
//    [self adjustRobotMenusIfNeed];
    [self.conversationContext layoutMentionUserHandle];
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(conversationView:inputPanelUpOrDown:)]) {
        [self.delegate conversationView:self inputPanelUpOrDown:up];
    }
   
}

// 输入框高度改变
- (void)inputPanelWillChangeHeight:(WKConversationInputPanel *)inputPanel height:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve{
    
    [self.messageListView animateMessageWithBlock:^{
        [self layoutSubviews];
    }];
    
}


// 结束触发@
-(void) inputPanelMentionEnd:(WKConversationInputPanel *)inputPanel {
    if(self.channel.channelType == WK_PERSON) {
        return;
    }
    WKLogDebug(@"inputPanelMentionEnd");
    [self.conversationContext hideMentionUsers];
    
    
}

// @后面的输入字符
- (void)inputPanel:(WKConversationInputPanel *)inputPanel mentionSearch:(NSString *)keyword {
    if(self.channel.channelType == WK_PERSON) {
        return;
    }
    WKLogDebug(@"mentionSearch--%@",keyword);
    [self.conversationContext showMentionUsers:keyword];
}

- (void)inputPanel:(WKConversationInputPanel *)inputPanel textChange:(NSString *)text {
    [self.conversationContext callConversationInputChangeDelegate];
}



#pragma mark -- WKMultiplePanelDelegate


// 多选panel
- (void)multiplePanel:(WKMultiplePanel *)panel action:(WKMultipAction)action {
    if(action == WKMultipActionDelete) { // 删除
        NSArray *selectedMessages = [self.messageListView getSelectedMessages];
        if(selectedMessages && selectedMessages.count>0) {
            [[WKMessageManager shared] deleteMessages:selectedMessages];
            [self setMultipleOn:NO];
        }
    }else if(action == WKMultipActionForward) { // 逐条转发
        [self multipActionForward];
    }else if(action == WKMultipActionMergeForward) { // 合并转发
        [self multipActionMergeForward];
    }
}

// 逐条转发
-(void) multipActionForward {
    WKConversationListSelectVC *vc = [WKConversationListSelectVC new];
    vc.title = LLang(@"选择一个聊天");
    NSArray *selectedMessages = [self.messageListView getSelectedMessages];
    __weak typeof(self) weakSelf = self;
    [vc setOnSelect:^(WKChannel * _Nonnull channel) {
        [[WKNavigationManager shared] popToViewController:weakSelf.lim_viewController animated:YES];
        for (WKMessageModel *messageModel  in selectedMessages) {
            if([[WKApp shared] allowMessageForward:messageModel.contentType]) { // 如果允许转发则直接转发
                if([weakSelf.channel isEqual:channel]) {
                    [weakSelf.conversationContext forwardMessage:messageModel.content];
                }else{
                    [[WKSDK shared].chatManager forwardMessage:messageModel.content channel:channel];
                }
                
            }else{ // 如果不允许转发，则将变成文本消息转发
                WKTextContent *textContent = [[WKTextContent alloc] initWithContent:[messageModel.content conversationDigest]];
                if([weakSelf.channel isEqual:channel]) {
                    [weakSelf.conversationContext forwardMessage:textContent];
                }else{
                    [[WKSDK shared].chatManager forwardMessage:textContent channel:channel];
                }
                
            }
           
        }
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];
        [weakSelf setMultipleOn:NO];
        
    }];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

// 合并转发
-(void) multipActionMergeForward {
    __weak typeof(self) weakSelf = self;
    WKConversationListSelectVC *vc = [WKConversationListSelectVC new];
    vc.title = LLang(@"选择一个聊天");
    NSArray *selectedMessages = [self.messageListView getSelectedMessages];
    [vc setOnSelect:^(WKChannel * _Nonnull channel) {
        [[WKNavigationManager shared] popToViewController:weakSelf.lim_viewController animated:YES];
        
        NSMutableArray *msgs = [NSMutableArray array];
        NSMutableArray<NSDictionary*> *userDicts = [NSMutableArray array];
        for (WKMessageModel *messageModel  in selectedMessages) {
            [msgs addObject:messageModel.message];
            bool hasUser = false;
            for (NSDictionary *userDict in userDicts) {
                if([messageModel.fromUid isEqualToString:userDict[@"uid"]]) {
                    hasUser = true;
                    break;
                }
            }
            if(!hasUser) {
                NSString *name = messageModel.from?messageModel.from.name:@"";
                [userDicts addObject:@{@"uid":messageModel.fromUid?:@"",@"name":name}];
            }
        }
        [msgs sortUsingComparator:^NSComparisonResult(WKMessageModel  *obj1, WKMessageModel *obj2) {
            if(obj1.timestamp<obj2.timestamp) {
                return NSOrderedAscending;
            }
            if(obj1.timestamp == obj2.timestamp) {
                return NSOrderedSame;
            }
            return NSOrderedDescending;
        }];
        
        WKMergeForwardContent *content = [WKMergeForwardContent msgs:msgs users:userDicts channelType:weakSelf.channel.channelType];
        if([weakSelf.channel isEqual:channel]) {
            [weakSelf.conversationContext sendMessage:content];
        }else {
            [[WKSDK shared].chatManager sendMessage:content channel:channel];
        }
       
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送成功")];
        [weakSelf setMultipleOn:NO];
        
    }];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

@end
