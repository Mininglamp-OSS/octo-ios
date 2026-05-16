// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConversationInputPanel.m
//  Session
//
//  Created by tt on 2018/9/29.
//


#import "WKConversationInputPanel.h"
#import "WKGrowingTextView.h"
#import "WKConversationPanel.h"
#import "UIView+WK.h"
#import "WKConstant.h"
#import "WKCommon.h"
#import "WKSessionPanelProto.h"
#import "WKInputChangeTextRespondProto.h"
#import "WKResource.h"
#import "WKApp.h"
#import "Mp3Recorder.h"
#import "UIView+WKCommon.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKInputMentionCache.h"
#import "WKPanel.h"
#import "WKPanelFuncItemProto.h"
#import "WKFuncItemButton.h"
#import "WuKongBase.h"
#import "WKSendButton.h"
#import "WKFuncGroupView.h"
#import "WKHoldToTalkManager.h"
#import <WuKongIMSDK/WKChannelMemberDB.h>
#import "WKMessageModel.h"
#define  WKiPhoneX (WKScreenWidth == 375.f && WKScreenHeight == 812.f ? YES : NO)

#define WKConversationInputHeight 36.0f // 输入框高度
#define WKConversationFuncGroupViewHeight 50.0f // 输入框下面的功能组的视图高度

@interface WKConversationInputPanel()<WKGrowingTextViewDelegate, WKHoldToTalkManagerDelegate, UITableViewDelegate, UITableViewDataSource>{
    //    CGFloat _inputPanelBorder;
    BOOL _noFollowKeyboradHeight; // 不追随键盘高度
}

//@property(nonatomic,assign) CGFloat height;


// 工具栏中间视图
@property(nonatomic,strong) WKFuncGroupView *funcGroupView;
// 消息工具栏
@property(nonatomic,strong) UIView *messageToolBar;

@property(nonatomic,strong) UIView *contentView;

@property(nonatomic) CGFloat messageToolBarMaxHeight; // 消息栏最大高度
// bar 的按钮
//@property(nonatomic,strong) UIView *rightItemContainer; // 右边Button的容器
// 面板相关

@property(nonatomic)  CGFloat panelHeight; // 面板高度（不包含消息输入栏）
@property(nonatomic,strong) NSArray<id<WKInputChangeTextRespondProto>> *inputChangeTextResponds; // 输入框文本改变响应链


@property(nonatomic,assign) CGFloat currentInputHeight; // 当前输入框高度



@property(nonatomic,strong) WKSendButton *sendButton;

@property(nonatomic,assign) BOOL mentionStart; // 是否开始@

@property(nonatomic,strong) NSArray<UIView*> *textViewRights;

@property(nonatomic,strong) WKHoldToTalkManager *holdToTalkManager;

// BotFather 命令联想
@property(nonatomic,strong) UIView *cmdSuggestView;
@property(nonatomic,strong) UITableView *cmdSuggestTable;
@property(nonatomic,strong) NSArray<NSDictionary *> *cmdSuggestData; // @{@"cmd":..., @"desc":...}
@property(nonatomic,strong) NSArray<NSDictionary *> *cmdSuggestFiltered;

@end

@implementation WKConversationInputPanel

-(WKConversationInputPanel*) initWithConversationContext:(id<WKConversationContext>)context {
    self = [super init];
    if(!self) return nil;
    self.conversationContext = context;
    [self setupUI];
    
    return self;
}



