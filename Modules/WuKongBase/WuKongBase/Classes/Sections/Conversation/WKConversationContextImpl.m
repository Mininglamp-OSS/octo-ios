//
//  WKConversationContextImpl.m
//  WuKongBase
//
//  Created by tt on 2022/5/19.
//

#import "WKConversationContextImpl.h"
#import <objc/runtime.h>
#import "WKUserHandleVC.h"
#import "WKMentionUserCell.h"
#import "WKInputMentionCache.h"
#import "WKReplyView.h"
#import "WKMessageEditView.h"
#import <WuKongBase/WuKongBase-Swift.h>

@interface WKConversationContextImpl ()

/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

@property(nonatomic,strong) WKChannel *channel;
@property(nonatomic,weak) WKConversationView *conversationView;

@property(nonatomic,weak) WKConversationVM *conversationVM;

// ---------- mention @ ----------
@property(nonatomic,strong) WKUserHandleVC *mentionUserHandleVC;
@property(nonatomic,strong) WKInputMentionCache *mentionCache;


// ---------- 长按菜单 ----------
//@property(nonatomic,strong) WKContextMenusVC *messageActionsVC;
//@property(nonatomic,strong) UILongPressGestureRecognizer *messageActionLongPressGesture;

///避免多个cell同时长按
//@property (nonatomic,assign)BOOL messageActionsVCIsShow;



@end

@implementation WKConversationContextImpl

-(instancetype) initWithChannel:(WKChannel*)channel conersationView:(WKConversationView*)conversationView conversationVM:(WKConversationVM*)conversationVM{
    self = [super init];
    if (self) {
        self.channel = channel;
        self.conversationView = conversationView;
        self.conversationVM = conversationVM;
    }
    return self;
}
- (void)showMentionUsers {
    [self showMentionUsers:@""];
}

-(NSString*) inputText {
    return [self.conversationView.input inputText];
}

-(NSRange) inputSelectedRange {
    return [self.conversationView.input inputSelectedRange];
}

-(void) inputDeleteText:(NSRange)range {
    [self.conversationView.input inputDeleteText:range];
}

/**
 往输入框插入文本
 */
-(void) inputInsertText:(NSString *)text {
    [self.conversationView.input inputInsertText:text];
}

-(void) inputSetText:(NSString*)text {
    [self.conversationView.input inputSetText:text];
}

-(void) inputTextToSend {
    NSString *text = self.conversationView.input.textView.text;
    [self.conversationView.input inputSetText:@""];
    [self sendTextMessage:text];
}

// 展示mention用户列表 (//keyword = nil  都不显示 keyword=“” 为显示所有)
-(void) showMentionUsers:(NSString *)keyword {
    [self addMentionUserHandleVCIfNeed];
    __weak typeof(self) weakSelf = self;
    [self getMentionUserListWithKeyword:keyword complete:^(NSArray<WKMentionUserCellModel *> *users) {
        if(![weakSelf array:(NSArray<WKMentionUserCellModel*>*)weakSelf.mentionUserHandleVC.items isEqualTo:users]) {
            [weakSelf.mentionUserHandleVC reload:users];
        }
    }];
    
    
    return;
}



- (void)replyTo:(WKMessage *)message {
    [self.conversationView.input becomeFirstResponder];
    self.conversationView.replyMessage = message;
    
    UIView *replyView = [self replyView:message];
    
    [self setInputTopView:replyView];
    
    // 添加@
    [self addMention:message.fromUid];
    
}

-(UIView*) replyView:(WKMessage*)message {
    __weak typeof(self) weakSelf = self;
    WKReplyView *replyView = [WKReplyView message:message];
    [replyView setOnClose:^{
        weakSelf.conversationView.replyMessage = nil;
        [weakSelf setInputTopView:nil];
    }];
    return replyView;
}

- (WKMessage *)replyingMessage {
    return self.conversationView.replyMessage;
}

-(BOOL) hasReply {
    if(self.conversationView.replyMessage) {
        return true;
    }
    return false;
}

-(void) showConversationTopView:(BOOL)show animated:(BOOL)animated{
    [self.conversationView showTopView:show animated:animated];
}


/**
 编辑消息
 */

-(void) editTo:(WKMessage*)message {
    if(message.contentType!=WK_TEXT) {
        return;
    }
    self.conversationView.editMessage = message;
    
    WKTextContent *textContent = (WKTextContent*)message.content;
    if(message.remoteExtra.contentEdit) {
        textContent = (WKTextContent*)message.remoteExtra.contentEdit;
    }
    [self.conversationView.input becomeFirstResponder];
    [self.conversationView.input inputSetText:textContent.content];
    [self.conversationView.input resetCurrentInputHeight];
    
    UIView *editView = [self editView:message];
    [self setInputTopView:editView];
}

-(UIView*) editView:(WKMessage*)message {
    __weak typeof(self) weakSelf = self;
    WKMessageEditView *editView = [WKMessageEditView message:message];
    [editView setOnClose:^{
        weakSelf.conversationView.editMessage = nil;
        [weakSelf setInputTopView:nil];
    }];
    return editView;
}

- (WKMessage *)editingMessage {
    return self.conversationView.editMessage;
}

-(BOOL) hasEdit {
    if(self.conversationView.editMessage) {
        return true;
    }
    return false;
}

