//
//  WKMessageCell.m
//  WuKongBase
//
//  Created by tt on 2019/12/28.
//

#import "WKMessageCell.h"
#import "WKImageView.h"
#import "WKResource.h"
#import "WKConversationInputPanel.h"
#import "WKAvatarUtil.h"
#import "WKCircularProgressView.h"
#import "WKReactionBaseView.h"
#import "UILabel+WK.h"
#import "NSMutableAttributedString+WK.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKTapLongTapOrDoubleTapGestureRecognizerEvent.h"


// 整个消息距离顶部的距离
#define WK_MESSAGE_TOP 0.0f

#define errorTipFontSize 14.0f
#define errorTipLeftSpace 20.0f // 发送消息错误提示左边距
#define errorTipRightSpace 20.0f // 发送消息错误提示右边距
#define errorTipTopSpace 5.0f // 发送消息错误提示顶部距离

static NSMutableDictionary *flameNodeCacheDict;


@interface WKMessageCell ()<WKCheckBoxDelegate>
@property(nonatomic,strong) NSArray<WKMessageLongMenusItem*> *longMenusItems;

@property(nonatomic,assign) BOOL canBecomeFirst;

@property(nonatomic,strong) UITapGestureRecognizer *messageCellTapGesture; // 总个消息被点击

@property(nonatomic,strong) WKCircularProgressView *readedProgressView; // 已读进度
@property(nonatomic,strong) UIView *readedProgressViewBox; // readedProgressView的box为了增大点击面

@property(nonatomic,strong) WKReactionBaseView *reactionView;

@property(nonatomic,strong) UILabel *errorLbl; // 消息发送错误原因

@property(nonatomic,strong) UIButton *navigateToMessageBtn; // 跳到消息的按钮

@property(nonatomic,strong) ContextControllerSourceNode *mainContainerNode;

@property(nonatomic,strong) TapLongTapOrDoubleTapGestureRecognizerWrap *tapLongTapOrDoubleTapGestureRecognizerWrap;


@end

@implementation WKMessageCell

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
    CGSize contentSize = [[self class] contentSizeForMessage:model];
    UIEdgeInsets  contentEdgeInsets = [[self class] contentEdgeInsets:model];
    UIEdgeInsets  bubbleEdgeInsets = [[self class] bubbleEdgeInsets:model contentSize:contentSize];
    CGFloat nicknameTop = 0.0f;
//    if(!model.isSend) {
//        nicknameTop = WK_NICKNAME_HEIGHT;
//    }
    NSAttributedString *reason = model.reason;
    CGFloat reasonHeight = 0;
    if(reason) {
        CGSize reasonSize = [self getTextSize:reason.string maxWidth:WKScreenWidth - errorTipLeftSpace - errorTipRightSpace font:[UIFont systemFontOfSize:errorTipFontSize]];
        reasonHeight = reasonSize.height + errorTipTopSpace;
    }
    CGFloat height = contentSize.height + contentEdgeInsets.top + contentEdgeInsets.bottom + bubbleEdgeInsets.top + bubbleEdgeInsets.bottom + WK_MESSAGE_TOP + nicknameTop + reasonHeight;
    
    CGFloat contentWidth = contentSize.width;
   
    
   
    CGFloat width = contentWidth + bubbleEdgeInsets.left + bubbleEdgeInsets.right + contentEdgeInsets.left + contentEdgeInsets.right;
    
    return CGSizeMake(width,height);
}

- (void)prepareForReuse {
    [super prepareForReuse];
//    if(self.flameNode) {
//        [self.flameNode.view removeFromSuperview];
//    }
    
    [self stopReminderAnimation];
    if(self.onPrepareForReuse) {
        self.onPrepareForReuse();
        self.onPrepareForReuse = nil;
    }
   
    
}

+ (CGSize) contentSizeForMessage:(WKMessageModel *)model {
    return CGSizeMake(80.0f, 80.0f);
}

