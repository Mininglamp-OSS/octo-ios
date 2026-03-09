//
//  WKTextMessageCell.m
//  WuKongBase
//
//  Created by tt on 2019/12/28.
//

#import "WKTextMessageCell.h"
#import "WKApp.h"
#import "UIView+WK.h"
#import "WKMentionService.h"
#import "WKWebViewVC.h"
#import "WKActionSheetView2.h"
#import <ContactsUI/CNContactViewController.h>
#import <ContactsUI/CNContactPickerViewController.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKTipLabel.h"
#import "WKSecurityTipManager.h"
#import <WuKongBase/WuKongBase-Swift.h>

#define replyNameFontSize 13.0f


#define replyContentFontSize 14.0f

#define replyAvatarSize 16.0f

#define splitWidth 0.0f
#define replyNameLeftSpace 10.0f

#define textTopSpace 8.0f // 消息内容顶部距离

#define securityTipTopSpace 20.0f // 安全提醒距离文本顶部距离

#define securityTipFontSize 12.0f

#define replyToNameSpace 4.0f // 回复离名字的距离


@interface WKTextMessageCell ()<CNContactViewControllerDelegate,CNContactPickerDelegate>

@property(nonatomic,strong) UILabel *textLbl;
@property(nonatomic,strong) id selectLinkData;


// ---------- 回复 ----------
@property(nonatomic,strong) UIView *replyBox;
@property(nonatomic,strong) UIView *splitView;
@property(nonatomic,strong) UILabel *replyNameLbl;
@property(nonatomic,strong) UILabel *replyContentLbl;
@property(nonatomic,strong) WKUserAvatar *replyAvatarIcon;

// ---------- 安全提醒 ----------
@property(nonatomic,strong) WKTipLabel *securityTipLbl;

@end


@implementation WKTextMessageCell

+ (CGSize)sizeForMessage:(WKMessageModel *)model {
   CGSize size = [super sizeForMessage:model];
    CGFloat securityTipHeight = 0.0f;
    if(model.hasSensitiveWord && !model.isSend) {
        securityTipHeight +=securityTipTopSpace;
        CGSize tipSize = [[self class] getTextSize:[WKSecurityTipManager shared].tip maxWidth:[WKApp shared].config.messageContentMaxWidth fontSize:securityTipFontSize];
        securityTipHeight += tipSize.height + 5.0f + 5.0f; // 5.0f+5.0f 为上下边距
    }
    return CGSizeMake(size.width, size.height + securityTipHeight);
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    NSMutableAttributedString *attrStr = [[self class] parseAndCacheTextMessage:model];
    CGSize  messageTextSize =  [[self class] textSize:attrStr messageModel:model];
    CGSize size = messageTextSize;
    if([self hasReply:model]) {
        CGSize replyNameSize = [self getReplyNameSize:model];
        CGSize replyContentSize = [self getReplyContentSize:model];
        if(replyContentSize.height>replyContentFontSize+1) {
            replyContentSize.height = replyContentFontSize+1;
        }
        CGFloat nameTopSpace = 0.0f;
        if([self isShowName:model]) {
            nameTopSpace = replyToNameSpace;
        }
        size = CGSizeMake(MAX(MAX(messageTextSize.width, replyNameSize.width+replyNameLeftSpace+replyAvatarSize+splitWidth), replyContentSize.width) , messageTextSize.height + replyNameSize.height+replyContentSize.height+textTopSpace + nameTopSpace);
    }
    
    
    CGSize trailingSize = [WKTrailingView size:model];

    CGFloat lastlineWidth = [[self class] textLastlineWidth:attrStr messageModel:model];

    CGFloat lastLineWithTrailingWidth = lastlineWidth + trailingSize.width + WKTrailingLeft;
    if(lastLineWithTrailingWidth>[WKApp shared].config.messageContentMaxWidth) {
        size.height += WKTimeHeight;
    }else{
        size.width = MAX(size.width, lastLineWithTrailingWidth);
    }
    CGFloat nicknameWidth = 0.0f;
    if([self isShowName:model]) {
        CGSize nicknameSize =  [self getNicknameSize:model];
        nicknameWidth = nicknameSize.width;
    }
    
    return CGSizeMake(MAX(size.width, nicknameWidth), size.height);
   
}