-(void) setupUI {
    
    [self addKeyboardListen]; // 这里也必须添加键盘通知，要不然有草稿的时候键盘弹起不会触发监听事件

   
    self.layer.shadowOffset = CGSizeMake(0.0f, -1.0f);
    self.layer.shadowOpacity = 0.6f;
    
    self.currentInputHeight = WKConversationInputHeight;
    
     //获取输入框改变响应链
    _inputChangeTextResponds = [[WKApp shared] invokes:WKPOINT_CATEGORY_CONVERSATION_INPUT_TEXT_RESPOND param:nil];
    if(_inputChangeTextResponds) {
        [_inputChangeTextResponds enumerateObjectsUsingBlock:^(id<WKInputChangeTextRespondProto>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.conversationContext = self.conversationContext;
        }];
    }
    
    
    _contentViewMinHeight = WKConversationInputHeight + WKConversationFuncGroupViewHeight +10.0f;
    
    [self addSubview:self.contentView];
    
    [self.contentView addSubview:self.messageToolBar];
    
    [self addSubview:self.conversationPanel];
    
    [self.messageToolBar addSubview:self.menusBtn];
    [self.messageToolBar addSubview:self.sendButton];
    
    [self.messageToolBar addSubview:self.voiceToggleBtn];
    [self.messageToolBar addSubview:self.holdToTalkBtn];
    [self.messageToolBar addSubview:self.textView];
    [self.messageToolBar addSubview:self.funcGroupView];


    [self reloadInputPanelFrame];
    [self layoutContentView];
    
    
}
// 添加和布局文本框右边视图
-(void) updateAndLayoutTextViewRightView {
    self.textViewRights = [[WKApp shared] invokes:WKPOINT_CATEGORY_TEXTVIEW_RIGHTVIEW param:@{@"context":self.conversationContext}];
    [self.textViewRightView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    if(!self.textViewRights || self.textViewRights.count==0) {
        [self.textView setRightView:nil];
        return;
    }
    self.textViewRightView.lim_height = self.textView.lim_height - 4.0f;
    self.textViewRightView.lim_top = 2.0f;
    self.textViewRightView.lim_width = 0.0f;
    UIView *preView;
    for (UIView *rightView in self.textViewRights) {
        rightView.lim_centerY_parent = self.textViewRightView;
        if(preView) {
            rightView.lim_left = preView.lim_right;
        }
        [self.textViewRightView addSubview:rightView];
        preView = rightView;
    }
    if(preView) {
        self.textViewRightView.lim_width = preView.lim_right;
    }
    
    [self.textView setRightView:self.textViewRightView];
    
}

- (UIView *)textViewRightView {
    if(!_textViewRightView) {
        _textViewRightView = [[UIView alloc] init];
    }
    return _textViewRightView;
}


-(void) resetCurrentInputHeight {
    self.textView.internalTextView.lim_size = self.textView.lim_size;
   CGFloat mHeight = [self.textView measureHeight];
    CGFloat currentHeight = MIN(mHeight, self.textView.maxHeight);
    self.currentInputHeight = MAX(WKConversationInputHeight, currentHeight);
}
//
//-(void) resetMoreItemAndTextView{
//    self.moreBtnItem.lim_left = itemSpace;
//    self.textView.lim_left = itemWidth+itemSpace*2;
//}

-(void) resetInputHeight {
   self.currentInputHeight = WKConversationInputHeight;
}
#pragma mark -- 面板相关
-(WKConversationPanel*) conversationPanel {
    if(!_conversationPanel) {
        _conversationPanel = [[WKConversationPanel alloc] init];
    }
    return _conversationPanel;
}


#pragma mark - 布局

CGFloat itemSpace = 10.0f;
-(void) layoutSubviews{
    [super layoutSubviews];
    [self reloadInputPanelFrame];
    [self layoutContentView];
    
    [self.messageToolBar setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    [self.conversationPanel setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    self.textView.internalTextView.backgroundColor = [UIColor clearColor];
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.layer.shadowColor = [UIColor colorWithRed:15.0f/255.0f green:15.0f/255.0f blue:15.0f/255.0f alpha:1.0].CGColor;
        [self.textView setBackgroundColor:[UIColor colorWithRed:38.0f/255.0f green:38.0f/255.0f blue:38.0f/255.0f alpha:1.0]];
        [self.holdToTalkBtn setBackgroundColor:[UIColor colorWithRed:38.0f/255.0f green:38.0f/255.0f blue:38.0f/255.0f alpha:1.0]];
    }else{
        self.layer.shadowColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0].CGColor;
        [self.textView setBackgroundColor:[UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0]];
        [self.holdToTalkBtn setBackgroundColor:[UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0]];
    }
    

}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

-(void) layoutContentView{
    
//    UIEdgeInsets inputFieldInsets = [self inputFieldInsets];
    // messageToolBar
    CGFloat contentHeight = self.currentContentHeight;
    
    CGFloat leftSpace = 10.0f;

    // messageToolBar
    self.contentView.lim_width = self.lim_width;
    self.contentView.lim_height = contentHeight;

    self.messageToolBar.lim_size = self.contentView.lim_size;
    if(self.topView) {
        self.messageToolBar.lim_top = self.topView.lim_bottom;
    }else {
        self.messageToolBar.lim_top = 0.0f;
    }

    // voiceToggleBtn
    CGFloat voiceToggleBtnLeft = leftSpace;
    if(self.showMenusBtn) {
        self.menusBtn.lim_left = leftSpace;
        voiceToggleBtnLeft = self.menusBtn.lim_right + 6.0f;
    }
    self.voiceToggleBtn.lim_left = voiceToggleBtnLeft;
    self.voiceToggleBtn.lim_top = 10.0f + (self.currentInputHeight / 2.0f - self.voiceToggleBtn.lim_height / 2.0f);

    // textView / holdToTalkBtn
    CGFloat inputLeft = self.voiceToggleBtn.lim_right + 8.0f;
    self.textView.lim_top = 10.0f;
    CGFloat textViewWidth = self.lim_width - inputLeft - 10.0f;

    [self.sendButton layoutSubviews];
    CGFloat sendLeftSpace = 10.0f;
    if(self.sendButton.show && !self.isVoiceMode) {
        textViewWidth -= (self.sendButton.lim_width+sendLeftSpace);
    }

    self.textView.lim_left = inputLeft;
    self.textView.lim_width = textViewWidth;
    self.textView.lim_height = self.currentInputHeight;
    self.textView.lim_top = 10.0f;

    // holdToTalkBtn（语音模式下与textView位置对齐）
    self.holdToTalkBtn.lim_left = inputLeft;
    self.holdToTalkBtn.lim_width = self.lim_width - inputLeft - 10.0f;
    self.holdToTalkBtn.lim_height = WKConversationInputHeight;
    self.holdToTalkBtn.lim_top = 10.0f;

    if(self.showMenusBtn) {
        self.menusBtn.lim_top = self.textView.lim_top + ( self.textView.lim_height/2.0f - self.menusBtn.lim_height/2.0f);
    }

    self.sendButton.lim_top = self.textView.lim_bottom - self.sendButton.lim_height;
    self.sendButton.lim_left = self.textView.lim_right + sendLeftSpace;
   
   

    self.funcGroupView.lim_top = self.textView.lim_bottom;
    if(self.funcGroupView.startScroll) {
        self.funcGroupView.lim_top = self.textView.lim_bottom - (self.funcGroupView.lim_height - WKConversationFuncGroupViewHeight);
    }else {
        self.funcGroupView.lim_top = self.textView.lim_bottom;
    }
    self.funcGroupView.lim_left = 0;
//    // funcGroupView
//    CGFloat funcLeftSpace = 10.0f;
//    CGFloat funcRightSpace = 10.0f;
//    self.funcGroupView.lim_height = WKConversationFuncGroupViewHeight;
//    self.funcGroupView.lim_top = self.textView.lim_bottom;
//    self.funcGroupView.lim_left = funcLeftSpace;
//    self.funcGroupView.lim_width = self.lim_width - funcLeftSpace - funcRightSpace;
//
//    CGFloat itemLeftSpace =  (self.funcGroupView.lim_width - itemWidth*self.funcGroupView.subviews.count) / (self.funcGroupView.subviews.count-1);
//    for (NSInteger i = 0;i<self.funcGroupView.subviews.count;i++) {
//        UIView *subView = self.funcGroupView.subviews[i];
//        if(i==0) {
//             subView.lim_left =0;
//        }else {
//            subView.lim_left = self.funcGroupView.subviews[i-1].lim_right+itemLeftSpace;
//        }
//
//        subView.lim_top =  self.funcGroupView.lim_height/2.0f - subView.lim_height/2.0f;
//    }
    
    self.conversationPanel.lim_top = self.contentView.lim_bottom;
    
}
- (UIEdgeInsets)inputFieldInsets
{
    static UIEdgeInsets insets;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        insets = UIEdgeInsetsMake(5.0f, 0.0f, 5.0f, 0.0f);
    });
    
    return insets;
}

#pragma mark - 消息栏相关

-(UIView*) messageToolBar {
    if(!_messageToolBar) {
        _messageToolBar = [[UIView alloc] init];
//        _messageToolBar.layer.borderWidth = 0.5;
//        _messageToolBar.layer.borderColor = [UIColor lightGrayColor].CGColor;
    }
    return _messageToolBar;
}

- (UIView *)contentView {
    if(!_contentView) {
        _contentView = [[UIView alloc] init];
    }
    return _contentView;
}

-(WKFuncGroupView*) funcGroupView {
    if(!_funcGroupView) {
        CGFloat scaleZoom = 1.8f;
        _funcGroupView = [[WKFuncGroupView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, WKConversationFuncGroupViewHeight) inputPanel:self];
        _funcGroupView.scaleZoom = scaleZoom;
        __weak typeof(self) weakSelf = self;
        [_funcGroupView setOnLayout:^{
            [weakSelf layoutContentView];
        }];
    }
    return _funcGroupView;
}

-(CGFloat) contentViewChangeHeight {
    
    return [self currentContentHeight] - _contentViewMinHeight;
}

#pragma mark - Panel draw