-(void) initUI {
    [super initUI];
    __weak typeof(self) weakSelf = self;
    
    [self setBackgroundColor:[UIColor clearColor]];
//    self.userInteractionEnabled = YES;
    
    // ---------- tap事件 ----------
    self.tapLongTapOrDoubleTapGestureRecognizerWrap = [[TapLongTapOrDoubleTapGestureRecognizerWrap alloc] initWithAction:^(TapLongTapOrDoubleTapGestureRecognizerWrap * gesture) {
        [weakSelf tapLongTapOrDoubleTapGesture:gesture];
    }];
    [self.tapLongTapOrDoubleTapGestureRecognizerWrap setup];
    self.tapLongTapOrDoubleTapGestureRecognizerWrap.tapActionAtPoint = ^WKTapLongTapOrDoubleTapGestureRecognizerEvent * _Nonnull(CGPoint point) {
        return [weakSelf tapActionAtPoint:point];
    };
    // 长按
    self.tapLongTapOrDoubleTapGestureRecognizerWrap.longTap = ^(CGPoint point, TapLongTapOrDoubleTapGestureRecognizerWrap * gesture) {
        if([weakSelf avatarTapAtPoint:point]) {
            [weakSelf onAvatarLongPressed];
        }
    };
//    [self.contentView setExclusiveTouch:true];
    [self.tapLongTapOrDoubleTapGestureRecognizerWrap attachToView:self.contentView];

    
    // ---------- main容器 ----------
    self.mainContextSourceNode = [[ContextExtractedContentContainingNode alloc] init];
//    self.bubbleSourceNode.view.backgroundColor = [UIColor redColor];
    self.mainContainerNode = [[ContextControllerSourceNode alloc] init];
//    self.mainContainerNode.isGestureEnabled = false;
    [self.contentView addSubnode:self.mainContainerNode];
    [self.mainContainerNode addSubnode:self.mainContextSourceNode];
   
    
    [self.mainContainerNode setShouldBegin:^BOOL(CGPoint point) {
        if(!weakSelf) {
            return false;
        }
        if(!CGRectContainsPoint(weakSelf.bubbleBackgroundView.frame, point)) {
            return false;
        }
//        WKTapLongTapOrDoubleTapGestureRecognizerEvent *event = [weakSelf tapActionAtPoint:point];
//        if(event.action != WKTapLongTapOrDoubleTapGestureRecognizerActionNone) {
//            return false;
//        }
        
        return true;
    }];
    [self.mainContainerNode setActivated:^(ContextGesture *gesture, CGPoint point) {
        if(!weakSelf) {
            return;
        }
       
    
        [weakSelf onLongTap:gesture];
    }];
   
    
    // ---------- 内容ui ----------

    // checkbox
    self.checkBox = [[WKCheckBox alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
    self.checkBox.onFillColor = [WKApp shared].config.themeColor;
    self.checkBox.onCheckColor = [UIColor whiteColor];
    self.checkBox.onAnimationType = BEMAnimationTypeBounce;
    self.checkBox.offAnimationType = BEMAnimationTypeBounce;
    self.checkBox.animationDuration = 0.0f;
    self.checkBox.lineWidth = 1.0f;
    self.checkBox.delegate = self;
    [self.contentView addSubview:self.checkBox];
    
    // 气泡
    self.bubbleBackgroundView = [[UIImageView alloc] initWithFrame:CGRectZero];
    [self.bubbleBackgroundView setBackgroundColor:[UIColor clearColor]];
    [self.mainContextSourceNode.contentNode.view addSubview:self.bubbleBackgroundView];
//    [self.contentView addSubview:self.bubbleContainerView];
//    self.bubbleBackgroundView.userInteractionEnabled = YES;

    // 消息正文
    self.messageContentView = [[WKMessageContentView alloc] initWithFrame:CGRectZero];
    [self.messageContentView setBackgroundColor:[UIColor clearColor]];
    self.messageContentView.userInteractionEnabled = YES;
    [self.bubbleBackgroundView addSubview:self.messageContentView];
    // 头像
    self.avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, [WKApp shared].config.messageAvatarSize.width, [WKApp shared].config.messageAvatarSize.height)];
    [self.contentView addSubview:self.avatarImgView];

    // 消息发送错误
    self.sendFailBtn = [[UIView alloc] init];
    UIImageView *sendFailIcon = [[UIImageView alloc] initWithImage:[self getImageNameForBaseModule:@"Conversation/Messages/MsgStatusFail"]];
    sendFailIcon.lim_size = CGSizeMake(24.0f, 24.0f);
    [self.sendFailBtn addSubview:sendFailIcon];
    
    self.sendFailBtn.lim_size = CGSizeMake(40.0f, 40.0f);
    [self.sendFailBtn setBackgroundColor:[UIColor clearColor]];
    self.sendFailBtn.userInteractionEnabled = YES;
    [self.contentView addSubview:self.sendFailBtn];
    
    sendFailIcon.lim_centerX_parent = self.sendFailBtn;
    sendFailIcon.lim_centerY_parent = self.sendFailBtn;
    
//    self.contentView.backgroundColor = [UIColor orangeColor];

//    self.bubbleBackgroundView.userInteractionEnabled = YES;
//     UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc]
//                         initWithTarget:self
//                                                       action:@selector(longGesturePress:)];
//    [self.messageContentView addGestureRecognizer:longPressGesture];
    
    // 总个cell被点击的tap
    self.messageCellTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageCellTap)];
    
    // ---------- 尾部 ----------
    [self.messageContentView addSubview:self.trailingView];
    [self.trailingView setUserInteractionEnabled:NO];

   
    
    // 名字
    self.nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [WKApp shared].config.messageContentMaxWidth, WK_NICKNAME_HEIGHT)];
    [self.nameLbl setFont:WK_NICKNAME_FONT];
   
    [self.nameLbl setTextColor:[UIColor grayColor]];
    [self.bubbleBackgroundView addSubview:self.nameLbl];
    
    // 回应
    self.reactionView = [[WKApp shared] invoke:WKPOINT_MESSAGEEXTEND_REACTIONVIEW param:nil];
    if(!self.reactionView) {
        self.reactionView = [[WKReactionBaseView alloc] init];
    }
    
    [self.contentView addSubview:self.reactionView];
    
    // 发送错误提示
    [self.contentView addSubview:self.errorLbl];
    
    self.mainContainerNode.targetNodeForActivationProgress = self.mainContextSourceNode.contentNode;
 
    [self.contentView addSubview:self.flameBox];
    
    [self.contentView addSubview:self.navigateToMessageBtn];
}


-(BOOL) respondContentSingleTap {
    return true;
}

-(void) tapLongTapOrDoubleTapGesture:(TapLongTapOrDoubleTapGestureRecognizerWrap*)recognizer {
    if(recognizer.tapAction == WKTapLongTapOrDoubleTapGestureTap) {
        
        if([self.conversationContext isFuncGroupZooming]) {
            [self.conversationContext stopFuncGroupZoom];
        }
        
        CGRect rectInContentView = [self.contentView convertRect:self.messageContentView.frame fromView:self.messageContentView.superview];
        if([self respondContentSingleTap] &&  CGRectContainsPoint(rectInContentView, recognizer.tapPoint)) {
            [self onTapWithGestureRecognizer:recognizer];
            return;
        }
        if([self avatarTapAtPoint:recognizer.tapPoint]) {
            [self onAvatarTap];
            return;
        }
        if(!self.sendFailBtn.hidden) {
            if([self sendFailAtPoint:recognizer.tapPoint]) {
                [self sendFailPressed];
                return;
            }
        }
        if(!self.navigateToMessageBtn.hidden) {
            if ([self navigateToMessageAtPoint:recognizer.tapPoint]) {
                [self navigateToMessagePressed];
            }
        }
       
        [self endEditing];
    }
}