-(void) initUI {
    [super initUI];
    self.textLbl = [[UILabel alloc] init];
//    self.textLbl.underLineForLink = false;
//    self.textLbl.delegate = self;

   
    
    [self.textLbl setFont:[[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize]];
    [_textLbl setBackgroundColor:[UIColor clearColor]];
//    [self.textLbl setTextColor:[WKApp shared].config.defaultTextColor];
    self.textLbl.numberOfLines = 0;
    self.textLbl.lineBreakMode = NSLineBreakByWordWrapping;
    [self.messageContentView addSubview:self.textLbl];
    
    // 回复
    [self.messageContentView addSubview:self.replyBox];
    [self.replyBox addSubview:self.splitView];
    [self.replyBox addSubview:self.replyNameLbl];
    [self.replyBox addSubview:self.replyContentLbl];
    [self.replyBox addSubview:self.replyAvatarIcon ];
    
    // 安全提醒
    [self.contentView addSubview:self.securityTipLbl];
    
}

-(void) removeAllGestureRecognizers {
    NSArray *gestures = self.contentView.gestureRecognizers;
    if(gestures && gestures.count>0) {
        for (UITapGestureRecognizer *gesture in gestures) {
            [self.contentView removeGestureRecognizer:gesture];
        }
    }
}


+(NSMutableAttributedString*) parseAndCacheTextMessage:(WKMessageModel*)message {
    
    
    if(message.streamOn && message.streamFlag!=WKStreamFlagEnd) { // 流式消息不缓存
        return [self getContentAttrStr:message];
    }
    
    static WKMemoryCache *memoryCache;
    if(!memoryCache) {
        memoryCache = [[WKMemoryCache alloc] init];
        memoryCache.maxCacheNum = 500; // TODO: 如果这里设置的过小 滑动会闪屏
    }
    NSString *key = [NSString stringWithFormat:@"%llu%@",message.messageId,message.clientMsgNo];
    WKTextContent *textContent =  (WKTextContent*)[message content];
    if(message.remoteExtra.contentEdit) {
        key = [NSString stringWithFormat:@"%@-edit-%lu",message.clientMsgNo,message.remoteExtra.editedAt];
        textContent = (WKTextContent*)message.remoteExtra.contentEdit;
    }
    if([textContent.format isEqualToString:@"html"]) {
        key = [NSString stringWithFormat:@"%@-%lu",key,(unsigned long)WKApp.shared.config.style]; // 如果是html需要加上主题
    }
    NSMutableAttributedString *attrStr =  [memoryCache getCache:key];
    if(attrStr) {
        return attrStr;
    }
    
    attrStr = [self getContentAttrStr:message];
    
//    attrStr = [[self class] parseText:textContent isSend:message.isSend parseBefore:nil];
    if(key) {
        [memoryCache setCache:attrStr forKey:key];
    }
  
    
    return attrStr;
}

+(NSMutableAttributedString*) getContentAttrStr:(WKMessageModel*)message {
    WKTextContent *textContent =  (WKTextContent*)[message content];
    if(message.remoteExtra.contentEdit) {
        textContent = (WKTextContent*)message.remoteExtra.contentEdit;
    }
    NSMutableString *content = [[NSMutableString alloc] initWithString:textContent.content];
    if(message.streams && message.streams.count>0) {
        for (WKStream *stream in message.streams) {
            if([stream.content isKindOfClass:WKTextContent.class]) {
                WKTextContent *textContent = (WKTextContent*)stream.content;
                [content appendString:textContent.content];
            }
        }
    }
    
    NSArray<id<WKMatchToken>> *tokens = [self getTokens:message text:content];
    
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] init];
    attrStr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    
    [attrStr lim_render:content tokens:tokens];
    
    return attrStr;
}