- (WKMenusBtn *)menusBtn {
    if(!_menusBtn) {
        _menusBtn = [[WKMenusBtn alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0f, 25.0f)];
//        _menusBtn.backgroundColor = [WKApp shared].config.themeColor;
        _menusBtn.hidden = YES;
        _menusBtn.layer.masksToBounds = YES;
//        _menusBtn.layer.cornerRadius = _menusBtn.lim_height/2.0f;
    }
    return _menusBtn;
}

- (WKSendButton *)sendButton {
    if(!_sendButton) {
        CGSize size = CGSizeMake(32.0f, 32.0f);
        _sendButton = [[WKSendButton alloc] initWithFrame:CGRectMake(self.messageToolBar.lim_width, 0.0f, size.width, size.height)];
        __weak typeof(self) weakSelf = self;
        [_sendButton setOnSend:^{
            [weakSelf inputSendFinished];
        }];
    }
    return _sendButton;
}

- (void)setShowMenusBtn:(BOOL)showMenusBtn {
    _showMenusBtn = showMenusBtn;
    self.menusBtn.hidden = !showMenusBtn;
    
    [self layoutSubviews];
}

-(WKGrowingTextView*) textView {
    if(!_textView) {
        _textView = [[WKGrowingTextView alloc] init];
        _textView.lim_height =WKConversationInputHeight;
        
        
        _textView.layer.masksToBounds = YES;
        _textView.layer.cornerRadius = 15.0f;
//        _textView.layer.borderWidth = 0.5;
//        _textView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        _textView.tag = 99;

        _textView.delegate = self;
    }
    return _textView;
}

// 切换更多面板
-(void) switchPanel:(NSString*)pointId{
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(switchPanel:pointID:)]) {
        [self.delegate switchPanel:self pointID:pointId];
    }
    
    if(![self keyboardIsUp]&&self.panelHeight>0){
        if(pointId && [pointId isEqualToString:[self.conversationPanel currentPanelPointId]]) { // 如果是点击相同的按钮才会弹起键盘
            [self.textView becomeFirstResponder];
            return;
        }
    }
    _noFollowKeyboradHeight = true;
    if(self.conversationPanel){
        self.conversationPanel.conversationContext = self.conversationContext;
    }
    
    if([self.conversationPanel switchPanel:nil pointId:pointId]){
        if(![self messageToolBarIsUp]){ // 如果输入栏没弹起 就先调整大小 这样面板出现的时候感觉像一个整体
            [self.conversationPanel adjustPanel:self.panelHeight keyboardHeight:self.keyboardHeight];
        }
        
        self.panelHeight = [self.conversationPanel currentPanelHeight];
        [WKCommon commonAnimation:^{
            [self.textView endEditing:YES];
            [self.conversationPanel adjustPanel:self.panelHeight keyboardHeight:self.keyboardHeight];
            [self reloadInputPanelFrame];
            [self inputPanelUpOrDown];
        }];
    }
    
}

-(BOOL) becomeFirstResponder {
   return [self.textView becomeFirstResponder];
}

-(void) endEditing {
    if(self.panelHeight>0){
        self.panelHeight = 0;
        [self keyboardAnimation:^{
            [self.textView endEditing:YES];
            [self reloadInputPanelFrame];
            [self.conversationPanel adjustPanel:self.panelHeight keyboardHeight:self.keyboardHeight];
            [self inputPanelUpOrDown];
        }];
        
    }else if([self keyboardIsUp]){
        [self.textView endEditing:YES];
    }
}

#pragma mark - 消息栏位置计算
-(void) reloadInputPanelFrame {
    self.lim_size = CGSizeMake(WKScreenWidth, [self currentContentHeight]+[self currentPanelHeight]);
    if(!self.disableAutoTop) {
        self.lim_top =  [self currentMessageToolBarY];
    }

    
    if(self.panelHeight<=0) {
        [self unSelectedFuncItems];
    }else if([self keyboardIsUp]) {
         [self unSelectedFuncItems];
    }

}

// 当前输入栏的Y坐标
-(CGFloat) currentMessageToolBarY{
//    CGRect statusRect = [[UIApplication sharedApplication] statusBarFrame];
//    CGFloat navHeight = self.lim_viewController.navigationController.navigationBar.frame.size.height;
//    CGFloat y =  WKScreenHeight -navHeight - statusRect.size.height -[self currentInputPanelHeight];
     CGFloat y =  WKScreenHeight -[self currentInputPanelHeight];
    
    return y;
}

// 当前整个输入面板的高度
-(CGFloat) currentInputPanelHeight{
    return [self currentPanelHeight]+[self currentContentHeight]-[self bottomAdjustOffset];
}

// 当前消息栏高度
-(CGFloat) currentContentHeight{
    CGFloat topViewBottom = 0.0f;
    if(self.topView) {
        topViewBottom = self.topView.lim_bottom;
    }
    CGFloat height = MAX(self.currentInputHeight + WKConversationFuncGroupViewHeight +10.0f,_contentViewMinHeight);
    return height+topViewBottom;
}
// 当前面板的高度
-(CGFloat) currentPanelHeight{
    if([self keyboardIsUp]) {
        return self.keyboardHeight+[self bottomAdjustOffset];
    }
    
    return self.panelHeight+[self bottomOffset];
}

// 底部偏移距离
-(CGFloat) bottomOffset{
    
    return [self safeBottom]+[self bottomAdjustOffset];
}

// 人为调整的大小
-(CGFloat) bottomAdjustOffset{
    return WKiPhoneX? 0.0f:0.0f;
}

#pragma mark - keyboard (键盘相关)

// 键盘是否弹起
-(BOOL) keyboardIsUp {
    return self.keyboardHeight>0;
}

-(void) setHidden:(BOOL)hidden animation:(BOOL)animation animationBlock:(void(^)(void))animationBlock{
    __weak typeof(self) weakSelf = self;
    if(hidden) {
        [self animateInputWithBlock:^{
            if(!weakSelf.disableAutoTop) {
                weakSelf.lim_top = WKScreenHeight;
            }
            
            weakSelf.hidden = YES;
            if(animationBlock) {
                animationBlock();
            }
        }];
    }else{
        weakSelf.hidden = NO;
        [self animateInputWithBlock:^{
            [weakSelf reloadInputPanelFrame];
            if(animationBlock) {
                animationBlock();
            }
        }];
    }
    
}
// 消息工具栏弹起
-(BOOL) messageToolBarIsUp{
    if([self keyboardIsUp]){
        return true;
    }
    if(self.panelHeight>0){
        return true;
    }
    return false;
}

-(void) keyboardAnimation:(void(^)(void)) block{
    
    [WKCommon commonAnimation:^{
        if(block){
            block();
        }
    }];
}