-(WKTapLongTapOrDoubleTapGestureRecognizerEvent*) tapActionAtPoint:(CGPoint)point {
    CGRect rectInContentView = [self.contentView convertRect:self.messageContentView.frame fromView:self.messageContentView.superview];
    
    WKTapLongTapOrDoubleTapGestureRecognizerEvent *event;
    if([self respondContentSingleTap] && CGRectContainsPoint(rectInContentView, point)) {
        event = [WKTapLongTapOrDoubleTapGestureRecognizerEvent action:(WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForSingleTap)];
    }else if([self avatarTapAtPoint:point]) {
        event = [WKTapLongTapOrDoubleTapGestureRecognizerEvent action:(WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForSingleTap)];
    }else {
        event = [WKTapLongTapOrDoubleTapGestureRecognizerEvent action:WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForSingleTap];
    }
    return event;
}

-(BOOL) avatarTapAtPoint:(CGPoint)point {
    return CGRectContainsPoint(self.avatarImgView.frame, point);
}

-(BOOL) sendFailAtPoint:(CGPoint)point {
    return CGRectContainsPoint(self.sendFailBtn.frame, point);
}

-(BOOL) navigateToMessageAtPoint:(CGPoint)point {
    return CGRectContainsPoint(self.navigateToMessageBtn.frame, point);
}


- (WKTrailingView *)trailingView {
    if(!_trailingView) {
        _trailingView = [[WKTrailingView alloc] init];
        _trailingView.messageCell = self;
        _trailingView.tailWrap = self.tailWrap;
    }
    return _trailingView;
}

- (UIView *)flameBox {
    if(!_flameBox) {
        _flameBox = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
//        [_flameBox setBackgroundColor:[UIColor blueColor]];
    }
    return _flameBox;
}


-(void) longGesturePress:(UIGestureRecognizer *)gestureRecognizer  {
    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]] &&
        gestureRecognizer.state == UIGestureRecognizerStateBegan) {

        [self onLongTap:gestureRecognizer];
        
    }
}

-(void) onAvatarLongPressed {
    [self.conversationContext addMention:self.messageModel.fromUid];
}

-(void) onAvatarTap {
    
    if(self.messageModel.channel.channelType == WK_CustomerService) {
        return;
    }
    NSMutableDictionary *paramDict = [[NSMutableDictionary alloc] init];
    [paramDict setObject:self.messageModel.fromUid?:@"" forKey:@"uid"];
    if(self.messageModel.channel) {
        [paramDict setObject:self.messageModel.channel forKey:@"channel"];
    }
    NSString *code = @"";
    if(self.messageModel.memberOfFrom) {
        code = self.messageModel.memberOfFrom.extra[@"vercode"];
        paramDict[@"vercode"] = code?:@"";
    }
   
    
    [[WKApp shared] invoke:WKPOINT_USER_INFO param:paramDict];
}

-(void) messageCellTap {
    [self didTapCheck];
}

-(void) didTapCheck {
    if(self.messageModel.contentType == WK_TYPING) {
        return;
    }
    self.messageModel.checked = !self.messageModel.checked;
    [self.checkBox setOn:self.messageModel.checked];
}

-(void) onLongTap:(UIGestureRecognizer *)gestureRecognizer {
    if(self.messageModel.contentType == WK_TYPING) {
        return;
    }
    [self.conversationContext longPressMessageCell:self gestureRecognizer:gestureRecognizer];
    
}


-(void) tappedMenuItem:(NSString*)title {
    if(self.longMenusItems) {
        for (WKMessageLongMenusItem *longItem in self.longMenusItems) {
            if([longItem.title isEqualToString:title]) {
                if(longItem.onTap) {
                    longItem.onTap(self.conversationContext);
                }
            }
        }
    }
}

-(void) onTap {
//    [self endEditing];
}

-(void) endEditing {
    [self.conversationContext endEditing];
}