-(void) setInputTopView:(UIView* __nullable)view {
    __weak typeof(self) weakSelf = self;
    [self.conversationView.input setTopView:view animateBlock:^{
        [weakSelf.conversationView layoutSubviews];
        [weakSelf layoutMentionUserHandle];
    }];
    [self callConversationInputChangeDelegate];
}

- (UIView *)inputTopView {
    return self.conversationView.input.topView;
}

-(void) inputBecomeFirstResponder {
    [self.conversationView.input becomeFirstResponder];
}

-(void) endEditing {
    [self.conversationView.input endEditing];
}

-(NSArray<WKMessageModel*>*) getMessagesWithContentType:(NSInteger)contentType {
    return [self.conversationView.messageListView getMessagesWithContentType:contentType];;
}

- (void)startRecordingVoiceMessage {
    [[WKSDK shared].mediaManager stopAudioPlay];
    NSArray *voiceMessages = [self getMessagesWithContentType:WK_VOICE];
    if(voiceMessages) {
        for (WKMessageModel *voiceMessage in voiceMessages) {
            if(voiceMessage.voicePlayStatus == WKVoicePlayStatusPlaying) {
                voiceMessage.voicePlayStatus = WKVoicePlayStatusNoPlay;
                [self refreshCell:voiceMessage];
            }
        }
    }
}

- (void)refreshCell:(WKMessageModel *)messageModel {
    [self.conversationView.messageListView refreshCell:messageModel];
}

- (NSArray<NSString *> *)dates {
    
    return [self.conversationView.messageListView dates];
}

- (NSArray<WKMessageModel *> *)messagesAtDate:(NSString *)date {
    return [self.conversationView.messageListView messagesAtDate:date];
}

-(UIViewController*) targetVC {
    return self.conversationView.lim_viewController;
}

- (NSArray<UITableViewCell *> *)visibleCells {
    return [self.conversationView.messageListView visibleCells];
}