- (void)configureWithKeyboardNotification:(NSNotification *)notification {
    CGRect keyboardBeginFrame = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect keyboardBeginFrameInView = [self.superview convertRect:keyboardBeginFrame fromView:nil];
    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardEndFrameInView = [self.superview convertRect:keyboardEndFrame fromView:nil];
    CGRect keyboardEndFrameIntersectingView = CGRectIntersection(self.superview.bounds, keyboardEndFrameInView);
    
    CGFloat keyboardHeight = CGRectGetHeight(keyboardEndFrameIntersectingView);
    
    self.keyboardHeight =keyboardHeight;
    if(!_noFollowKeyboradHeight) {
        self.panelHeight = self.keyboardHeight;
    }else{
        _noFollowKeyboradHeight = false;
    }
    
    // Workaround for collection view cell sizes changing/animating when view is first pushed onscreen on iOS 8.
    if (CGRectEqualToRect(keyboardBeginFrameInView, keyboardEndFrameInView)) {
        [UIView performWithoutAnimation:^{
            NSLog(@"configureWithKeyboardNotification---->1");
//            [self reloadInputPanelFrame];
//            [self inputPanelUpOrDown];
        }];
        return;
    }
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [self reloadInputPanelFrame];
    if(self.keyboardHeight>0){
        NSLog(@"configureWithKeyboardNotification---->3 ->%0.2f -->%0.2f",self.panelHeight,self.keyboardHeight);
        [self.conversationPanel adjustPanel:self.panelHeight keyboardHeight:self.keyboardHeight];
    }
    [self inputPanelUpOrDown];
    [UIView commitAnimations];
    NSLog(@"configureWithKeyboardNotification---->2");
   

}


// 取消所有被选中的功能item
-(void) unSelectedFuncItems {
    [self.funcGroupView unSelectedItems];
}



// 键盘隐藏
- (void)keyboardWillHide:(NSNotification *)notification{
    [self configureWithKeyboardNotification:notification];
}

// 键盘显示
- (void)keyboardWillShow:(NSNotification *)notification{
    [self  unSelectedFuncItems];
    [self configureWithKeyboardNotification:notification];
}


//添加监听键盘
-(void)addKeyboardListen{
    [self removeKeyboardListen];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}
//移除监听
-(void)removeKeyboardListen{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
}

- (int)convertToByte:(NSString*)str {
    int strlength = 0;
    char* p = (char*)[str cStringUsingEncoding:NSUnicodeStringEncoding];
    for (int i=0 ; i<[str lengthOfBytesUsingEncoding:NSUnicodeStringEncoding] ;i++) {
        if (*p) {
            p++;
            strlength++;
        }
        else {
            p++;
        }
    }
    return (strlength+1)/2;
}

-(void) inputSendFinished {
    NSString *content = self.textView.text;
    if([WKApp shared].config.messageTextMaxBytes !=0) {
        if(content && [self convertToByte:content]>[WKApp shared].config.messageTextMaxBytes) {
            [self showTextToFileAlert:content];
            return;
        }
    }

    self.textView.text = @"";
    self.sendButton.show = NO;
    self.sendButton.hidden = YES;
    [self resetInputHeight];
    [self animateInputPanelChange:^{
        if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelSend:text:)]) {
            [self.delegate inputPanelSend:self text:content];
        }
    }];

}

/// 文本超出限制时弹窗提示，确认后转为 .txt 文件发送
-(void) showTextToFileAlert:(NSString *)text {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
        message:LLang(@"字数超出限制无法发送，是否需将消息转为文档发出？")
        preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:LLang(@"取消")
        style:UIAlertActionStyleCancel handler:nil];

    __weak typeof(self) weakSelf = self;
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:LLang(@"确认发送")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [weakSelf sendTextAsFile:text];
        }];

    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    [[WKNavigationManager shared].topViewController presentViewController:alert animated:YES completion:nil];
}

/// 将文本内容生成 .txt 文件并以文件消息发送
-(void) sendTextAsFile:(NSString *)text {
    // 用前10个字符作为文件名
    NSString *namePrefix = text.length > 10 ? [text substringToIndex:10] : text;
    // 移除文件名中的非法字符
    NSCharacterSet *illegal = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|\n\r\t"];
    namePrefix = [[namePrefix componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@""];
    if (namePrefix.length == 0) namePrefix = @"消息";
    NSString *fileName = [NSString stringWithFormat:@"%@.txt", namePrefix];

    // 写入临时文件
    NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WKTextToFile"];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *filePath = [tmpDir stringByAppendingPathComponent:fileName];
    [text writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    WKFileContent *fileContent = [WKFileContent initWithFileURL:fileURL];

    // 清空输入框
    self.textView.text = @"";
    self.sendButton.show = NO;
    [self resetInputHeight];

    // 通过 delegate 发送文件消息
    if (self.delegate && [self.delegate respondsToSelector:@selector(inputPanel:sendMessage:)]) {
        [self.delegate inputPanel:self sendMessage:fileContent];
    }
}

#pragma mark - UITextViewDelegate
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
//    if ([text isEqualToString:@"\n"]) {
//        NSString *content = textView.text;
//        if([WKApp shared].config.messageTextMaxBytes !=0) {
//            if(content && [self convertToByte:content]>[WKApp shared].config.messageTextMaxBytes) {
//                [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"发送的内容太长！")];
//                return NO;
//            }
//        }
//
//        textView.text = @"";
//        [self resetInputHeight];
//        if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelSend:text:)]) {
//            [self.delegate inputPanelSend:self text:content];
//        }
//        return NO;
//    }else
    if ([self isMention:text]) { // @功能
        [self triggerMentionStartIfNeed];
        
        return YES;
    } else  if ([text isEqualToString:@""] && range.length == 1 ) { // 删除
        NSString *willDeleteStr =  [self.textView.text substringWithRange:range];
        if([willDeleteStr isEqualToString:WKInputAtStartChar]) { /// @被删除了 说明@结束了
            [self triggerMentionEndIfNeed];
            return YES;
        }
         NSRange rangeForMention = [self delRangeForMention];
        if(rangeForMention.length>1) {
            [self triggerMentionEndIfNeed];
            if([self.delegate respondsToSelector:@selector(inputPanel:delMention:)]) {
                [self.delegate inputPanel:self delMention:rangeForMention];
            }
            [self inputDeleteText:rangeForMention];
            return NO;
        }
    }else if([text isEqualToString:@" "]) { // 空格 如果有@需要结束
        [self triggerMentionEndIfNeed];
    }
    
    if(_inputChangeTextResponds && _inputChangeTextResponds.count>0){
        BOOL allowChange = true;
        for(id<WKInputChangeTextRespondProto> inputChangeTextRespond in _inputChangeTextResponds){
            id<WKInputChangeRespondResult> result =  [inputChangeTextRespond shouldChangeTextInRange:range replacementText:text];
            if(result && !result.changeText) {
                allowChange = false;
            }
            if(result&&!result.next) {
                break;
            }
        }
        return allowChange;
    }
    return YES;
}

-(void) triggerMentionStartIfNeed {
    if(self.mentionStart) {
        return;
    }
    self.mentionStart = true;
    if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelMentionStart:)]) {
        [self.delegate inputPanelMentionStart:self];
    }
}
-(void) triggerMentionEndIfNeed {
    if(!self.mentionStart) {
        return;
    }
    self.mentionStart = false;
    if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelMentionEnd:)]) {
        [self.delegate inputPanelMentionEnd:self];
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    [self handleTextViewContentDidChange];
   
}