-(void) onTapWithGestureRecognizer:(TapLongTapOrDoubleTapGestureRecognizerWrap*)gesture {
    [self onTap];
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
    self.showCheckBox = model.checkboxOn;
    self.bubbleBackgroundView.image = [self bubbleImage];
    
    WKBubblePostion bubblePosition = [[self class] bubblePosition:self.messageModel];
    
    if(model.checkboxOn && model.contentType != WK_TYPING) {
        self.mainContainerNode.isGestureEnabled = NO;
        [self.tapLongTapOrDoubleTapGestureRecognizerWrap.gesture setEnabled:NO];
        self.checkBox.hidden = NO;
        [self.checkBox setOn:self.messageModel.checked];
        [self.contentView addGestureRecognizer:self.messageCellTapGesture];
        self.avatarImgView.userInteractionEnabled = NO;
        self.messageContentView.userInteractionEnabled = NO;
        
    }else{
        self.mainContainerNode.isGestureEnabled = YES;
        [self.tapLongTapOrDoubleTapGestureRecognizerWrap.gesture setEnabled:YES];
        self.checkBox.hidden = YES;
        self.avatarImgView.userInteractionEnabled = YES;
        [self.contentView removeGestureRecognizer:self.messageCellTapGesture];
        self.messageContentView.userInteractionEnabled = YES;
    }
    
    if(!model.from && ![model.fromUid isEqualToString:@""]) { // 如果没有发送者信息则提取。
        [[WKSDK shared].channelManager fetchChannelInfo:[[WKChannel alloc] initWith:model.fromUid channelType:WK_PERSON]];
    }
    if(model.channel.channelType != WK_PERSON && !model.channelInfo) { // 没有频道信息则提取
        [[WKSDK shared].channelManager fetchChannelInfo:model.channel];
    }
    
    if([[self class] isShowName:model]) {
        self.nameLbl.hidden = NO;
        if(model.channel.channelType == WK_GROUP) {
            self.nameLbl.textColor = [WKUserColorUtil userColor:model.memberOfFrom.memberUid];
        }else {
            self.nameLbl.textColor =  [WKUserColorUtil userColor:model.from.channel.channelId];
        }
        self.nameLbl.text = [[self class] getFromName:self.messageModel];
        [self.nameLbl sizeToFit];
    }else {
        self.nameLbl.hidden = YES;
    }
    
    if(model.isSend) {
        self.avatarImgView.url = [WKApp shared].loginInfo.extra[@"avatar"];
    }else {
        if(model.from) { // 如果有发送者信息
            self.avatarImgView.url = [WKAvatarUtil getFullAvatarWIthPath:model.from.logo];
        }else {
            self.avatarImgView.avatarImgView.image = nil;
        }
    }
    self.sendFailBtn.hidden = YES;
    if([self needError:model]) {
        self.sendFailBtn.hidden = NO;
    }
    
    if(self.messageModel.reminderAnimation) { // 点击回复消息，跳到对应内容提醒
        self.messageModel.reminderAnimation = NO;
        [self startReminderAnimation:self.messageModel.reminderAnimationCount*2 white:true];
    }
    
    
    CGSize trailingSize = [WKTrailingView size:self.messageModel];
    self.trailingView.lim_size =  CGSizeMake(trailingSize.width + 15.0f, trailingSize.height + 4.0);
    [self.trailingView refresh:self.messageModel];
    
    self.avatarImgView.hidden = NO;
    
    if(bubblePosition == WKBubblePostionMiddle || bubblePosition == WKBubblePostionFirst) {
        self.avatarImgView.hidden = YES;
    }
    if([self.messageModel isSend] || self.messageModel.isPersonChannel) {
        self.avatarImgView.hidden = YES;
    }
    
    // 回应
    if(self.messageModel.reactions && self.messageModel.reactions.count>0) {
        self.reactionView.hidden = NO;
        [self.reactionView render:self.messageModel.reactionTop3];
        self.reactionView.reactionNum = self.messageModel.reactions.count;
    }else{
        self.reactionView.hidden = YES;
    }
    
    NSMutableAttributedString *reason = self.messageModel.reason;
    self.errorLbl.hidden = YES;
    if(reason) {
        self.errorLbl.hidden = NO;
        self.errorLbl.tokens = reason.tokens;
        self.errorLbl.attributedText = reason;
        [self.errorLbl sizeToFit];
    }
    [self.flameBox.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    if(self.messageModel.content.flame && ![self hiddenFlameProgress] && !self.messageModel.flameFinished) {
        RadialStatusNode *flameNode = [self.messageModel flameNode];
        [self.flameBox addSubview:flameNode.view];
        __weak typeof(self.messageModel) weakMessageModel = self.messageModel;
        [self.messageModel startFlameIfNeed:^{
            [WKMessageManager.shared deleteMessages:@[weakMessageModel]];
        }];
    }
    if(self.messageModel.isSend) {
        self.bubbleBackgroundView.tintColor = WKApp.shared.config.themeColor;
    }else{
        self.bubbleBackgroundView.tintColor = WKApp.shared.config.cellBackgroundColor;
    }
}
// 获取发送者名字
+(NSString*) getFromName:(WKMessageModel*)messageModel {
    
    NSString *fromUID = messageModel.fromUid;
    
    if([fromUID isEqualToString:[WKApp shared].config.systemUID]) {
        return LLang(@"系统通知");
    }else if([fromUID isEqualToString:[WKApp shared].config.fileHelperUID]) {
        return LLang(@"文件传输助手");
    }
    
    if(messageModel.channel.channelType == WK_PERSON) { // 个人不显示名字
        return messageModel.from?messageModel.from.displayName:@"";;
    }
    
    // 名字显示规则  个人备注 > 群内名字 > 昵称
    NSString *name = @"";
    WKChannelInfo *fromChannelInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:messageModel.fromUid]];
    if(fromChannelInfo) {
        if(fromChannelInfo.remark && ![fromChannelInfo.remark isEqualToString:@""]) {
            name = fromChannelInfo.remark;
        }
    }
    if([name isEqualToString:@""]) {
        if(messageModel.memberOfFrom && messageModel.memberOfFrom.memberRemark && ![messageModel.memberOfFrom.memberRemark isEqualToString:@""]) {
            name = messageModel.memberOfFrom.memberRemark;
        }
    }
    if([name isEqualToString:@""] && messageModel.from) {
        name = messageModel.from.name;
    }
   NSString *deviceName = [self getDeviceName:messageModel];
    if(deviceName && ![deviceName isEqualToString:@""]) {
        name = [NSString stringWithFormat:@"%@/%@",name,deviceName];
    }
   
    return name;
}


// 获取消息发送的设备
+(NSString*) getDeviceName:(WKMessageModel*)messageModel {
    if(!messageModel.clientMsgNo) {
        return @"";
    }
    
    if([messageModel.clientMsgNo hasSuffix:@"1"]) {
        return @"Android";
    }
    
    if([messageModel.clientMsgNo hasSuffix:@"2"]) {
        return @"iOS";
    }
    
    if([messageModel.clientMsgNo hasSuffix:@"3"]) {
        return @"Web";
    }
    
    if([messageModel.clientMsgNo hasSuffix:@"5"]) {
        return @"Flutter";
    }
    
    return @"";
}

+(CGSize) getNicknameSize:(WKMessageModel*)messageModel {
    NSString *nickname = [self getFromName:messageModel];
    CGSize nicknameSize =  [self getTextSize:nickname maxWidth:[WKApp shared].config.messageContentMaxWidth font:WK_NICKNAME_FONT];
    return nicknameSize;
}