/// 添加@
/// @param uid 被@人的uid
-(void) addMention:(NSString *)uid{
    if(self.channel.channelType == WK_PERSON || self.channel.channelType == WK_CustomerService) { // 单聊不能@
        return;
    }
    if(!uid || [uid isEqualToString:@""] || [uid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return;
    }
    
    NSString *str =  [self addMentionToCache:@[uid]];
    [self.conversationView.input inputInsertText:str];
    [self.conversationView.input becomeFirstResponder];
    
}

- (void)setMultipleOn:(BOOL)multiple selectedMessage:(WKMessageModel *)messageModel {
    [self.conversationView setMultipleOn:multiple selectedMessage:messageModel];
}

/// 定位到指定的消息
/// @param messageSeq 通过消息messageSeq定位消息
-(void) locateMessageCell:(uint32_t)messageSeq {
    [self.conversationView.messageListView locateMessageCell:messageSeq];
}

-(UITableViewCell*) cellForRowAtIndex:(NSIndexPath*)indexPath {
    return [self.conversationView.messageListView cellForRowAtIndex:indexPath];
}

-(void) hideMentionUsers {
    //    [self showMentionUsers:nil];
    [self.mentionUserHandleVC reload:@[]];
}

-(WKMessage*) sendTextMessage:(NSString*)text {
    return [self sendTextMessage:text entities:nil];
}

- (WKChannelInfo *)getChannelInfo {
    return [WKSDK.shared.channelManager getChannelInfo:self.channel];
}

-(WKMessage*) sendTextMessage:(NSString*)text entities:(NSArray<WKMessageEntity*>*)entities {
    return [self sendTextMessage:text entities:entities robotID:nil];
}

-(NSArray<NSTextCheckingResult*>*) ranges:(NSString*)text pattern:(NSString*)pattern{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray *results = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    return results;
}

-(NSArray<WKMessageEntity*>*) entities:(NSString*)text mentionCache:(WKInputMentionCache*)mentionCache{
    
    // -------------------- @ --------------------
    NSMutableArray<WKMessageEntity*> *entities = [NSMutableArray array];
    NSArray<WKInputMentionItem*> *mentionItems =  mentionCache.items;
    NSMutableArray<WKMessageEntity*> *newMentionEntities = [NSMutableArray array];
    if(mentionItems && mentionItems.count>0) {
        
        for (WKInputMentionItem *mentionItem in mentionItems) {
            NSString *mentionName = [NSString stringWithFormat:@"%@%@",WKInputAtStartChar,mentionItem.name];
            NSArray<NSTextCheckingResult*> *results = [self ranges:text pattern:mentionName];
            if(results && results.count>0) {
                for (NSTextCheckingResult *result in results) {
                    BOOL exist = false;
                    for (WKMessageEntity *existEntity in newMentionEntities) {
                        if(NSLocationInRange(result.range.location, existEntity.range)) {
                            exist = true;
                            break;
                        }
                    }
                    if(!exist) {
                        WKMessageEntity *entity = [[WKMessageEntity alloc] init];
                        entity.type = WKMentionRichTextStyle;
                        entity.value = mentionItem.uid;
                        entity.range = result.range;
                        [newMentionEntities addObject:entity];
                    }
                    
                }
            }
        }
        
    }
    [entities addObjectsFromArray:newMentionEntities];
    
    // -------------------- 链接 --------------------
    NSArray<id<WKMatchToken>> *linkTokens = [WKRichTextParseService.shared parseLink:text];
    if(linkTokens && linkTokens.count>0) {
        for (id<WKMatchToken> linkToken in linkTokens) {
            if(linkToken.type != WKatchTokenTypeLink) {
                continue;
            }
            BOOL locationInRange = false;
            if(newMentionEntities.count>0) {
                for (WKMessageEntity *mentionEntity in newMentionEntities) {
                    if(NSLocationInRange(linkToken.range.location, mentionEntity.range)) {
                        locationInRange = true;
                        break;
                    }
                }
            }
            if(!locationInRange) {
                WKMessageEntity *entity = [[WKMessageEntity alloc] init];
                entity.type = WKLinkRichTextStyle;
                entity.range = linkToken.range;
                [entities addObject:entity];
            }
        }
    }
    
    
    return entities;
}

-(NSArray<WKMessageEntity*>*) entities:(NSString*)text {
    
    return [self entities:text mentionCache:self.mentionCache];
}

-(WKMentionedInfo*) mentionedInfo:(NSString*)text mentionCache:(WKInputMentionCache*)mentionCache{
    WKMentionedInfo  *mentionedInfo;
    NSArray<NSString*> *mentionUids = [mentionCache allMentionUid:text];
    if(mentionUids && mentionUids.count>0) {
        if([mentionUids containsObject:@"all"]) {
            mentionedInfo = [[WKMentionedInfo alloc] initWithMentionedType:WK_Mentioned_All];
        }else{
            mentionedInfo = [[WKMentionedInfo alloc] initWithMentionedType:WK_Mentioned_Users uids:mentionUids];
        }
        
    }
    return mentionedInfo;
}

-(WKMentionedInfo*) mentionedInfo:(NSString*)text {
    return [self mentionedInfo:text mentionCache:self.mentionCache];
}

-(WKMessage*) sendTextMessage:(NSString*)text entities:(NSArray<WKMessageEntity*>*)entities robotID:(NSString*)robotID{
    if(!text || [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) {
        return nil;
    }
    
    NSMutableArray<WKMessageEntity*> *newEntities = [NSMutableArray arrayWithArray:entities];
    
    WKTextContent *content = [[WKTextContent alloc] initWithContent:text];
    
    WKMessage *editMessage = self.conversationView.editMessage;
    
    // -------------------- @ 设置 --------------------
    if(editMessage) {
        content.mentionedInfo = [self mentionedInfo:text];
        WKMessageContent *editContent = editMessage.content;
        if(editMessage.remoteExtra.contentEdit) {
            editContent = editMessage.remoteExtra.contentEdit;
        }
        NSArray<WKMessageEntity*> *oldEntities = editContent.entities;
        NSString *oldText = ((WKTextContent*)editContent).content;
        if(oldEntities && oldEntities.count>0) {
            for (WKMessageEntity *oldEntity in oldEntities) {
                if([oldEntity.type isEqualToString:WKMentionRichTextStyle]) {
                    WKInputMentionItem *inputMentionItem = [WKInputMentionItem new];
                    inputMentionItem.uid = oldEntity.value;
                    inputMentionItem.name = [oldText substringWithRange:NSMakeRange(oldEntity.range.location+1, oldEntity.range.length-1)];
                    
                    [self.mentionCache addMentionItem:inputMentionItem];
                }
            }
        }
        
    }else{
        content.mentionedInfo = [self mentionedInfo:text];
       
    }
    
    
    [newEntities addObjectsFromArray:[self entities:text]];
     
   
    [self.mentionCache clean];
    

    
    // ---------- 回复逻辑  ----------
    WKMessage *replyMessage = self.conversationView.replyMessage;
    if(replyMessage) {
        WKReply *reply = [WKReply new];
        reply.messageID = [NSString stringWithFormat:@"%llu",replyMessage.messageId];
        
        reply.messageSeq = replyMessage.messageSeq;
        reply.fromUID = replyMessage.fromUid;
        if(replyMessage.from) {
            reply.fromName = replyMessage.from.name;
        }
        reply.content = replyMessage.content;
        content.reply = reply;
        
        // 清除回复状态
        self.conversationView.replyMessage = nil;
        __weak typeof(self) weakSelf = self;
        [self.conversationView.input setTopView:nil animateBlock:^{
            [weakSelf.conversationView layoutSubviews];
        }];
    }
    // ---------- 编辑逻辑  ----------
   
    if(editMessage) {
        WKTextContent *newTextContent = [[WKTextContent alloc] initWithContent:text];
        if(newEntities&&newEntities.count>0) {
            newTextContent.entities = newEntities;
        }
        content.robotID = robotID;
        [[WKSDK shared].chatManager editMessage:editMessage newContent:newTextContent];
        self.conversationView.editMessage = nil;
        __weak typeof(self) weakSelf = self;
        [self.conversationView.input setTopView:nil animateBlock:^{
            [weakSelf.conversationView layoutSubviews];
        }];
        [self.conversationView.messageListView reloadData];
        
        [self.conversationView.messageListView animateMessageWithBlock:^{
            [self.conversationView layoutSubviews];
        }];
        
        return editMessage;
    }
    
  
    
    // ---------- 其它逻辑  ----------
    if(newEntities.count>0) {
        content.entities = newEntities;
    }
    content.robotID = robotID;
    
  return  [self sendMessage:content];
}


-(WKMessage*) sendMessage:(WKMessageContent*)content {
    WKSetting *setting = [WKSetting new];
    if(self.conversationVM.channelInfo) {
        setting.receiptEnabled = self.conversationVM.channelInfo.receipt;
        if(self.conversationVM.channelInfo.extra[@"msg_auto_delete"]) {
            setting.expire = [self.conversationVM.channelInfo.extra[@"msg_auto_delete"] integerValue];
        }
    }
//    if(self.channel.channelType == WK_PERSON) {
//        setting.signal = true; // 个人聊天进行signal加密
//    }

    // ---------- DM消息注入space_id（用于BotFather等系统Bot的会话隔离）----------
    NSString *currentSpaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if(currentSpaceId && currentSpaceId.length > 0 && self.channel.channelType == WK_PERSON) {
        content.spaceId = currentSpaceId;
    }

    // ---------- 阅后即焚  ----------
    WKChannelInfo *channelInfo = [self getChannelInfo];
    if(channelInfo && channelInfo.flame) {
        content.flame = channelInfo.flame;
        content.flameSecond = channelInfo.flameSecond;
    }
    NSString *topic = @"";
    if(self.conversationVM.channelInfo && self.conversationVM.channelInfo.parentChannel) {
        topic = [NSString stringWithFormat:@"%@@%hhu",self.conversationVM.channelInfo.parentChannel.channelId,self.conversationVM.channelInfo.parentChannel.channelType];
    }
    
    WKMessage *message = [[[WKSDK shared] chatManager] sendMessage:content channel:self.channel setting:setting topic:topic];
    if([[WKSDK shared].chatManager needStoreOfIntercept:message]) {
        [self.conversationView.messageListView sendMessage:[[WKMessageModel alloc] initWithMessage:message]];
    }
    return message;
    
}

-(void) resendMessage:(WKMessage*)message {
    
    WKMessageModel *messageModel = [[WKMessageModel alloc] initWithMessage:message];
    [self.conversationView.messageListView removeMessage:messageModel];
    
    WKMessage *newMessage = [[[WKSDK shared] chatManager] resendMessage:message];
    WKMessageModel *newMessageModel = [[WKMessageModel alloc] initWithMessage:newMessage];
    if([[WKSDK shared].chatManager needStoreOfIntercept:newMessage]) {
        [self.conversationView.messageListView sendMessage:newMessageModel];
    
    }
}

- (void)forwardMessage:(WKMessageContent *)content {
    WKMessage *message = [[WKSDK shared].chatManager forwardMessage:content channel:self.channel];
    [self.conversationView.messageListView sendMessage:[[WKMessageModel alloc] initWithMessage:message]];
}

-(void) longPressMessageCell:(WKMessageCell*)messageCell gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer{
    __weak typeof(self) weakSelf = self;
    [self endEditing];

    WKMessageModel *contextMessage = messageCell.messageModel;

    NSArray<WKMessageLongMenusItem*> *toolbarMenus;
    if(contextMessage.content.flame) {
        WKMessageLongMenusItem *revokeToolbarMenus = [[WKApp shared] invoke:WKPOINT_LONGMENUS_REVOKE param:@{@"message":contextMessage}];
        if(revokeToolbarMenus) {
            toolbarMenus = @[revokeToolbarMenus];
        }
    }else{
        toolbarMenus = [[WKApp shared] invokes:WKPOINT_CATEGORY_MESSAGE_LONGMENUS param:@{@"message":contextMessage}];
    }

    // Fix5: 获取手指触摸的 window 坐标，用于精准定位菜单
    CGPoint touchInWindow = [gestureRecognizer locationInView:nil];
    __weak typeof(messageCell) weakCell = messageCell;

    // 文本消息：长按直接进入全选模式，菜单在选区上方显示，无需单独「选择文字」按钮
    if (contextMessage.contentType == WK_TEXT) {
        NSArray *capturedMenus = [toolbarMenus copy];
        [messageCell startInBubbleTextSelectionWithMenuItems:capturedMenus];
        return;
    }

    // 非文本消息：显示常规内联菜单（定位在手指位置附近）
    [self showInlineMenuForCell:messageCell menuItems:toolbarMenus atTouchPoint:touchInWindow];
}

// ─── 自定义气泡内联菜单（替代 Telegram ContextController，避免黑屏） ───

-(void) showInlineMenuForCell:(WKMessageCell*)cell menuItems:(NSArray<WKMessageLongMenusItem*>*)items {
    CGPoint touch = [cell.bubbleBackgroundView convertRect:cell.bubbleBackgroundView.bounds toView:nil].origin;
    touch.y += cell.bubbleBackgroundView.bounds.size.height / 2.0f;
    [self showInlineMenuForCell:cell menuItems:items atTouchPoint:touch];
}

-(void) showInlineMenuForCell:(WKMessageCell*)cell menuItems:(NSArray<WKMessageLongMenusItem*>*)items atTouchPoint:(CGPoint)touchInWindow {
    if (!items.count) return;

    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    __weak typeof(self) weakSelf = self;
    __weak typeof(cell)  weakCell = cell;

    // 气泡在 window 中的绝对位置
    CGRect bubbleRect = [cell.bubbleBackgroundView convertRect:cell.bubbleBackgroundView.bounds toView:nil];

    // ── 遮罩层（轻微暗色，点击即关闭）
    UIButton *overlay = [[UIButton alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.08f];
    overlay.alpha = 0;
    [window addSubview:overlay];

    // ── 菜单卡片
    // ── 网格菜单：图标在上、文字在下、每行 4 个、最多 3 行（参考微信长按菜单）
    NSInteger colCount  = MIN(4, (NSInteger)items.count);
    NSInteger rowCount  = (items.count + colCount - 1) / colCount;
    CGFloat hPad        = 12.0f;
    CGFloat cardW       = MIN(window.frame.size.width - 24.0f, 380.0f);
    CGFloat cellW       = (cardW - hPad * 2) / colCount;
    CGFloat iconSz      = 24.0f;
    CGFloat cellH       = 12.0f + iconSz + 4.0f + 13.0f + 10.0f; // top+icon+gap+text+bottom
    CGFloat cardH       = rowCount * cellH + 8.0f; // 8pt top/bottom padding
    CGFloat cornerR     = 14.0f;

    // __block 前向引用：dismiss block 里捕获 card，card 需先声明
    __block UIView *card = nil;
    __block BOOL dismissed = NO;
    void(^dismiss)(void) = ^{
        if (dismissed) return;
        dismissed = YES;
        [UIView animateWithDuration:0.15 animations:^{
            card.alpha    = 0;
            overlay.alpha = 0;
        } completion:^(BOOL f) {
            [card removeFromSuperview];
            [overlay removeFromSuperview];
        }];
    };
    objc_setAssociatedObject(overlay, "dismiss", dismiss, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [overlay addTarget:self action:@selector(wk_inlineMenuOverlayTapped:) forControlEvents:UIControlEventTouchUpInside];

    card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardW, cardH)];
    card.layer.cornerRadius = cornerR;
    card.clipsToBounds = NO;
    card.layer.shadowColor  = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.18f;
    card.layer.shadowRadius  = 12.0f;
    card.layer.shadowOffset  = CGSizeMake(0, 4);

    UIView *clipView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardW, cardH)];
    clipView.backgroundColor = [WKApp shared].config.style == WKSystemStyleDark
        ? [UIColor colorWithRed:0.18 green:0.18 blue:0.20 alpha:1.0]
        : [UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1.0];
    clipView.layer.cornerRadius = cornerR;
    clipView.clipsToBounds = YES;
    [card addSubview:clipView];

    UIFont *textFont  = [UIFont systemFontOfSize:11.0f];
    UIColor *textColor = [WKApp shared].config.defaultTextColor;
    UIColor *iconTint  = textColor;

    for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
        WKMessageLongMenusItem *item = items[i];
        NSInteger col = i % colCount;
        NSInteger row = i / colCount;
        CGFloat cellX = hPad + col * cellW;
        CGFloat cellY = 4.0f + row * cellH; // 4pt top padding

        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(cellX, cellY, cellW, cellH)];
        btn.backgroundColor = [UIColor clearColor];
        [btn setBackgroundImage:[self wk_solidColorImage:[UIColor colorWithWhite:0.5 alpha:0.15]] forState:UIControlStateHighlighted];

        // 图标（居中，上方）
        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake((cellW - iconSz)/2, 12.0f, iconSz, iconSz)];
        iconView.image = item.icon ?: [UIImage systemImageNamed:@"ellipsis"];
        iconView.tintColor = iconTint;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        [btn addSubview:iconView];

        // 文字（居中，图标下方）
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(2, 12.0f + iconSz + 4.0f, cellW - 4, 13.0f)];
        lbl.text = item.title;
        lbl.font = textFont;
        lbl.textColor = textColor;
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.adjustsFontSizeToFitWidth = YES;
        lbl.minimumScaleFactor = 0.8f;
        [btn addSubview:lbl];

        WKMessageLongMenusItem *captured = item;
        objc_setAssociatedObject(btn, "itemDismiss", dismiss, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(btn, "itemAction", captured.onTap, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:self action:@selector(wk_inlineMenuItemTapped:) forControlEvents:UIControlEventTouchUpInside];
        [clipView addSubview:btn];

        // 列分割线
        if (col < colCount - 1 && i < (NSInteger)items.count - 1) {
            UIView *vSep = [[UIView alloc] initWithFrame:CGRectMake(cellX + cellW - 0.25f, cellY + 8, 0.5f, cellH - 16)];
            vSep.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.3];
            [clipView addSubview:vSep];
        }
        // 行分割线
        if (row < rowCount - 1 && i + colCount < (NSInteger)items.count) {
            CGFloat rowY = cellY + cellH - 0.25f;
            UIView *hSep = [[UIView alloc] initWithFrame:CGRectMake(hPad, rowY, cardW - hPad*2, 0.5f)];
            hSep.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.3];
            [clipView addSubview:hSep];
        }
    }

    // ── 定位：上方优先（不遮挡已选中文字），空间不足则放下方 ──
    CGFloat safeTop    = window.safeAreaInsets.top + 8;
    CGFloat safeBottom = window.frame.size.height - window.safeAreaInsets.bottom - 80;
    CGFloat cardX = bubbleRect.origin.x;
    if (cardX + cardW > window.frame.size.width - 8) cardX = window.frame.size.width - cardW - 8;
    cardX = MAX(8, cardX);
    // 气泡上方是否有足够空间
    CGFloat aboveY = touchInWindow.y - cardH - 12;
    CGFloat belowY = touchInWindow.y + 12;
    CGFloat cardY  = (aboveY >= safeTop) ? aboveY : belowY;
    cardY = MAX(safeTop, MIN(cardY, safeBottom - cardH));
    card.frame = CGRectMake(cardX, cardY, cardW, cardH);
    clipView.frame = CGRectMake(0, 0, cardW, cardH);

    [window addSubview:card];

    card.alpha = 0;
    card.transform = CGAffineTransformMakeScale(0.88, 0.88);
    [UIView animateWithDuration:0.18 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0 options:0 animations:^{
        card.alpha = 1;
        card.transform = CGAffineTransformIdentity;
        overlay.alpha = 1;
    } completion:nil];
}