+(NSMutableAttributedString*) parseText:(WKTextContent*)content isSend:(BOOL)isSend parseBefore:(void(^)(NSMutableAttributedString *attr))parseBeforeBlock{
    
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] init];
    attrStr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    if(parseBeforeBlock) {
        parseBeforeBlock(attrStr);
    }
    if(content.content) {
        if(content.format && [content.format isEqualToString:@"html"]) {
            UIColor *textColor;
            if(isSend) {
                textColor =  [WKApp shared].config.messageSendTextColor;
            }else {
                textColor = [WKApp shared].config.messageRecvTextColor;
            }
            NSString *temp = [NSString stringWithFormat:@"<style>body{font-size:%0.0fpx;color:%@}</style>%@",[WKApp shared].config.messageTextFontSize,[textColor toHexRGB],content.content];
            [attrStr appendAttributedString:[[NSAttributedString alloc] initWithData:[temp dataUsingEncoding:NSUTF8StringEncoding] options:@{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType,NSCharacterEncodingDocumentAttribute:@(NSUTF8StringEncoding)} documentAttributes:nil error:nil]];
        }else {
            [attrStr lim_parse:content.content mentionInfo:content.mentionedInfo];
        }
    }
    
    
   
    return  attrStr;
}

+(NSArray<id<WKMatchToken>>*) getTokens:(WKMessageModel*)message text:(NSString*)text{
    NSMutableArray<id<WKMatchToken>> *tokens = [NSMutableArray array];
    @try {
        
        NSArray<WKMessageEntity*> *entities = message.content.entities;
        if(message.remoteExtra.contentEdit) {
            entities = message.remoteExtra.contentEdit.entities;
        }
        
        if(entities && entities.count>0) {
           
            for (WKMessageEntity *messageEntiy in entities) {
                if(!messageEntiy.type) {
                    continue;
                }
                if(messageEntiy.type && [messageEntiy.type isEqualToString:WKMentionRichTextStyle]) {
                   NSString *mentionText =  [text substringWithRange:messageEntiy.range];
                    
                    NSRange range = messageEntiy.range;
                    if([mentionText hasSuffix:@" "]) {
                        range = NSMakeRange(range.location, range.length-1);
                    }
                    
                    WKMetionToken *token = [WKMetionToken new];
                    token.range = range;
                    token.uid = messageEntiy.value?:@"";
                    token.text = [text substringWithRange:range];
                    [tokens addObject:token];
                }else if([messageEntiy.type isEqualToString:WKLinkRichTextStyle]) {
                    WKLinkToken *token = [WKLinkToken new];
                    token.range = messageEntiy.range;
                    token.linkText = [text substringWithRange:messageEntiy.range];
                    [tokens addObject:token];
                }
            }
        }
    } @catch (NSException *exception) {
        WKLogDebug(@"解析文本消息的 token失败！->%@ %@",text,exception);
    } @finally {
        
    }
    return tokens;
}


+(CGSize) textSize:(NSMutableAttributedString*)attrStr messageModel:(WKMessageModel*)model{
    
    if(model.streamOn && model.streamFlag!=WKStreamFlagEnd) { // 流式消息不缓存
        return [attrStr size:[WKApp shared].config.messageContentMaxWidth];
    }
    
    NSString *key = [NSString stringWithFormat:@"%@-size",model.clientMsgNo];
    if(model.remoteExtra.contentEdit) {
        key = [NSString stringWithFormat:@"%@-size-edit-%lu",model.clientMsgNo,model.remoteExtra.editedAt];
    }
    static WKMemoryCache *memoryCache;
    if(!memoryCache) {
        memoryCache = [[WKMemoryCache alloc] init];
        memoryCache.maxCacheNum = 100;
    }
    NSString  *sizeStr =  [memoryCache getCache:key];
    if(sizeStr) {
        return CGSizeFromString(sizeStr);
    }
    CGSize size = [attrStr size:[WKApp shared].config.messageContentMaxWidth];
    [memoryCache setCache:NSStringFromCGSize(size) forKey:key];
    return size;
}

+(CGFloat) textLastlineWidth:(NSMutableAttributedString*)attrStr messageModel:(WKMessageModel*)model{
    
    if(model.streamOn && model.streamFlag!=WKStreamFlagEnd) { // 流式消息不缓存
        return [attrStr lastlineWidth:[WKApp shared].config.messageContentMaxWidth];
    }
    
    NSString *key = [NSString stringWithFormat:@"%@-lastLine",model.clientMsgNo];
    if(model.remoteExtra.contentEdit) {
        key = [NSString stringWithFormat:@"%@-lastLine-edit-%lu",model.clientMsgNo,model.remoteExtra.editedAt];
    }
    static WKMemoryCache *memoryCache;
    if(!memoryCache) {
        memoryCache = [[WKMemoryCache alloc] init];
        memoryCache.maxCacheNum = 100;
    }
    NSNumber  *lastLineWidth =  [memoryCache getCache:key];
    if(lastLineWidth) {
        return lastLineWidth.floatValue;
    }
    CGFloat lastLineWidthF = [attrStr lastlineWidth:[WKApp shared].config.messageContentMaxWidth];
    [memoryCache setCache:@(lastLineWidthF) forKey:key];
    return lastLineWidthF;
}