// 气泡位置
+(WKBubblePostion) bubblePosition:(WKMessageModel*)messageModel {
    if([self isSystemOrRevoke:messageModel]) {
        return WKBubblePostionSingle;
    }
    if(messageModel.hasSensitiveWord && !messageModel.isSend) { // 有敏感词
        return  WKBubblePostionSingle;
    }
    if(messageModel.reason) {
        return WKBubblePostionSingle;
    }
    
    
    BOOL preContinue = [self preIsContinue:messageModel];
    BOOL nextContiue = [self nextIsContinue:messageModel];
    if(!preContinue && !nextContiue) {
        return WKBubblePostionSingle;
    }
    
    if( [self preIsSameFrom:messageModel] && [self nextIsSameFrom:messageModel] && ![self preIsSystemOrRevoke:messageModel] && ![self nextIsSystemOrRevoke:messageModel] && [self preIsSameDay:messageModel] && [self nextIsSameDay:messageModel]) {
        return WKBubblePostionMiddle;
    }else if(!nextContiue) {
        return WKBubblePostionLast;
    }else if(!preContinue) {
        return WKBubblePostionFirst;
    }
    return WKBubblePostionUnknown;
}

// 下一条消息是否连续
+(BOOL) nextIsContinue:(WKMessageModel*) messageModel {
    
    return [self nextIsSameFrom:messageModel] && ![self nextIsSystemOrRevoke:messageModel] && [self nextIsSameDay:messageModel];
}

// 上一条是否连续
+(BOOL) preIsContinue:(WKMessageModel*)messageModel {
    return [self preIsSameFrom:messageModel] && ![self preIsSystemOrRevoke:messageModel] && [self preIsSameDay:messageModel];
}

// 下一条消息是同一天
+(BOOL) nextIsSameDay:(WKMessageModel*)messageModel {
    if(!messageModel.nextMessageModel) {
        return false;
    }
    if([messageModel.dateStr isEqualToString:messageModel.nextMessageModel.dateStr]) {
        return true;
    }
    return false;
}

+(BOOL) preIsSameDay:(WKMessageModel*)messageModel {
    if(!messageModel.preMessageModel) {
        return false;
    }
    if([messageModel.dateStr isEqualToString:messageModel.preMessageModel.dateStr]) {
        return true;
    }
    return false;
}

// 下一条消息是否是系统消息(或者被撤回)
+(BOOL) nextIsSystemOrRevoke:(WKMessageModel*)messageModel {
    return [self isSystemOrRevoke:messageModel.nextMessageModel];
}

+(BOOL) isSystemOrRevoke:(WKMessageModel*)messageModel {
    
    return messageModel && ([[WKSDK shared] isSystemMessage:messageModel.contentType]||messageModel.revoke || messageModel.contentType == WK_HISTORY_SPLIT);
}

// 上一条消息是否是系统消息(或者被撤回) 则为第一条消息
+(BOOL) preIsSystemOrRevoke:(WKMessageModel*)messageModel {
    return [self isSystemOrRevoke:messageModel.preMessageModel];
}

// 上一条消息是否是同一个发送者
+(BOOL) preIsSameFrom:(WKMessageModel*)messageModel {
    return messageModel.preMessageModel && [messageModel.preMessageModel.fromUid isEqualToString:messageModel.fromUid];
}

// 下一条消息是否是同一个发送者
+(BOOL) nextIsSameFrom:(WKMessageModel*)messageModel {
    return messageModel.nextMessageModel && [messageModel.nextMessageModel.fromUid isEqualToString:messageModel.fromUid];
}



-(BOOL) needLoading:(WKMessageModel*)model {
    if((model.status == WK_MESSAGE_WAITSEND || model.status == WK_MESSAGE_UPLOADING) && model.isSend) {
        return true;
    }
    return false;
}

-(void) startReminderAnimation:(NSInteger)count white:(BOOL)white{
    
    [self.contentView.layer removeAllAnimations];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
    animation.duration = 0.8f;
    animation.repeatCount = 1;
    animation.toValue = (id)[WKApp shared].config.themeColor.CGColor;
    
    [self.contentView.layer addAnimation:animation forKey:nil];
}

-(void) startReminderAnimation{
    [self startReminderAnimation:1 white:false];
}


-(void) stopReminderAnimation {
    [self.contentView.layer removeAllAnimations];
}

// 是否显示昵称
-(BOOL) showNick {
    return self.messageModel.channelInfo && self.messageModel.channelInfo.showNick;
}