-(void) wk_inlineMenuOverlayTapped:(UIButton *)btn {
    void(^dismiss)(void) = objc_getAssociatedObject(btn, "dismiss");
    if (dismiss) dismiss();
}

-(void) wk_inlineMenuItemTapped:(UIButton *)btn {
    void(^dismiss)(void) = objc_getAssociatedObject(btn, "itemDismiss");
    void(^action)(id) = objc_getAssociatedObject(btn, "itemAction");
    if (dismiss) dismiss();
    if (action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            action(self);
        });
    }
}

-(UIImage *) wk_solidColorImage:(UIColor *)color {
    CGRect r = CGRectMake(0,0,1,1);
    UIGraphicsBeginImageContextWithOptions(r.size, NO, 0);
    [color setFill]; UIRectFill(r);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/// 弹出文字选择界面，支持选取部分文字复制
-(void) showTextSelectionForMessage:(WKMessageModel *)model fromCell:(WKMessageCell *)cell {
    WKTextContent *textContent = nil;
    if ([model.content isKindOfClass:[WKTextContent class]]) {
        textContent = (WKTextContent *)model.content;
    }
    NSString *rawText = textContent.content;
    if (!rawText.length) return;

    UIViewController *topVC = [WKNavigationManager shared].topViewController;

    // 背景遮罩
    UIView *dimView = [[UIView alloc] initWithFrame:topVC.view.bounds];
    dimView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35f];
    dimView.alpha = 0;

    // 文字选择容器
    CGFloat padding = 16.0f;
    CGFloat maxW = topVC.view.bounds.size.width - padding * 2;
    UITextView *tv = [[UITextView alloc] init];
    tv.text = rawText;
    tv.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    tv.textColor = [WKApp shared].config.defaultTextColor;
    tv.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    tv.layer.cornerRadius = 12.0f;
    tv.clipsToBounds = YES;
    tv.editable = NO;
    tv.selectable = YES;
    tv.scrollEnabled = YES;
    tv.contentInset = UIEdgeInsetsMake(8, 8, 8, 8);
    tv.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    CGFloat tvMaxH = topVC.view.bounds.size.height * 0.5f;
    CGFloat tvH = MIN([tv sizeThatFits:CGSizeMake(maxW, CGFLOAT_MAX)].height + 24.0f, tvMaxH);
    tv.frame = CGRectMake(padding, topVC.view.bounds.size.height - tvH - 60.0f, maxW, tvH);

    // 「复制」按钮
    UIButton *doneBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [doneBtn setTitle:LLang(@"复制") forState:UIControlStateNormal];
    doneBtn.titleLabel.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
    doneBtn.backgroundColor = [WKApp shared].config.themeColor;
    [doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    doneBtn.layer.cornerRadius = 10.0f;
    doneBtn.clipsToBounds = YES;
    doneBtn.frame = CGRectMake(padding, tv.frame.origin.y + tv.frame.size.height + 10.0f, maxW, 44.0f);

    [dimView addSubview:tv];
    [dimView addSubview:doneBtn];
    [topVC.view addSubview:dimView];

    // 用 block 捕获 tv，dismiss 时自动复制选中文字
    __weak UITextView *weakTV = tv;
    __weak UIView *weakDimView = dimView;
    void(^copyAndDismiss)(void) = ^{
        UITextView *strongTV = weakTV;
        if (strongTV) {
            NSString *selectedText = nil;
            if (strongTV.selectedRange.length > 0) {
                selectedText = [strongTV.text substringWithRange:strongTV.selectedRange];
            }
            if (!selectedText.length) {
                selectedText = strongTV.text;
            }
            if (selectedText.length > 0) {
                [UIPasteboard generalPasteboard].string = selectedText;
                [weakDimView.superview showHUDWithHide:LLang(@"已复制")];
            }
        }
        UIView *strongDim = weakDimView;
        [UIView animateWithDuration:0.2 animations:^{ strongDim.alpha = 0; } completion:^(BOOL f) { [strongDim removeFromSuperview]; }];
    };
    objc_setAssociatedObject(doneBtn, "copyAndDismiss", copyAndDismiss, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [doneBtn addTarget:self action:@selector(onTextSelectionDone:) forControlEvents:UIControlEventTouchUpInside];
    // 背景点击只关闭不复制
    void(^justDismiss)(void) = ^{
        UIView *strongDim = weakDimView;
        [UIView animateWithDuration:0.2 animations:^{ strongDim.alpha = 0; } completion:^(BOOL f) { [strongDim removeFromSuperview]; }];
    };
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTextSelectionBgTap:)];
    objc_setAssociatedObject(bgTap, "dismissBlock", justDismiss, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [dimView addGestureRecognizer:bgTap];

    [UIView animateWithDuration:0.2 animations:^{ dimView.alpha = 1; }];
    [tv becomeFirstResponder];
    [tv selectAll:nil];
}

-(void) onTextSelectionDone:(UIButton *)btn {
    void(^copyAndDismiss)(void) = objc_getAssociatedObject(btn, "copyAndDismiss");
    if (copyAndDismiss) copyAndDismiss();
}

-(void) onTextSelectionBgTap:(UITapGestureRecognizer *)gr {
    void(^dismiss)(void) = objc_getAssociatedObject(gr, "dismissBlock");
    if (dismiss) dismiss();
}

-(void) addMentionUserHandleVCIfNeed {
    if(self.mentionUserHandleVC.parentViewController) {
        return;
    }
    UIViewController *parentVC = self.conversationView.lim_viewController;
    [self layoutMentionUserHandle];
    [parentVC addChildViewController:self.mentionUserHandleVC];
    [self.conversationView insertSubview:self.mentionUserHandleVC.view belowSubview:self.conversationView.input];
    [self.mentionUserHandleVC didMoveToParentViewController:parentVC];
    
}


//keyword = nil为显示所有 keyword=“” 都不显示
-(void) getMentionUserListWithKeyword:(NSString*)keyword complete:(void(^)(NSArray<WKMentionUserCellModel*>*users))complete{

    __weak typeof(self) weakSelf = self;

    NSLog(@"[Mention] getMentionUserList channel=%@/%d keyword=%@", self.channel.channelId, self.channel.channelType, keyword);
    [[WKGroupManager shared] searchMembers:self.channel keyword:keyword limit:10000 complete:^(WKChannelMemberCacheType cacheType, NSArray<WKChannelMember *> * _Nonnull members) {
        NSLog(@"[Mention] searchMembers returned %lu members, cacheType=%ld", (unsigned long)members.count, (long)cacheType);
        WKMemberRole role =  weakSelf.conversationVM.memberRole;

        NSArray<WKMentionUserCellModel*>*users = [weakSelf membersToMentionUsers:members role:role keyword:keyword];
        NSLog(@"[Mention] final mention users count=%lu", (unsigned long)users.count);
        if(complete) {
            complete(users);
        }
    }];
    
   
}

-(NSArray<WKMentionUserCellModel*>*) membersToMentionUsers:(NSArray<WKChannelMember*>*)members role:(WKMemberRole)role keyword:(NSString*)keyword{

    NSMutableArray<WKMentionUserCellModel*> *users = [NSMutableArray array];
    // @所有人 对所有群成员可见，对齐 Web 端行为（移除管理员角色限制）
    NSString *allStr = LLang(@"所有人");
    if(!keyword || [keyword isEqualToString:@""] || [allStr containsString:keyword]) {
        [users addObject:[WKMentionUserCellModel uid:@"all" name:allStr]];
    }
    if(members && members.count>0) {
        for (WKChannelMember *member in members) {
            if([member.memberUid isEqualToString:[WKApp shared].loginInfo.uid]) {
                continue;
            }
            NSString *name = member.displayName;
            BOOL contain = false;
            if(![keyword isEqualToString:@""]) {
                if([name containsString:keyword]) {
                    contain = true;
                }
            }else{
                contain = true;
            }
            if(contain) {
                // 透传 member.extra 给 cell model，供 WKExternalViewerResolver 判定 @SpaceName 后缀。
                [users addObject:[WKMentionUserCellModel uid:member.memberUid
                                                        name:member.displayName
                                                   avatarURL:[NSURL URLWithString: [WKAvatarUtil getAvatar:member.memberUid]]
                                                       robot:member.robot
                                                      extras:member.extra]];
            }
        }
    }
    return users;
}

-(void) layoutMentionUserHandle {
    self.mentionUserHandleVC.view.frame = CGRectMake(0.0f, 0.0f, self.conversationView.lim_width, self.conversationView.lim_height - self.conversationView.input.lim_height);
}

-(BOOL) array:(NSArray<WKMentionUserCellModel*>*)array1 isEqualTo:(NSArray<WKMentionUserCellModel*>*)array2 {
    if(array1.count!=array2.count) {
        return false;
    }
    for (NSInteger i=0;i<array1.count;i++) {
        WKMentionUserCellModel *userModel1 =  array1[i];
        WKMentionUserCellModel *userModel2 =  array2[i];
        if(![userModel1.uid isEqualToString:userModel2.uid]){
            return false;
        }
    }
    return true;
}

- (BOOL)forbidden {
    if(self.conversationVM.memberOfMe && (self.conversationVM.memberOfMe.role == WKMemberRoleCreator || self.conversationVM.memberOfMe.role == WKMemberRoleManager)) {
        return false;
    }else {
        if(self.conversationVM.channelInfo) {
            NSInteger forbiddenExpirTime = [self.conversationVM.memberOfMe.extra[@"forbidden_expir_time"] integerValue];
            BOOL forbidden = self.conversationVM.channelInfo.forbidden || forbiddenExpirTime > 0;
            return forbidden;
        }
    }
    return false;
}


// 是否显示了@列表
-(BOOL) isShowMentionUserHandle {
    if(self.mentionUserHandleVC.parentViewController && self.mentionUserHandleVC.items.count>0) {
        return true;
    }
    return false;
}


- (WKUserHandleVC *)mentionUserHandleVC {
    if(!_mentionUserHandleVC) {
        _mentionUserHandleVC = [[WKUserHandleVC alloc] init];
        [_mentionUserHandleVC setRegisterCellBlock:^(UITableView *tableView,NSString * _Nonnull reuseIdentifier) {
            [tableView registerClass:WKMentionUserCell.class forCellReuseIdentifier:reuseIdentifier];
        }];
        __weak typeof(self) weakSelf = self;
        [_mentionUserHandleVC setOnSelect:^(WKFormItemModel * _Nonnull model) {
            WKMentionUserCellModel *userModel = (WKMentionUserCellModel*)model;
        
            NSString *str =  [weakSelf addMentionToCache:@[userModel.uid]];
            [weakSelf.conversationView.input replaceInputingMention:str];
        }];
    }
    return _mentionUserHandleVC;
}


-(void) addMentionItems:(NSArray<WKInputMentionItem *> *)items {
    for (WKInputMentionItem *item in items) {
        [self.mentionCache addMentionItem:item];
    }
}

-(NSString*) addMentionToCache:(NSArray<NSString*>*)uids {
    if(!uids || uids.count==0) {
        return @"";
    }

    NSArray<WKChannelMember*> *mentionMembers = [[WKChannelMemberDB shared] getMembersWithChannel:self.channel uids:[uids filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF in %@)",@[@"all"]]]];
    NSMutableString *str = [[NSMutableString alloc] initWithString:@""];

    NSMutableDictionary *memberDict = [NSMutableDictionary dictionary];
    if(mentionMembers && mentionMembers.count>0) {
        for (WKChannelMember *mentionMember in mentionMembers) {
            memberDict[mentionMember.memberUid?:@""] = mentionMember;
        }
    }

    for (NSString *uid in uids) {

        WKChannelMember *mentionMember =  memberDict[uid];

        WKInputMentionItem *item = [[WKInputMentionItem alloc] init];
        item.uid  = uid;
        if(mentionMember) {
            if(mentionMember.memberRemark && ![mentionMember.memberRemark isEqualToString:@""]) {
                item.name = [self handleMentionName:mentionMember.memberRemark];
            }else {
                item.name = [self handleMentionName:mentionMember.memberName];
            }
        }else if([uid isEqualToString:@"all"]) {
            item.name = LLang(@"所有人");
        }else  {
           WKChannelInfo *memberUserInfo =  [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:uid]];
            if(memberUserInfo) {
                item.name = [self handleMentionName:memberUserInfo.name];

            }else {
                item.name = @"";
            }
        }

        [self.mentionCache addMentionItem:item];
        [str appendString:WKInputAtStartChar];
        [str appendString:item.name];
        [str appendString:WKInputAtEndChar];
    }
    return str;
}

-(NSString*) handleMentionName:(NSString*)oldName {
    if(!oldName) {
        return @"";
    }
    return oldName;
//    NSString *newName = [oldName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
//    if([newName containsString:@" "]) { // 如果名字里包含空格 则取空格的前部（仿tg）
//       NSArray<NSString*> *nameArray = [newName componentsSeparatedByString:@" "];
//        newName = nameArray[0];
//    }
//    return newName;
}

- (WKInputMentionCache *)mentionCache {
    if(!_mentionCache) {
        _mentionCache = [WKInputMentionCache new];
    }
    return _mentionCache;
}

- (BOOL)isFuncGroupZooming {
    return [self.conversationView.input isFuncGroupZooming];
}

- (void)stopFuncGroupZoom {
    [self.conversationView.input stopFuncGroupZoom];
}

-(void) refreshInputView {
    [self.conversationView.input updateAndLayoutTextViewRightView];
}

- (BOOL)hasInputText {
    NSString *text = [self.conversationView.input inputText];
    if(text && ![text isEqualToString:@""]) {
        return  true;
    }
    return false;
}


- (NSLock *)delegateLock {
    if (_delegateLock == nil) {
        _delegateLock = [[NSLock alloc] init];
    }
    return _delegateLock;
}

-(NSHashTable*) delegates {
    if (_delegates == nil) {
        _delegates = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return _delegates;
}

- (void)addInputDelegate:(id<WKConversationInputDelegate>)delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}

- (void)removeInputDelegate:(id<WKConversationInputDelegate>)delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

-(void) callConversationInputChangeDelegate {
    [self.delegateLock lock];
    NSHashTable *copyDelegates =  [self.delegates copy];
    [self.delegateLock unlock];
    for (id delegate in copyDelegates) {//遍历delegates ，call delegate
        if(!delegate) {
            continue;
        }
        if ([delegate respondsToSelector:@selector(conversationInputChange:)]) {
            if (![NSThread isMainThread]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate conversationInputChange:self];
                });
            }else {
                [delegate conversationInputChange:self];
            }
        }
    }
}

- (void)dealloc {
    NSLog(@"[WKConversationContextImpl dealloc]");
}

@end