+(BOOL) hasReply:(WKMessageModel*)messageModel {
    if(messageModel.content.reply && messageModel.content.reply.content) {
        return true;
    }
    return false;
}

- (void)refresh:(WKMessageModel *)model {
    [super refresh:model];
//    NSString *text = textContent.content;
    
    NSMutableAttributedString *attrStr = [[self class] parseAndCacheTextMessage:model];

    if(model.isSend) {
        attrStr.textColor =  [WKApp shared].config.messageSendTextColor;
        attrStr.linkColor = [UIColor whiteColor];
    }else {
        attrStr.textColor = [WKApp shared].config.messageRecvTextColor;
        attrStr.linkColor = [UIColor blueColor];
    }
    attrStr.metionColor = attrStr.textColor;
    attrStr.metionUnderline = true;

    self.textLbl.attributedText = attrStr;
    self.textLbl.tokens = attrStr.tokens;
    self.textLbl.lim_size =[[self class] textSize:attrStr messageModel:model];
    //[self.textLbl lim_setText:text mentionInfo:textContent.mentionedInfo];
    
    self.replyBox.hidden = YES;
    if([[self class] hasReply:model]) {
        self.replyBox.hidden = NO;
        self.replyNameLbl.text = model.content.reply.fromName;
        self.replyAvatarIcon.url = [WKAvatarUtil getAvatar:model.content.reply.fromUID];
        if(model.content.reply.revoke) {
            self.replyContentLbl.text = LLang(@"消息已被撤回");
        }else {
            self.replyContentLbl.text = [model.content.reply.content conversationDigest];
        }
        
    }
    
    if([self.messageModel isSend]) {
        self.replyContentLbl.textColor =[WKApp shared].config.messageTipColor;
        self.replyNameLbl.textColor = [WKApp shared].config.messageTipColor;
    }else{
        self.replyContentLbl.textColor =[WKApp shared].config.tipColor;
        self.replyNameLbl.textColor = [WKApp shared].config.tipColor;
    }
    
}

-(void) onTapWithGestureRecognizer:(TapLongTapOrDoubleTapGestureRecognizerWrap*)gesture {
   // [self.textLbl onTap:gesture];
    if([self replyAtPoint:gesture.tapPoint]) {
        [self replyBoxTap];
        return;
    }
    CGPoint point = [self.textLbl convertPoint:gesture.tapPoint fromView:self.contentView];
   id<WKMatchToken> token = [self.textLbl matchDidTapAttributedTextInLabelWithPoint:point];
    if(token) {
        if(token.type == WKatchTokenTypeMetion) {
            [self didMetionClick:token];
        }else if(token.type == WKatchTokenTypeLink) {
            [self didLinkClick:token.text];
        }else if(token.type == WKatchTokenTypeLink2) {
            WKLinkToken *linToken = (WKLinkToken*)token;
            [self didLinkClick:linToken.linkText];
        }
    }
    
}

-(BOOL) replyAtPoint:(CGPoint)point {
    CGRect rectInContentView = [self.contentView convertRect:self.replyBox.frame fromView:self.replyBox];
    return CGRectContainsPoint(rectInContentView, point);
}