-(void) handleTextViewContentDidChange {
    NSString *text = self.textView.text;
    BOOL hasText = ![[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""];
    self.sendButton.show = hasText;
    self.sendButton.hidden = !hasText || self.isVoiceMode;
    [self animateInputPanelChange];
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanelTyping:)]) {
        [self.delegate inputPanelTyping:self];
    }
    
    if([text hasSuffix:WKInputAtStartChar]) {
        [self triggerMentionStartIfNeed];
    }
   
    if(![text containsString:@"@"]) {
        [self triggerMentionEndIfNeed];
    }else if(text.length>0){
        if([text hasSuffix:WKInputAtEndChar]) {
            [self triggerMentionEndIfNeed];
        }
    }
    if(self.mentionStart) {
        [self textChangeMentionCandidateIfNeeded];
    }
    
    // BotFather 命令联想
    [self updateCommandSuggestions:text];

    [[WKApp shared] invokes:WKPOINT_CATEGORY_CONVERSATION_INPUT_TEXT_CHANGE param:@{@"input":self}];

    if(self.delegate && [self.delegate respondsToSelector:@selector(inputPanel:textChange:)]) {
        [self.delegate inputPanel:self textChange:text];
    }
    
    
}

// 是否提及
-(BOOL) isMention:(NSString*)text {
    return [text isEqualToString:WKInputAtStartChar];
}

// 是否删除提及
- (NSRange)delRangeForMention {
    NSRange range = [self rangeForPrefix:WKInputAtStartChar suffix:WKInputAtEndChar];
    return range;
}


- (NSRange)rangeForPrefix:(NSString *)prefix suffix:(NSString *)suffix
{
    NSString *text = self.textView.text;
    NSRange range = [self inputSelectedRange];
    NSString *selectedText = range.length ? [text substringWithRange:range] : text;
    NSInteger endLocation = range.location;
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger index = -1;
    if ([selectedText hasSuffix:suffix]) {
        //往前搜最多20个字符，一般来讲是够了...
        NSInteger p = 20;
        for (NSInteger i = endLocation; i >= endLocation - p && i-1 >= 0 ; i--)
        {
            NSRange subRange = NSMakeRange(i - 1, 1);
            NSString *subString = [text substringWithRange:subRange];
            if ([subString compare:prefix] == NSOrderedSame)
            {
                index = i - 1;
                break;
            }
        }
    }
    return index == -1? NSMakeRange(endLocation - 1, 1) : NSMakeRange(index, endLocation - index);
}

// 获取输入中的@和后面的关键字
-(NSRange) inputingMentionRange {
    NSString *text = self.textView.text;
    NSRange range = [self inputSelectedRange];
//    NSString *selectedText = range.length ? [text substringWithRange:range] : text;
    NSInteger endLocation = range.location;
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    
    NSInteger index = -1;
    //往前搜最多20个字符，一般来讲是够了...
    NSInteger p = 20;
    for (NSInteger i = endLocation; i >= endLocation - p && i-1 >= 0 ; i--) {
        NSRange subRange = NSMakeRange(i - 1, 1);
        NSString *subString = [text substringWithRange:subRange];
        if([subString compare:WKInputAtEndChar] == NSOrderedSame) {
            return NSMakeRange(NSNotFound, 0);
        }
        if ([subString compare:WKInputAtStartChar] == NSOrderedSame) {
            index = i - 1;
            break;
        }
    }
    return index == -1? NSMakeRange(NSNotFound, 0) : NSMakeRange(index, endLocation - index);
}

// 替换正在输入中的@内容
-(BOOL) replaceInputingMention:(NSString*)value {
   NSRange mentionRange = [self inputingMentionRange];
    if(mentionRange.location == NSNotFound) {
        return false;
    }
    self.textView.text  = [self.textView.text stringByReplacingCharactersInRange:mentionRange withString:value];
    [self handleTextViewContentDidChange];
    return YES;
}

-(void) textChangeMentionCandidateIfNeeded {
   NSRange range = [self inputingMentionRange];
    if(range.location == NSNotFound) {
        return;
    }
    if([self.delegate respondsToSelector:@selector(inputPanel:mentionSearch:)]) {
        NSRange keywordRange = NSMakeRange(range.location + 1, range.length - 1);
        NSString *text = [self.textView.text substringWithRange:keywordRange];
        [self.delegate inputPanel:self mentionSearch:text];
    }
}

#pragma mark - WKGrowingTextViewDelegate


- (void)growingTextView:(WKGrowingTextView *)growingTextView willChangeHeight:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve{
//    UIEdgeInsets inputFieldInsets = [self inputFieldInsets];
//    CGFloat inputContainerHeight = MAX(_messageToolBarMinHeight, height);
    if(height < WKConversationInputHeight) {
        height = WKConversationInputHeight;
    }
    CGFloat currentHeight = MIN(height, self.textView.maxHeight);
    if(height!=self.currentInputHeight) {
//        self.currentMessageToolBarHeight +=( currentHeight - self.currentInputHeight);
        self.currentInputHeight = currentHeight;
        [self animateInputPanelChange];
        [self triggerInputPanelChangeEvent];
    }
    
}

#pragma mark - WKInputProto

- (void)sendMessage:(WKMessageContent *)content {
    [self.delegate inputPanel:self sendMessage:content];
}

/**
 往输入框插入文本
 */
-(void) inputInsertText:(NSString *)text{
    [self.textView insertText:text];
    [self handleTextViewContentDidChange];
    // 滚动到文本末尾
    dispatch_async(dispatch_get_main_queue(), ^{
        UITextView *tv = self.textView.internalTextView;
        if (tv.text.length > 0) {
            [tv scrollRangeToVisible:NSMakeRange(tv.text.length, 0)];
        }
    });
}

-(void) inputSetText:(NSString *)text {
    [self.textView setText:text];
    [self handleTextViewContentDidChange];
    // 滚动到文本末尾
    dispatch_async(dispatch_get_main_queue(), ^{
        UITextView *tv = self.textView.internalTextView;
        if (tv.text.length > 0) {
            [tv scrollRangeToVisible:NSMakeRange(tv.text.length, 0)];
        }
    });
}


/**
 删除范围内的文本
 
 @param range <#range description#>
 */