-(BOOL) needError:(WKMessageModel*)model {
    if(model.status == WK_MESSAGE_FAIL  && model.isSend) {
        return true;
    }
    return false;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    if(!self.messageModel) {
        return;
    }
    
    Class cellClass = [self class];
    UIEdgeInsets contentInsets = [cellClass contentEdgeInsets:self.messageModel];
    
    CGSize contentSize = [cellClass contentSizeForMessage:self.messageModel];
    self.messageContentView.lim_size = contentSize;
    self.messageContentView.lim_top = contentInsets.top;
    
    self.bubbleBackgroundView.lim_size = CGSizeMake(contentSize.width + contentInsets.left + contentInsets.right, contentSize.height +contentInsets.top + contentInsets.bottom);

    
    CGFloat avatarSpace = 10.0f; // 头像边距
    CGFloat avatarLeft = 0.0f; // 头像这边距离
    CGFloat checkBoxLeft = 10.0f;
    CGFloat checkBoxSpace = 10.0f;
    
    UIEdgeInsets bubbleInsets = [cellClass bubbleEdgeInsets:self.messageModel contentSize:contentSize];
    
    if(self.messageModel.isSend) {
        avatarLeft =  WKScreenWidth - avatarSpace - self.avatarImgView.lim_width;
    }else {
        avatarLeft = avatarSpace;
    }

    self.checkBox.lim_top = self.bubbleBackgroundView.lim_top + ( self.bubbleBackgroundView.lim_height/2.0f - self.checkBox.lim_height/2.0f);
    if(self.showCheckBox) {
        checkBoxLeft = checkBoxSpace;
        if(self.messageModel.isSend) {
            //checkBoxLeft = WKScreenWidth - checkBoxSpace - self.checkBox.lim_width;
           // avatarLeft  = checkBoxLeft - avatarSpace - self.avatarImgView.lim_width;
        }else {
            avatarLeft = checkBoxLeft + self.checkBox.lim_width + avatarSpace;
        }
        self.checkBox.lim_left = checkBoxLeft;
    }else{
        self.checkBox.lim_left = -self.checkBox.lim_width;
        
    }
    
    // 头像
    self.avatarImgView.lim_top = 0.0f;
    self.avatarImgView.lim_left =avatarLeft;
    
//    self.readedProgressView.hidden = YES;
    self.bubbleBackgroundView.lim_top = bubbleInsets.top;
    
    self.avatarImgView.lim_top = self.bubbleBackgroundView.lim_bottom - self.avatarImgView.lim_height;
    if(self.messageModel.isSend) { // 发送消息
        
        self.bubbleBackgroundView.lim_left = self.lim_width - self.bubbleBackgroundView.lim_width - bubbleInsets.right;
        
        // 消息正文
         self.messageContentView.lim_left = contentInsets.left;
        // 发送错误状态
        self.sendFailBtn.lim_top = self.bubbleBackgroundView.lim_top + ( self.bubbleBackgroundView.lim_height/2.0f - self.sendFailBtn.lim_height/2.0f);
        self.sendFailBtn.lim_left = self.bubbleBackgroundView.lim_left - self.sendFailBtn.lim_width;
        
//        self.readedProgressView.hidden = NO;
        self.readedProgressViewBox.lim_left = self.bubbleBackgroundView.lim_left - self.readedProgressViewBox.lim_width - 5.0f;
        self.readedProgressViewBox.lim_top = self.bubbleBackgroundView.lim_top + (self.bubbleBackgroundView.lim_height -self.readedProgressViewBox.lim_height);
        
        self.flameBox.lim_left = self.bubbleBackgroundView.lim_left - self.flameBox.lim_width - 10.0f;
        self.flameBox.lim_top =  self.bubbleBackgroundView.lim_top + ( self.bubbleBackgroundView.lim_height/2.0f - self.flameBox.lim_height/2.0f);
    }else { // 接收消息
        [self layoutName];
       
        if(self.messageModel.isPersonChannel) {
            if(self.showCheckBox) {
                self.bubbleBackgroundView.lim_left =  bubbleInsets.left + self.checkBox.lim_right + checkBoxLeft;
            }else{
                self.bubbleBackgroundView.lim_left =  bubbleInsets.left;
            }
            
        }else{
            self.bubbleBackgroundView.lim_left = self.avatarImgView.lim_right + bubbleInsets.left;
            
        }
       
        // 消息正文
        self.messageContentView.lim_left = contentInsets.left;
        
        self.flameBox.lim_left = self.bubbleBackgroundView.lim_right + 10.0f;
        self.flameBox.lim_top =  self.bubbleBackgroundView.lim_top + ( self.bubbleBackgroundView.lim_height/2.0f - self.flameBox.lim_height/2.0f);
    }

    [self layoutTrailingView];
    
    [self layoutReaction];
   
    self.errorLbl.lim_centerX_parent = self.contentView;
    self.errorLbl.lim_top = self.bubbleBackgroundView.lim_bottom + errorTipTopSpace;
    
    [self layoutMainContextSourceNode];
    
    self.navigateToMessageBtn.lim_top = self.bubbleBackgroundView.lim_bottom - self.navigateToMessageBtn.lim_height;
    if(self.messageModel.isSend) {
        self.navigateToMessageBtn.lim_left = self.bubbleBackgroundView.lim_left - self.navigateToMessageBtn.lim_width - 8.0f;
    } else {
        self.navigateToMessageBtn.lim_left = self.bubbleBackgroundView.lim_right + 8.0f;
    }
   
}

-(void) layoutMainContextSourceNode {
    
    self.mainContextSourceNode.frame = self.contentView.bounds;
    self.mainContainerNode.frame = self.contentView.bounds;
    
    CGRect backgroundFrame = self.bubbleBackgroundView.frame;

    CGRect previousContextContentFrame = self.mainContextSourceNode.contentRect;
    self.mainContextSourceNode.contentRect = backgroundFrame;
    
    [self.mainContainerNode targetNodeForActivationProgressContentRectForOCWithRect:self.mainContextSourceNode.contentRect];

    if(!CGSizeEqualToSize(previousContextContentFrame.size, self.mainContextSourceNode.bounds.size) || !CGRectEqualToRect(previousContextContentFrame, self.mainContextSourceNode.contentRect)) {
        [self.mainContextSourceNode layoutUpdatedForOCWithSize:self.mainContextSourceNode.bounds.size];
    }

}

- (void)onEndDisplay {
//    [self.mainContextSourceNode layoutUpdatedForOCWithSize:self.mainContextSourceNode.bounds.size];
}

-(void) layoutTrailingView {
    
    if([[self class] hiddenBubble]) {
        self.trailingView.lim_top = self.messageContentView.lim_height - self.trailingView.lim_height - 5.0f;
        self.trailingView.lim_left = self.messageContentView.lim_width - self.trailingView.lim_width - 5.0f;
    }else{
        self.trailingView.lim_top = self.messageContentView.lim_height - self.trailingView.lim_height + 2.0f;
        self.trailingView.lim_left = self.messageContentView.lim_width - self.trailingView.lim_width;
    }
    
   
}