-(void) layoutSubviews {
    [super layoutSubviews];
    
    if(!self.messageModel) {
        return;
    }
    
    CGFloat replyBoxBottom = 0.0f;
    
    if([[self class] hasReply:self.messageModel]) {
        
        CGSize replyNameSize = [[self class] getReplyNameSize:self.messageModel];
        CGSize replyContentSize = [[self class] getReplyContentSize:self.messageModel];
        if(replyContentSize.height>replyContentFontSize+1) {
            replyContentSize.height = replyContentFontSize+1;
            replyContentSize.width = self.messageContentView.lim_width;
        }
        self.replyNameLbl.lim_size = replyNameSize;
        self.replyContentLbl.lim_size = replyContentSize;
        
        self.replyBox.lim_top = 0.0f;
        if(!self.nameLbl.hidden) {
            self.replyBox.lim_top = replyToNameSpace;
        }
        self.replyBox.lim_width = self.messageContentView.lim_width;
        self.replyBox.lim_height = replyNameSize.height + replyContentSize.height;
        
        self.splitView.lim_left = 0.0f;
        self.splitView.lim_top = 0.0f;
        self.splitView.lim_height = self.replyBox.lim_height;
        self.splitView.lim_width = splitWidth;
        
        self.replyAvatarIcon.lim_left = self.splitView.lim_right;
        self.replyAvatarIcon.lim_top = self.splitView.lim_top;
        self.replyAvatarIcon.lim_centerY_parent = self.replyNameLbl;
        
        self.replyNameLbl.lim_left = self.replyAvatarIcon.lim_right+4.0f;
        self.replyNameLbl.lim_top = self.splitView.lim_top;
        
        
        self.replyContentLbl.lim_top = self.replyNameLbl.lim_bottom+2.0f;
        self.replyContentLbl.lim_left = self.replyAvatarIcon.lim_left;
       
        replyBoxBottom = self.replyBox.lim_bottom+textTopSpace;
    }
    
    self.textLbl.lim_left = 0.0f;
    self.textLbl.lim_top = replyBoxBottom;
    
    self.securityTipLbl.lim_top = self.messageContentView.lim_bottom + securityTipTopSpace;
    self.securityTipLbl.lim_centerX_parent = self.contentView;
    
    if(self.messageModel.hasSensitiveWord && !self.messageModel.isSend) {
        self.securityTipLbl.hidden = NO;
    }else{
        self.securityTipLbl.hidden = YES;
    }
    
   

}

-(void) layoutName {
    WKBubblePostion position = [[self class] bubblePosition:self.messageModel];
    if(!self.nameLbl.hidden) {
        if(position == WKBubblePostionLast || position == WKBubblePostionSingle) {
            self.nameLbl.lim_left =  WK_CONTENT_INSETS.left+WKLastBubbleOffsetSpace;
        }else{
            self.nameLbl.lim_left =  WK_CONTENT_INSETS.left;
        }
        
        self.nameLbl.lim_top =  WK_CONTENT_INSETS.top;
    }
    self.nameLbl.lim_width = self.messageContentView.lim_width;
}

+(UIEdgeInsets) contentEdgeInsets:(WKMessageModel*)model {
    
    UIEdgeInsets edgeInsets = [super contentEdgeInsets:model];
    
   
    if([self isShowName:model]) {
        return UIEdgeInsetsMake(edgeInsets.top + WK_NICKNAME_HEIGHT, edgeInsets.left, edgeInsets.bottom, edgeInsets.right);
    }
    return UIEdgeInsetsMake(edgeInsets.top, edgeInsets.left, edgeInsets.bottom, edgeInsets.right);
    
}

// 气泡边距
+(UIEdgeInsets) bubbleEdgeInsets:(WKMessageModel*) model contentSize:(CGSize)contentSize{
    
    UIEdgeInsets bubbleInsets = [super bubbleEdgeInsets:model contentSize:contentSize];
   
    return UIEdgeInsetsMake(0.0f, bubbleInsets.left, bubbleInsets.bottom, bubbleInsets.right);
   // return WK_BUBBLE_INSETS;
}

//+ (UIEdgeInsets)bubbleEdgeInsets:(WKMessageModel *)model contentSize:(CGSize)contentSize {
//    WKBubblePostion position = [self bubblePosition:model];
//    if(position == WKBubblePostionLast) { // 最后一条消息
//        return UIEdgeInsetsMake(0.0f, WK_BUBBLE_INSETS.left-4.0f, 20.0f, WK_BUBBLE_INSETS.right-4.0f);
//    }
//    return UIEdgeInsetsMake(0.0f, WK_BUBBLE_INSETS.left-4.0f, 4.0f, WK_BUBBLE_INSETS.right-4.0f);
//}

- (UIView *)replyBox {
    if(!_replyBox) {
        _replyBox = [[UIView alloc] init];
    }
    return _replyBox;
}