-(void) inputDeleteText:(NSRange)range{
    
    [self.textView deleteText:range];
    [self handleTextViewContentDidChange];
}


/**
 获取当前输入框的文本
 
 @return <#return value description#>
 */
-(NSString*) inputText{
    
    return self.textView.text;
}

-(NSRange) inputSelectedRange{
    
    return self.textView.selectedRange;
}


#pragma mark - 公开方法



-(void) adjustInput:(BOOL)animation{
    if(animation) {
        [self animateInputWithBlock:^{
            [self reloadInputPanelFrame];
        }];
    }else{
        [self reloadInputPanelFrame];
    }
}



- (void)setTopView:(UIView *)topView {
    [self setTopView:topView animateBlock:nil];
}

- (void)setTopView:(UIView *)topView animateBlock:(void(^)(void))animateBlock{
    if(_topView) {
        [_topView removeFromSuperview];
    }
    _topView = topView;
    if(_topView) {
        [self.contentView addSubview:_topView];
        [self.contentView sendSubviewToBack:_topView];
    }
    __weak typeof(self) weakSelf = self;
    [self animateInputWithBlock:^{
        [weakSelf layoutSubviews];
        if(animateBlock) {
            animateBlock();
        }
    }];
    
}


#pragma mark - 私有方法

// 输入框面板收缩
-(void) inputPanelUpOrDown {
    if( [self delegate]&&[self.delegate respondsToSelector:@selector(inputPanelUpOrDown:up:)]){
        [self.delegate inputPanelUpOrDown:self up:self.keyboardHeight>0];
    }
}

-(void) animateInputWithBlock:(void(^)(void)) block{
    [UIView animateWithDuration:SessionInputAnimateDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        block();
    } completion:nil];
}
-(void) animateInputPanelChange {
    [self animateInputWithBlock:^{
//        [self adjustInput:NO];
        [self layoutSubviews]; // 加了这句textView才有向上增长的效果，而不是向上移动（很重要）
        [self.textView layoutSubviews];
    }];
}

-(void) animateInputPanelChange:(void(^)(void))block {
    [self animateInputWithBlock:^{
//        [self adjustInput:NO];
        [self layoutSubviews]; // 加了这句textView才有向上增长的效果，而不是向上移动（很重要）
        [self.textView layoutSubviews];
        block();
    }];
}

-(UIImage*) imageName:(NSString*)name {
//    return [currentModule ImageForResource:name];
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//   return  [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}


// 输入面板发送改变
-(void) triggerInputPanelChangeEvent {
    if(_delegate&&[_delegate respondsToSelector:@selector(inputPanelWillChangeHeight:height:duration:animationCurve:)]) {
        [_delegate inputPanelWillChangeHeight:self height:self.currentContentHeight duration:SessionInputAnimateDuration animationCurve:0];
    }
}

-(void) stopFuncGroupZoom {
    [self.funcGroupView stopZoom];
}

-(BOOL) isFuncGroupZooming {
    return [self.funcGroupView isZooming];
}

#pragma mark - Voice/Text Mode Toggle

- (UIButton *)voiceToggleBtn {
    if (!_voiceToggleBtn) {
        _voiceToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _voiceToggleBtn.frame = CGRectMake(0, 0, 30, 30);
        UIImage *voiceImg = [WKApp.shared loadImage:@"Conversation/Toolbar/VoiceToggle" moduleID:@"WuKongBase"];
        [_voiceToggleBtn setImage:voiceImg forState:UIControlStateNormal];
        _voiceToggleBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_voiceToggleBtn addTarget:self action:@selector(toggleVoiceMode) forControlEvents:UIControlEventTouchUpInside];
    }
    return _voiceToggleBtn;
}

- (UIButton *)holdToTalkBtn {
    if (!_holdToTalkBtn) {
        _holdToTalkBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _holdToTalkBtn.frame = CGRectMake(0, 0, 100, WKConversationInputHeight);
        [_holdToTalkBtn setTitle:LLang(@"按住 说话") forState:UIControlStateNormal];
        [_holdToTalkBtn setTitleColor:[UIColor colorWithRed:0.35 green:0.35 blue:0.37 alpha:1.0] forState:UIControlStateNormal];
        _holdToTalkBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        _holdToTalkBtn.layer.cornerRadius = 15.0f;
        _holdToTalkBtn.layer.masksToBounds = YES;
        _holdToTalkBtn.hidden = YES;

        // 长按手势
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHoldToTalk:)];
        longPress.minimumPressDuration = 0.15;
        [_holdToTalkBtn addGestureRecognizer:longPress];
    }
    return _holdToTalkBtn;
}

- (WKHoldToTalkManager *)holdToTalkManager {
    if (!_holdToTalkManager) {
        _holdToTalkManager = [[WKHoldToTalkManager alloc] init];
        _holdToTalkManager.delegate = self;
    }
    return _holdToTalkManager;
}

- (void)toggleVoiceMode {
    self.isVoiceMode = !self.isVoiceMode;

    if (self.isVoiceMode) {
        // 切换到语音模式
        UIImage *kbImg = [WKApp.shared loadImage:@"Conversation/Toolbar/KeyboardToggle" moduleID:@"WuKongBase"];
        [self.voiceToggleBtn setImage:kbImg forState:UIControlStateNormal];
        self.textView.hidden = YES;
        self.sendButton.hidden = YES;
        self.holdToTalkBtn.hidden = NO;
        [self.textView endEditing:YES];
        // 语音模式下输入栏高度重置为单行
        self.currentInputHeight = WKConversationInputHeight;
    } else {
        // 切换回文本模式
        UIImage *voiceImg = [WKApp.shared loadImage:@"Conversation/Toolbar/VoiceToggle" moduleID:@"WuKongBase"];
        [self.voiceToggleBtn setImage:voiceImg forState:UIControlStateNormal];
        self.textView.hidden = NO;
        self.holdToTalkBtn.hidden = YES;
        // 恢复发送按钮状态
        NSString *text = self.textView.text;
        BOOL hasText = text && ![[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""];
        self.sendButton.show = hasText;
        self.sendButton.hidden = !hasText;
        // 恢复文本模式下输入框高度
        [self resetCurrentInputHeight];
        [self.holdToTalkManager cancelIfRecording];
    }

    [self animateInputPanelChange];
}

- (void)handleHoldToTalk:(UILongPressGestureRecognizer *)gesture {
    UIWindow *window = self.window;
    if (!window) return;
    [self.holdToTalkManager handleLongPress:gesture inWindow:window];
}

#pragma mark - WKHoldToTalkManagerDelegate

- (void)holdToTalkManager:(WKHoldToTalkManager *)manager didTranscribeText:(NSString *)text {
    [self inputInsertText:text];
}

- (void)holdToTalkManager:(WKHoldToTalkManager *)manager sendVoiceData:(NSData *)data seconds:(NSInteger)seconds waveform:(NSArray<NSNumber *> *)waveform {
    if (seconds <= 0) {
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"说话时间太短")];
        return;
    }
    // 将波形数组转为 NSData（与 WKVoicePanel cutAudioWaveform 一致）
    NSData *waveformData = [self convertWaveformToData:waveform];
    if ([self.conversationContext respondsToSelector:@selector(sendMessage:)]) {
        [self.conversationContext sendMessage:[WKVoiceContent initWithData:data second:(int)seconds waveform:waveformData]];
    }
}