-(void) layoutReaction {
    CGFloat reactionOffset = 4.0f;
    if([self.messageModel isSend]) {
        self.reactionView.lim_left = self.bubbleBackgroundView.lim_left - self.reactionView.lim_width + reactionOffset;
    }else{
        self.reactionView.lim_left = self.bubbleBackgroundView.lim_right - reactionOffset;
    }
    
    self.reactionView.lim_top = self.bubbleBackgroundView.lim_bottom  -  self.reactionView.lim_height - 10.0f;
}

-(UIImage*) bubbleImage {
    if([[self class] hiddenBubble]) {
        return nil;
    }
    WKBubblePostion bubblePosition = [[self class] bubblePosition:self.messageModel];
    UIImage *img;
    NSString *imgName;
    if(self.messageModel.isSend) {
        if(bubblePosition == WKBubblePostionFirst) {
            imgName = @"Conversation/Messages/MessageSendBubbleFirst";
        }else  if(bubblePosition == WKBubblePostionMiddle){
            imgName = @"Conversation/Messages/MessageSendBubbleMiddle";
        }else {
            imgName = @"Conversation/Messages/MessageSendBubble";
        }
        img = [self getImageNameForBaseModule:imgName] ;
        img = [img resizableImageWithCapInsets:UIEdgeInsetsMake(img.size.height/2.0f - 4.0f,img.size.width/2.0f - 4.0f, img.size.height/2.0f - 4.0f, img.size.width/2.0f - 4.0f) resizingMode:UIImageResizingModeStretch];
    }else {
        if(bubblePosition == WKBubblePostionFirst) {
            imgName = @"Conversation/Messages/MessageReceiverBubbleFirst";
        }else  if(bubblePosition == WKBubblePostionMiddle){
            imgName = @"Conversation/Messages/MessageReceiverBubbleMiddle";
        }else {
            imgName = @"Conversation/Messages/MessageReceiverBubble";
        }
        img = [self getImageNameForBaseModule:imgName] ;
        img = [img resizableImageWithCapInsets:UIEdgeInsetsMake(img.size.height/2.0f - 4.0f,img.size.width/2.0f - 4.0f, img.size.height/2.0f - 4.0f, img.size.width/2.0f - 4.0f) resizingMode:UIImageResizingModeStretch];
    }
    img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return img;
}



-(void) layoutName {
    WKBubblePostion position = [[self class] bubblePosition:self.messageModel];
    if(!self.nameLbl.hidden) {
        if(position == WKBubblePostionLast || position == WKBubblePostionSingle) {
            self.nameLbl.lim_left = WKLastBubbleOffsetSpace;
        }else{
            self.nameLbl.lim_left = 0.0f;
        }
        
        self.nameLbl.lim_top =  -self.nameLbl.lim_height - 4.0f;
    }
}


+(CGFloat)getWidthWithText:(NSString*)text height:(CGFloat)height font:(CGFloat)font{
    CGRect rect = [text boundingRectWithSize:CGSizeMake(MAXFLOAT, height) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:font]} context:nil];
    return rect.size.width;
    
}

-(void) sendFailPressed {
    __weak typeof(self) weakSelf = self;
    [WKAlertUtil alert:LLang(@"重发该消息") buttonsStatement:@[LLang(@"取消"),LLang(@"重发")] chooseBlock:^(NSInteger buttonIdx) {
        if(buttonIdx == 1) {
            [weakSelf.conversationContext resendMessage:weakSelf.messageModel.message];
        }
    }];
}

-(void) animationCheckBox:(BOOL)show {
    __weak typeof(self) weakSelf = self;
    self.checkBox.hidden = NO;
    [UIView animateWithDuration:0.25f animations:^{
        [weakSelf layoutSubviews];
        
    } completion:^(BOOL finished) {
        if(!show) {
            weakSelf.checkBox.hidden = YES;
        }
    }];
    
}

// 正文边距
+(UIEdgeInsets) contentEdgeInsets:(WKMessageModel*) model {
//    CGSize size = [self trailingViewSize:model];
//    return UIEdgeInsetsMake(WK_CONTENT_INSETS.top, WK_CONTENT_INSETS.left, WK_CONTENT_INSETS.bottom, WK_CONTENT_INSETS.right+size.width);
   
    if([self hiddenBubble]) {
        WKBubblePostion position = [self bubblePosition:model];
        if(position == WKBubblePostionLast || position == WKBubblePostionSingle) {
            if(model.isSend) {
                return UIEdgeInsetsMake(0, 0,0,WKLastBubbleOffsetSpace);
            }
            return UIEdgeInsetsMake(0, WKLastBubbleOffsetSpace,0,0);
        }
        return UIEdgeInsetsMake(0, 0,0,0);
    }
    
    WKBubblePostion position = [self bubblePosition:model];
    
    if(model.isSend) {
        if(position == WKBubblePostionLast || position == WKBubblePostionSingle) { // 最后一条消息
            return UIEdgeInsetsMake(WK_CONTENT_INSETS.top, WK_CONTENT_INSETS.left + WKLastBubbleOffsetSpace, WK_CONTENT_INSETS.bottom, WK_CONTENT_INSETS.right+WKLastBubbleOffsetSpace);
        }
        return UIEdgeInsetsMake(WK_CONTENT_INSETS.top, WK_CONTENT_INSETS.left+WKLastBubbleOffsetSpace, WK_CONTENT_INSETS.bottom, WK_CONTENT_INSETS.right);
    }else{
        if(position == WKBubblePostionLast || position == WKBubblePostionSingle) {
            return UIEdgeInsetsMake(WK_CONTENT_INSETS.top, WK_CONTENT_INSETS.left+WKLastBubbleOffsetSpace, WK_CONTENT_INSETS.bottom, WK_CONTENT_INSETS.right);
        }
    }
   
    return UIEdgeInsetsMake(WK_CONTENT_INSETS.top, WK_CONTENT_INSETS.left, WK_CONTENT_INSETS.bottom, WK_CONTENT_INSETS.right);
}
// 气泡边距
+(UIEdgeInsets) bubbleEdgeInsets:(WKMessageModel*) model contentSize:(CGSize)contentSize{
    WKBubblePostion position = [self bubblePosition:model];
    CGFloat top = 0.0f;
    CGFloat bottom = WK_BUBBLE_INSETS.bottom;
    CGFloat right = WK_BUBBLE_INSETS.right;
    CGFloat left = WK_BUBBLE_INSETS.left;
    
    if(model.contentType != WK_TYPING) {
        if(position == WKBubblePostionFirst || position == WKBubblePostionSingle ) {
            top =  WK_NICKNAME_HEIGHT + 5.0f;
        }
    }
    
   
    if(position == WKBubblePostionLast || position == WKBubblePostionSingle) { // 最后一条消息
        bottom +=10.0f;
        if(model.isSend) {
            right -= WKLastBubbleOffsetSpace;
        }else{
            left-= WKLastBubbleOffsetSpace;
        }
        
    }
//    if(model.reactions && model.reactions.count>0) {
//        bottom += [WKReactionView height];
//    }
    return UIEdgeInsetsMake(top, left, bottom, right);
}