-(void) replyBoxTap {
    [self.conversationContext locateMessageCell:self.messageModel.content.reply.messageSeq];
}

- (WKUserAvatar *)replyAvatarIcon {
    if(!_replyAvatarIcon) {
        _replyAvatarIcon = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, replyAvatarSize, replyAvatarSize)];
    }
    return _replyAvatarIcon;
}

- (UIView *)splitView {
    if(!_splitView) {
        _splitView = [[UIView alloc] init];
        [_splitView setHidden:YES];
        _splitView.backgroundColor = [WKApp shared].config.themeColor;
    }
    return _splitView;
}

- (UILabel *)replyNameLbl {
    if(!_replyNameLbl) {
        _replyNameLbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [WKApp shared].config.messageContentMaxWidth - 20*2, 0.0f)];
        _replyNameLbl.font = [[WKApp shared].config appFontOfSize:replyNameFontSize];
    }
    return _replyNameLbl;
}

- (UILabel *)replyContentLbl {
    if(!_replyContentLbl) {
        _replyContentLbl = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [WKApp shared].config.messageContentMaxWidth - 20*2, 0.0f)];
        _replyContentLbl.font = [[WKApp shared].config appFontOfSize:replyContentFontSize];
        _replyContentLbl.numberOfLines = 1;
        [_replyContentLbl setTextColor:[WKApp shared].config.messageTipColor];
    }
    return _replyContentLbl;
}

- (WKTipLabel *)securityTipLbl {
    if(!_securityTipLbl) {
        _securityTipLbl = [[WKTipLabel alloc] init];
        _securityTipLbl.text = [WKSecurityTipManager shared].tip;
        _securityTipLbl.lim_width = [WKApp shared].config.messageContentMaxWidth;
        _securityTipLbl.font = [[WKApp shared].config appFontOfSize:securityTipFontSize];
        _securityTipLbl.textAlignment = NSTextAlignmentCenter;
        _securityTipLbl.numberOfLines = 0;
        _securityTipLbl.lineBreakMode = NSLineBreakByWordWrapping;
        _securityTipLbl.layer.masksToBounds = YES;
        _securityTipLbl.layer.cornerRadius = 4.0f;
        _securityTipLbl.textColor = [WKApp shared].config.defaultTextColor;
        [_securityTipLbl sizeToFit];
        _securityTipLbl.backgroundColor = [UIColor colorWithRed:255.0f green:255.0f blue:255.0f alpha:0.5f];
    }
    return _securityTipLbl;
}



+(CGSize) getReplyNameSize:(WKMessageModel *)message {
    return [self getTextSize:message.content.reply.fromName?:@"" maxWidth:[WKApp shared].config.messageContentMaxWidth - 20*2 fontSize:replyNameFontSize];
}

+(CGSize) getReplyContentSize:(WKMessageModel *)message {
    return [self getTextSize:[message.content.reply.content conversationDigest] maxWidth:[WKApp shared].config.messageContentMaxWidth - 20*2 fontSize:replyContentFontSize];
}

+(CGFloat)getWidthWithText:(NSString*)text height:(CGFloat)height font:(CGFloat)font{
    CGRect rect = [text boundingRectWithSize:CGSizeMake(MAXFLOAT, height) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:font]} context:nil];
    return rect.size.width;
    
}


+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth fontSize:(CGFloat)fontSize{
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:fontSize], NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}


#pragma mark -- event

-(void) didMetionClick:(WKMetionToken*)token {
    NSString *atUID = token.uid;
    if(!atUID || [atUID isEqualToString:@""]) {
        return;
    }
    WKChannelMember *member = [[WKSDK shared].channelManager getMember:self.messageModel.channel uid:atUID];
    NSString *vercode = @"";
    if(member) {
        vercode = member.extra[WKChannelExtraKeyVercode];
    }
    [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{
        @"channel": self.messageModel.channel,
        @"uid": atUID,
        @"vercode":vercode?:@"",
    }];
}