- (NSData *)convertWaveformToData:(NSArray<NSNumber *> *)waveform {
    if (!waveform || waveform.count == 0) return nil;
    NSMutableData *data = [[NSMutableData alloc] init];
    NSUInteger binSize = waveform.count / 20; // 缩减到约20个采样点
    if (binSize == 0) binSize = 1;
    for (NSUInteger i = 0; i < waveform.count; i += binSize) {
        uint8_t maxVal = 0;
        for (NSUInteger j = 0; j < binSize && (i + j) < waveform.count; j++) {
            uint8_t v = (uint8_t)(MIN(waveform[i + j].floatValue * 100.0f, 255));
            if (v > maxVal) maxVal = v;
        }
        [data appendBytes:&maxVal length:1];
    }
    return data;
}

- (void)holdToTalkManager:(WKHoldToTalkManager *)manager sendText:(NSString *)text {
    if (self.delegate && [self.delegate respondsToSelector:@selector(inputPanelSend:text:)]) {
        [self.delegate inputPanelSend:self text:text];
    }
}

- (void)holdToTalkManager:(WKHoldToTalkManager *)manager sendText:(NSString *)text mentions:(NSArray<WKInputMentionItem *> *)mentions {
    // 先写入 mentionCache
    if (mentions.count > 0 && [self.conversationContext respondsToSelector:@selector(addMentionItems:)]) {
        [self.conversationContext addMentionItems:mentions];
    }
    // 再走正常发送流程（sendTextMessage 会从 mentionCache 生成 entity）
    if (self.delegate && [self.delegate respondsToSelector:@selector(inputPanelSend:text:)]) {
        [self.delegate inputPanelSend:self text:text];
    }
}

- (NSArray *)holdToTalkManagerChannelMembers:(WKHoldToTalkManager *)manager {
    if (![self.conversationContext respondsToSelector:@selector(channel)]) return @[];
    WKChannel *channel = self.conversationContext.channel;
    // 子区成员在父群上
    if (channel.channelType == WK_COMMUNITY_TOPIC) {
        NSRange sep = [channel.channelId rangeOfString:@"____"];
        if (sep.location != NSNotFound) {
            NSString *groupNo = [channel.channelId substringToIndex:sep.location];
            return [[WKChannelMemberDB shared] getMembersWithChannel:[WKChannel groupWithChannelID:groupNo]];
        }
    }
    return [[WKChannelMemberDB shared] getMembersWithChannel:channel];
}

- (void)holdToTalkManagerDidStartRecording:(WKHoldToTalkManager *)manager {
    if ([self.conversationContext respondsToSelector:@selector(startRecordingVoiceMessage)]) {
        [self.conversationContext startRecordingVoiceMessage];
    }
}

- (void)holdToTalkManagerDidStopRecording:(WKHoldToTalkManager *)manager {
    // 录音结束
}

- (NSString *)holdToTalkManagerCurrentInputText:(WKHoldToTalkManager *)manager {
    return self.textView.text;
}

- (NSString *)holdToTalkManagerChatContext:(WKHoldToTalkManager *)manager {
    // 构建聊天上下文（复用 WKVoicePanel 的逻辑）
    NSMutableArray<NSString*> *parts = [NSMutableArray array];
    NSString *myUid = [WKApp shared].loginInfo.uid;
    WKChannel *channel = self.conversationContext.channel;

    // 聊天成员名单
    NSMutableArray<NSString*> *memberNames = [NSMutableArray array];
    NSMutableSet<NSString*> *uniqueNames = [NSMutableSet set];

    if (channel.channelType == WK_GROUP || channel.channelType == WK_COMMUNITY_TOPIC) {
        WKChannel *memberChannel = channel;
        if (channel.channelType == WK_COMMUNITY_TOPIC) {
            NSRange sep = [channel.channelId rangeOfString:@"____"];
            if (sep.location != NSNotFound) {
                memberChannel = [WKChannel groupWithChannelID:[channel.channelId substringToIndex:sep.location]];
            }
        }
        NSArray<WKChannelMember*> *members = [[WKChannelMemberDB shared] getMembersWithChannel:memberChannel];
        NSInteger limit = MIN(members.count, 100);
        for (NSInteger i = 0; i < limit; i++) {
            WKChannelMember *member = members[i];
            if ([member.memberUid isEqualToString:myUid]) continue;
            if (member.status != WKMemberStatusNormal) continue;
            WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfoOfUser:member.memberUid];
            if (info) {
                if (info.name.length > 0 && ![uniqueNames containsObject:info.name]) {
                    [uniqueNames addObject:info.name];
                    [memberNames addObject:info.name];
                }
            }
        }
    } else if (channel.channelType == WK_PERSON) {
        WKChannelInfo *peerInfo = [[WKSDK shared].channelManager getChannelInfo:channel];
        if (peerInfo && peerInfo.name.length > 0) {
            [memberNames addObject:peerInfo.name];
        }
    }

    if (memberNames.count > 0) {
        [parts addObject:[NSString stringWithFormat:@"聊天成员：%@", [memberNames componentsJoinedByString:@","]]];
    }

    // 最后10条消息
    if ([self.conversationContext respondsToSelector:@selector(dates)] &&
        [self.conversationContext respondsToSelector:@selector(messagesAtDate:)]) {
        NSMutableArray<WKMessageModel*> *allMessages = [NSMutableArray array];
        for (NSString *date in [self.conversationContext dates]) {
            NSArray<WKMessageModel*> *msgs = [self.conversationContext messagesAtDate:date];
            if (msgs) [allMessages addObjectsFromArray:msgs];
        }
        NSMutableArray<WKMessageModel*> *textMessages = [NSMutableArray array];
        for (WKMessageModel *msg in allMessages) {
            NSString *content = msg.content.contentDict[@"content"];
            if (content.length > 0) {
                [textMessages addObject:msg];
            }
        }
        if (textMessages.count > 0) {
            NSInteger count = MIN(textMessages.count, 10);
            NSArray *recent = [textMessages subarrayWithRange:NSMakeRange(textMessages.count - count, count)];
            NSMutableArray<NSString*> *msgLines = [NSMutableArray array];
            for (WKMessageModel *msg in recent) {
                NSString *text = msg.content.contentDict[@"content"];
                NSString *name = nil;
                WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfoOfUser:msg.fromUid];
                if (info) name = info.displayName;
                if (!name) name = msg.fromUid;
                [msgLines addObject:[NSString stringWithFormat:@"[%@]: %@", name, text]];
            }
            [parts addObject:[msgLines componentsJoinedByString:@"\n"]];
        }
    }

    return parts.count > 0 ? [parts componentsJoinedByString:@"\n"] : nil;
}