+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth font:(UIFont*)font{
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:font, NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}

- (UILabel *)errorLbl {
    if(!_errorLbl) {
        _errorLbl = [[UILabel alloc] init];
        _errorLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _errorLbl.numberOfLines = 0;
        _errorLbl.lim_width = WKScreenWidth - errorTipLeftSpace - errorTipRightSpace;
        _errorLbl.textColor = [WKApp shared].config.tipColor;
        _errorLbl.font = [[WKApp shared].config appFontOfSize:errorTipFontSize];
        [_errorLbl onClick:^(id<WKMatchToken> token) {
            if(token.type == WKatchTokenTypeLink2) {
                WKLinkToken *linkToken = (WKLinkToken*)token;
                NSURL *url = [NSURL URLWithString:linkToken.linkContent];
                if([url.scheme hasPrefix:[WKApp shared].config.appSchemaPrefix]) {
                    [[WKSchemaManager shared]handleURL:url];
                }
            }
            
        }];
        
    }
    return _errorLbl;
}

- (UIButton *)navigateToMessageBtn {
    if(!_navigateToMessageBtn) {
        _navigateToMessageBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 28.0f, 28.0f)];
        [_navigateToMessageBtn setImage:[self getImageNameForBaseModule:@"Conversation/Messages/NavigateToMessageIcon"] forState:UIControlStateNormal];
        
//        _navigateToMessageBtn.layer.masksToBounds = YES;
        _navigateToMessageBtn.layer.cornerRadius = _navigateToMessageBtn.lim_height/2.0f;
        [_navigateToMessageBtn setContentEdgeInsets:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
        _navigateToMessageBtn.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.2f];
        _navigateToMessageBtn.hidden = !self.showNavigateToMessage;
        _navigateToMessageBtn.userInteractionEnabled = NO;
    }
    return _navigateToMessageBtn;
}

-(void) navigateToMessagePressed {
    if(self.conversationContext && [self.conversationContext respondsToSelector:@selector(navigateToMessage:)]) {
        [self.conversationContext navigateToMessage:self.messageModel];
    }
}

- (void)setShowNavigateToMessage:(BOOL)showNavigateToMessage {
    _showNavigateToMessage = showNavigateToMessage;
    self.navigateToMessageBtn.hidden = !_showNavigateToMessage;
}

-(UIImage*) getImageNameForBaseModule:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

 + (BOOL) hiddenBubble {
    return NO;
}

-(BOOL) hiddenFlameProgress {
    return NO;
}

+(BOOL) isShowName:(WKMessageModel*)model {
    WKBubblePostion position = [self bubblePosition:model];
    return  !model.isSend && model.channel.channelType != WK_PERSON &&  (position == WKBubblePostionFirst || position == WKBubblePostionSingle);
}

#define mark -- WKCheckBoxDelegate

- (void)didTapCheckBox:(WKCheckBox *)checkBox {
    [self didTapCheck];
}
@end

@interface WKBubbleBackgroundView ()

@property(nonatomic,assign) BOOL hasAnimate;

@property(nonatomic,assign) BOOL completionAnmiate;

@end

@implementation WKBubbleBackgroundView

- (void)layoutSubviews {
    [super layoutSubviews];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    self.originalViewFrame = self.frame;
    self.completionAnmiate = false;
    
    [UIView animateWithDuration:1.0f delay:0.0f usingSpringWithDamping:80.0f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self targetView].transform = CGAffineTransformMakeScale(0.5f,0.5f);
    } completion:^(BOOL finished) {
        self.completionAnmiate  = finished;
        if(finished && self.onAnimateCompletion) {
            self.onAnimateCompletion();
        }
    }];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
  
}

-(UIView*) targetView {
    return self.superview;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
   // [self cancelAnimate];
}


- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
}

-(void) cancelAnimate {
    [[self targetView].layer removeAllAnimations];
    if(!self.completionAnmiate) {
        [[self targetView].layer animateSpringFrom:@(0.9f) to:@(1.0f) keyPath:@"transform.scale" duration:0.5f delay:0.0f initialVelocity:0.0f damping:80.0f removeOnCompletion:false additive:false completion:^(BOOL v){
            self.frame = self.originalViewFrame;
            self.completionAnmiate  = true;
        }];
    }
   
    self.hasAnimate = false;
}


@end