-(void) didLinkClick:(NSString*)link {
//    NSString *link = token.text;
    if([link containsString:@"."]) { // 网站
        WKWebViewVC *vc = [[WKWebViewVC alloc] init];
        if(![link hasPrefix:@"http"]) {
            link = [NSString stringWithFormat:@"http://%@",link];
        }
        vc.url = [NSURL URLWithString:[link stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
       
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    } else {  // 电话
        [self.conversationContext endEditing]; // 结束编辑
        __weak typeof(self) weakSelf = self;
        WKActionSheetView2 *sheetView = [WKActionSheetView2 initWithTip:[NSString stringWithFormat:LLang(@"%@可能是一个电话号码，你可以"),link]];
        [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"呼叫") onClick:^{
            NSMutableString *str = [[NSMutableString alloc]
                     initWithFormat:@"telprompt://%@", link];
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:str]]) {
                     [[UIApplication sharedApplication] openURL:[NSURL URLWithString:str]];
            } else {
                     [weakSelf showMsg:LLang(@"手机格式不正确！")];
            }
        }]];
        [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"复制号码") onClick:^{
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            [pasteboard setString:link];
        }]];
        [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"添加到手机通讯录") onClick:^{
            [weakSelf toSaveContacts:link];
        }]];
        [sheetView show];
    }
}

-(void) toSaveContacts:(NSString*)phone {
    __weak typeof(self) weakSelf = self;
    WKActionSheetView2 *sheetView = [WKActionSheetView2 initWithTip:[NSString stringWithFormat:LLang(@"%@可能是一个电话号码，你可以"),phone]];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"创建新联系人") onClick:^{
        [weakSelf saveNewContact:phone];
    }]];
    [sheetView addItem:[WKActionSheetButtonItem2 initWithTitle:LLang(@"添加到现有联系人") onClick:^{
        [weakSelf saveExistContact:phone];
    }]];
    [sheetView show];
}

-(void) saveNewContact:(NSString*)phone {
    if (@available(iOS 9.0, *)) {
        CNMutableContact *contact = [[CNMutableContact alloc] init];
        [self saveContacts:phone contact:contact isNew:YES];
        CNContactViewController *vc = [CNContactViewController viewControllerForNewContact:contact];
        vc.delegate = self;
        UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:vc];
        [[WKNavigationManager shared].topViewController presentViewController:navigation animated:YES completion:nil];
    }
}

-(void) saveExistContact:(NSString*)phone {
    if (@available(iOS 9.0, *)) {
        CNContactPickerViewController *controller =
        [[CNContactPickerViewController alloc] init];
        controller.delegate = self;
           [[WKNavigationManager shared].topViewController presentViewController:controller
             animated:YES
           completion:^{

           }];
    }
}

-(void) saveContacts:(NSString*)phone contact:(CNMutableContact*)contact isNew:(BOOL)isNew API_AVAILABLE(ios(9.0)){
    if (@available(iOS 9.0, *)) {
        CNLabeledValue *phoneNumber = [CNLabeledValue
                                              labeledValueWithLabel:CNLabelPhoneNumberMobile
                                              value:[CNPhoneNumber phoneNumberWithStringValue:
                                                     phone]];
        if(isNew) {
                contact.phoneNumbers = @[ phoneNumber ];
           }else{
               if ([contact.phoneNumbers count] > 0) {
                    NSMutableArray *phoneNumbers =
                        [[NSMutableArray alloc] initWithArray:contact.phoneNumbers];
                    [phoneNumbers addObject:phoneNumber];
                    contact.phoneNumbers = phoneNumbers;
                  } else {
                    contact.phoneNumbers = @[ phoneNumber ];
                  }
           }
    }
}

- (void)contactPicker:(CNContactPickerViewController *)picker
     didSelectContact:(CNContact *)contact  API_AVAILABLE(ios(9.0)){
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        CNMutableContact *c = [contact mutableCopy];
        [weakSelf saveContacts:weakSelf.selectLinkData contact:c isNew:YES];
        
        CNContactViewController *controller =
                                      [CNContactViewController
                                          viewControllerForNewContact:c];
        controller.delegate = weakSelf;
        UINavigationController *navigation =
                                      [[UINavigationController alloc]
                                          initWithRootViewController:controller];

                                  [[WKNavigationManager shared].topViewController presentViewController:navigation
                                                        animated:YES
                                                      completion:^{

                                                      }];
    }];
}
- (void)contactViewController:(CNContactViewController *)viewController
       didCompleteWithContact:(nullable CNContact *)contact  API_AVAILABLE(ios(9.0)){
  [viewController dismissViewControllerAnimated:YES completion:nil];
}

@end