#pragma mark - BotFather 命令联想

- (BOOL)isBotFatherChannel {
    NSString *botUID = [WKApp shared].config.botfatherUID;
    if (!botUID || botUID.length == 0) return NO;
    return [self.conversationContext.channel.channelId isEqualToString:botUID];
}

- (NSArray<NSDictionary *> *)botFatherCommands {
    if (!_cmdSuggestData) {
        _cmdSuggestData = @[
            @{@"cmd": @"/quickstart", @"desc": @"AI Agent 快速入门"},
            @{@"cmd": @"/newbot",     @"desc": @"创建新机器人"},
            @{@"cmd": @"/mybots",     @"desc": @"查看我的机器人"},
            @{@"cmd": @"/connect",    @"desc": @"获取连接 prompt"},
            @{@"cmd": @"/disconnect", @"desc": @"断开 Agent 连接"},
            @{@"cmd": @"/setname",    @"desc": @"修改机器人名称"},
            @{@"cmd": @"/setdescription", @"desc": @"修改机器人描述"},
            @{@"cmd": @"/deletebot",  @"desc": @"删除机器人"},
            @{@"cmd": @"/token",      @"desc": @"查看 Token"},
            @{@"cmd": @"/revoke",     @"desc": @"重置 Token"},
            @{@"cmd": @"/pending",    @"desc": @"查看待处理的好友申请"},
            @{@"cmd": @"/approve",    @"desc": @"通过好友申请"},
            @{@"cmd": @"/reject",     @"desc": @"拒绝好友申请"},
            @{@"cmd": @"/cancel",     @"desc": @"取消当前操作"},
            @{@"cmd": @"/help",       @"desc": @"显示帮助"},
        ];
    }
    return _cmdSuggestData;
}

- (void)updateCommandSuggestions:(NSString *)text {
    if (![self isBotFatherChannel]) {
        [self hideCmdSuggestView];
        return;
    }

    // 只在文本以 / 开头时显示联想
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![trimmed hasPrefix:@"/"]) {
        [self hideCmdSuggestView];
        return;
    }

    // 用输入的文本过滤命令
    NSString *keyword = [trimmed lowercaseString];
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *item in [self botFatherCommands]) {
        NSString *cmd = item[@"cmd"];
        if ([cmd hasPrefix:keyword] || [cmd containsString:keyword]) {
            [filtered addObject:item];
        }
    }

    // 如果只剩一个且完全匹配，不显示
    if (filtered.count == 1 && [filtered[0][@"cmd"] isEqualToString:trimmed]) {
        [self hideCmdSuggestView];
        return;
    }

    if (filtered.count == 0) {
        [self hideCmdSuggestView];
        return;
    }

    self.cmdSuggestFiltered = filtered;
    [self showCmdSuggestView];
    [self.cmdSuggestTable reloadData];
}

- (void)showCmdSuggestView {
    if (self.cmdSuggestView) {
        [self layoutCmdSuggestView];
        return;
    }

    self.cmdSuggestView = [[UIView alloc] init];
    self.cmdSuggestView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    self.cmdSuggestView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.cmdSuggestView.layer.shadowOpacity = 0.1;
    self.cmdSuggestView.layer.shadowOffset = CGSizeMake(0, -2);
    self.cmdSuggestView.layer.shadowRadius = 4;

    self.cmdSuggestTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.cmdSuggestTable.delegate = self;
    self.cmdSuggestTable.dataSource = self;
    self.cmdSuggestTable.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.cmdSuggestTable.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    self.cmdSuggestTable.backgroundColor = [UIColor clearColor];
    self.cmdSuggestTable.rowHeight = 44;
    self.cmdSuggestTable.bounces = NO;
    [self.cmdSuggestTable registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CmdCell"];
    [self.cmdSuggestView addSubview:self.cmdSuggestTable];

    UIView *parentView = self.superview;
    if (parentView) {
        [parentView insertSubview:self.cmdSuggestView belowSubview:self];
    }
    [self layoutCmdSuggestView];
}

- (void)layoutCmdSuggestView {
    if (!self.cmdSuggestView || !self.cmdSuggestFiltered) return;
    CGFloat rowH = 44;
    CGFloat maxRows = MIN(self.cmdSuggestFiltered.count, 6);
    CGFloat tableH = rowH * maxRows;
    CGFloat w = self.lim_width;
    CGFloat y = self.frame.origin.y - tableH;
    self.cmdSuggestView.frame = CGRectMake(0, y, w, tableH);
    self.cmdSuggestTable.frame = self.cmdSuggestView.bounds;
}

- (void)hideCmdSuggestView {
    if (self.cmdSuggestView) {
        [self.cmdSuggestView removeFromSuperview];
        self.cmdSuggestView = nil;
        self.cmdSuggestTable = nil;
        self.cmdSuggestFiltered = nil;
    }
}

#pragma mark - Command Suggest UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.cmdSuggestTable) {
        return self.cmdSuggestFiltered.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CmdCell" forIndexPath:indexPath];
    NSDictionary *item = self.cmdSuggestFiltered[indexPath.row];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    // 命令文字（蓝色加粗）+ 描述（灰色）
    NSString *cmd = item[@"cmd"];
    NSString *desc = item[@"desc"];
    NSString *full = [NSString stringWithFormat:@"%@  %@", cmd, desc];

    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:full];
    UIColor *themeColor = [WKApp shared].config.themeColor;
    [attr addAttribute:NSForegroundColorAttributeName value:themeColor range:NSMakeRange(0, cmd.length)];
    [attr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:15 weight:UIFontWeightMedium] range:NSMakeRange(0, cmd.length)];
    [attr addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:NSMakeRange(cmd.length + 2, desc.length)];
    [attr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:13] range:NSMakeRange(cmd.length + 2, desc.length)];

    cell.textLabel.attributedText = attr;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.cmdSuggestFiltered[indexPath.row];
    NSString *cmd = item[@"cmd"];
    self.textView.text = cmd;
    [self handleTextViewContentDidChange];
    [self hideCmdSuggestView];
}

-(void) dealloc{
    [self removeKeyboardListen];
}

- (CGFloat) safeBottom {
    CGFloat safeNum = 0;
    if (@available(iOS 11.0, *)) {
        UIWindow *window = self.window;
        if (!window) {
            window = [UIApplication sharedApplication].keyWindow;
        }
        safeNum = window.safeAreaInsets.bottom;
    }
    return safeNum;
}


@end
