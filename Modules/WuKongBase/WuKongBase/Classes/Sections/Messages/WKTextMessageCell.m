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
#import "WKRichTextParseService.h"
#import "WKMarkdownParser.h"
#import <WebKit/WebKit.h>
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

#define kTableRowHeight 44.0f
#define kTableTopSpace 8.0f
#define kTableExtraPadding 10.0f
#define kTableToolbarHeight 36.0f

#define kBotActionBtnHeight 32.0f
#define kBotActionTopSpace 10.0f
#define kBotActionBtnSpacing 10.0f


@interface WKTextMessageCell ()<CNContactViewControllerDelegate,CNContactPickerDelegate,WKNavigationDelegate,UIScrollViewDelegate>

@property(nonatomic,strong) UILabel *textLbl;
@property(nonatomic,strong) id selectLinkData;

// ---------- 分段渲染（文本段=UILabel，表格段=WKWebView）----------
@property(nonatomic,strong) NSMutableArray<UIView*> *segmentViews;       // 按顺序的 UILabel / WKWebView
@property(nonatomic,strong) NSMutableArray<WKWebView*> *tableWebViews;   // 表格 WebView 引用
@property(nonatomic,strong) NSMutableArray<UIScrollView*> *tableOverlays; // 滑动遮罩（在 contentView 上）
@property(nonatomic,strong) NSMutableArray<UIView*> *tableToolbars;      // 表格工具栏
@property(nonatomic,strong) NSMutableArray<NSString*> *tableRawContents; // 表格原始 markdown 内容（供复制用）
@property(nonatomic,assign) BOOL segmentsBuilt; // 分段视图是否已创建


// ---------- 回复 ----------
@property(nonatomic,strong) UIView *replyBox;
@property(nonatomic,strong) UIView *splitView;
@property(nonatomic,strong) UILabel *replyNameLbl;
@property(nonatomic,strong) UILabel *replyContentLbl;
@property(nonatomic,strong) WKUserAvatar *replyAvatarIcon;

// ---------- 安全提醒 ----------
@property(nonatomic,strong) WKTipLabel *securityTipLbl;

// ---------- BotFather 审批按钮 ----------
@property(nonatomic,strong) UIView *botActionView;
@property(nonatomic,strong) UIButton *approveBtn;
@property(nonatomic,strong) UIButton *rejectBtn;
@property(nonatomic,copy) NSString *approveCommand;
@property(nonatomic,copy) NSString *rejectCommand;

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


    // 含表格时：逐段计算高度（与 layoutSubviews 保持一致，避免合并文本与分段之和的偏差）
    NSString *rawContent = [[self class] getRawContent:model];
    if ([WKMarkdownRenderer containsTable:rawContent]) {
        CGFloat segHeight = [[self class] segmentedContentHeightForMessage:model];
        // 用分段高度替换 messageTextSize 中的文本高度部分（保留 reply 等其他高度）
        size.height = size.height - messageTextSize.height + segHeight;
        size.width = MAX(size.width, [WKApp shared].config.messageContentMaxWidth);
    }

    // BotFather 审批按钮高度
    if ([self isBotFatherApproveMessage:model]) {
        size.height += kBotActionTopSpace + kBotActionBtnHeight;
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
        // 使用包含AI标识宽度的计算，避免气泡太窄导致AI标识被裁剪
        nicknameWidth = [self getNicknameRowWidth:model];
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

    // 分段渲染数组
    self.segmentViews = [NSMutableArray array];
    self.tableWebViews = [NSMutableArray array];
    self.tableOverlays = [NSMutableArray array];
    self.tableToolbars = [NSMutableArray array];
    self.tableRawContents = [NSMutableArray array];

    // 回复
    [self.messageContentView addSubview:self.replyBox];
    [self.replyBox addSubview:self.splitView];
    [self.replyBox addSubview:self.replyNameLbl];
    [self.replyBox addSubview:self.replyContentLbl];
    [self.replyBox addSubview:self.replyAvatarIcon ];
    
    // 安全提醒
    [self.contentView addSubview:self.securityTipLbl];

    // BotFather 审批按钮
    self.botActionView = [[UIView alloc] init];
    self.botActionView.hidden = YES;
    [self.messageContentView addSubview:self.botActionView];

    self.rejectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.rejectBtn setTitle:LLang(@"拒绝") forState:UIControlStateNormal];
    [self.rejectBtn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
    self.rejectBtn.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    self.rejectBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
    self.rejectBtn.layer.cornerRadius = 4.0f;
    self.rejectBtn.layer.masksToBounds = YES;
    [self.rejectBtn addTarget:self action:@selector(rejectBtnTap) forControlEvents:UIControlEventTouchUpInside];
    [self.botActionView addSubview:self.rejectBtn];

    self.approveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.approveBtn setTitle:LLang(@"通过") forState:UIControlStateNormal];
    [self.approveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.approveBtn.backgroundColor = [WKApp shared].config.themeColor;
    self.approveBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
    self.approveBtn.layer.cornerRadius = 4.0f;
    self.approveBtn.layer.masksToBounds = YES;
    [self.approveBtn addTarget:self action:@selector(approveBtnTap) forControlEvents:UIControlEventTouchUpInside];
    [self.botActionView addSubview:self.approveBtn];


}

-(void) clearSegmentViews {
    for (UIView *v in self.segmentViews) {
        // 不移除 textLbl（它是 initUI 创建的持久视图，移除后复用会空白）
        if (v != self.textLbl) { [v removeFromSuperview]; }
    }
    [self.segmentViews removeAllObjects];
    for (UIScrollView *o in self.tableOverlays) { [o removeFromSuperview]; }
    [self.tableOverlays removeAllObjects];
    [self.tableWebViews removeAllObjects];
    [self.tableToolbars removeAllObjects];
    [self.tableRawContents removeAllObjects];
}

-(WKWebView*) createSegmentWebView {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    wv.scrollView.scrollEnabled = NO;
    wv.backgroundColor = [UIColor clearColor];
    wv.opaque = NO;
    wv.scrollView.backgroundColor = [UIColor clearColor];
    wv.navigationDelegate = self;
    return wv;
}

-(UIScrollView*) createSegmentOverlay {
    UIScrollView *sv = [[UIScrollView alloc] init];
    sv.backgroundColor = [UIColor clearColor];
    sv.showsHorizontalScrollIndicator = YES;
    sv.showsVerticalScrollIndicator = NO;
    sv.bounces = NO;
    sv.directionalLockEnabled = YES;
    sv.delegate = self;
    return sv;
}

-(UIView*) createTableToolbar:(NSInteger)tableIndex {
    UIView *toolbar = [[UIView alloc] init];
    toolbar.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF6/255.0 alpha:1.0];

    // 左侧 "表格" 标签
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.text = @"表格";
    titleLbl.font = [UIFont boldSystemFontOfSize:15];
    titleLbl.textColor = [UIColor colorWithRed:0x33/255.0 green:0x33/255.0 blue:0x33/255.0 alpha:1.0];
    [titleLbl sizeToFit];
    titleLbl.frame = CGRectMake(12, (kTableToolbarHeight - titleLbl.frame.size.height) / 2.0, titleLbl.frame.size.width, titleLbl.frame.size.height);
    [toolbar addSubview:titleLbl];

    // 右侧复制按钮
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.tag = tableIndex;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightRegular];
        UIImage *icon = [UIImage systemImageNamed:@"doc.on.doc" withConfiguration:config];
        [copyBtn setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    } else {
        [copyBtn setTitle:@"复制" forState:UIControlStateNormal];
        copyBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    }
    copyBtn.tintColor = [UIColor colorWithRed:0x99/255.0 green:0x99/255.0 blue:0x99/255.0 alpha:1.0];
    [copyBtn addTarget:self action:@selector(copyTableTapped:) forControlEvents:UIControlEventTouchUpInside];
    copyBtn.frame = CGRectMake(0, 0, 36, kTableToolbarHeight);
    [toolbar addSubview:copyBtn];

    // 底部分隔线
    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = [UIColor colorWithRed:0xE0/255.0 green:0xE0/255.0 blue:0xE0/255.0 alpha:1.0];
    separator.tag = 9999; // 用于 layoutSubviews 中定位
    [toolbar addSubview:separator];

    return toolbar;
}

-(void) copyTableTapped:(UIButton*)sender {
    NSInteger idx = sender.tag;
    if (idx < (NSInteger)self.tableRawContents.count) {
        NSString *content = self.tableRawContents[idx];
        [UIPasteboard generalPasteboard].string = content;
        UIView *topView = [WKNavigationManager shared].topViewController.view;
        [topView showHUDWithHide:LLang(@"已复制")];
    }
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
                WKTextContent *streamTextContent = (WKTextContent*)stream.content;
                [content appendString:streamTextContent.content];
            }
        }
    }

    // BotFather 审批消息：从显示文本中剥离 /approve 和 /reject 命令行
    if ([[self class] isBotFatherApproveMessage:message]) {
        NSRange approveRange = [content rangeOfString:@"/approve"];
        NSRange rejectRange = [content rangeOfString:@"/reject"];
        NSUInteger cutPos = NSNotFound;
        if (approveRange.location != NSNotFound && rejectRange.location != NSNotFound) {
            cutPos = MIN(approveRange.location, rejectRange.location);
        } else if (approveRange.location != NSNotFound) {
            cutPos = approveRange.location;
        } else if (rejectRange.location != NSNotFound) {
            cutPos = rejectRange.location;
        }
        if (cutPos != NSNotFound && cutPos > 0) {
            NSString *trimmed = [[content substringToIndex:cutPos] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [content setString:trimmed];
        }
    }

    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] init];
    attrStr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];

    // 如果内容包含表格，将表格部分移除（表格由 WKWebView 单独渲染）
    NSString *renderContent = content;
    if (![textContent.format isEqualToString:@"html"] && [WKMarkdownRenderer containsTable:content]) {
        renderContent = [[WKMarkdownRenderer removeTableMarkdown:content] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    // 尝试使用 Down 库进行 markdown 渲染
    BOOL useMarkdown = NO;
    if (![textContent.format isEqualToString:@"html"]) {
        if (renderContent.length > 0 && [WKMarkdownRenderer containsMarkdown:renderContent]) {
            UIColor *textColor = message.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.messageRecvTextColor;
            NSString *colorHex = [textColor toHexRGB];
            NSAttributedString *mdAttr = [WKMarkdownRenderer render:renderContent fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
            if (mdAttr && mdAttr.length > 0) {
                useMarkdown = YES;
                NSMutableAttributedString *mdMutable = [[NSMutableAttributedString alloc] initWithAttributedString:mdAttr];
                mdMutable.font = attrStr.font;

                // 从 Down 渲染结果中提取可点击的 tokens
                NSMutableArray<id<WKMatchToken>> *clickableTokens = [NSMutableArray array];

                // 1. 提取链接 tokens，并记录需要移除NSLinkAttributeName的range
                NSMutableArray<NSValue*> *linkRanges = [NSMutableArray array];
                [mdMutable enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, mdMutable.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
                    if (value) {
                        WKLinkToken *token = [WKLinkToken new];
                        token.range = range;
                        token.linkText = [mdMutable.string substringWithRange:range];
                        if ([value isKindOfClass:[NSURL class]]) {
                            token.linkContent = [(NSURL*)value absoluteString];
                        } else if ([value isKindOfClass:[NSString class]]) {
                            token.linkContent = (NSString*)value;
                        }
                        token.text = token.linkText;
                        [clickableTokens addObject:token];
                        [linkRanges addObject:[NSValue valueWithRange:range]];
                    }
                }];
                // 移除NSLinkAttributeName：UILabel不支持该属性，且会导致hitTest用的
                // UITextView布局与UILabel不一致，使点击坐标无法匹配到token range
                for (NSValue *rangeValue in linkRanges) {
                    NSRange range = [rangeValue rangeValue];
                    [mdMutable removeAttribute:NSLinkAttributeName range:range];
                    // 确保链接有可见的视觉样式（颜色+下划线）
                    [mdMutable addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:range];
                    [mdMutable addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
                }

                // 2. 从消息 entities 中提取 @mention tokens，在渲染后的文本中查找匹配位置
                NSArray<WKMessageEntity*> *entities = message.content.entities;
                if (message.remoteExtra.contentEdit) {
                    entities = message.remoteExtra.contentEdit.entities;
                }
                if (entities) {
                    NSString *renderedText = mdMutable.string;
                    for (WKMessageEntity *entity in entities) {
                        if (![entity.type isEqualToString:WKMentionRichTextStyle]) continue;
                        // 从原文中取出 @xxx 文本
                        if (entity.range.location + entity.range.length > content.length) continue;
                        NSString *mentionText = [content substringWithRange:entity.range];
                        if ([mentionText hasSuffix:@" "]) {
                            mentionText = [mentionText substringToIndex:mentionText.length - 1];
                        }
                        // 在渲染后的文本中查找这段 @xxx
                        NSRange foundRange = [renderedText rangeOfString:mentionText];
                        if (foundRange.location != NSNotFound) {
                            WKMetionToken *token = [WKMetionToken new];
                            token.range = foundRange;
                            token.uid = entity.value ?: @"";
                            token.text = mentionText;
                            [clickableTokens addObject:token];
                            // 给 @mention 文本加上下划线 + 颜色
                            UIColor *mentionColor = message.isSend ? [UIColor whiteColor] : [WKApp shared].config.themeColor;
                            [mdMutable addAttribute:NSForegroundColorAttributeName value:mentionColor range:foundRange];
                            [mdMutable addAttribute:NSUnderlineStyleAttributeName value:@1 range:foundRange];
                        }
                    }
                }

                // 3. Auto-detect pure URLs not covered by markdown [text](url) links
                NSArray<id<WKMatchToken>> *autoLinkTokens = [[WKRichTextParseService shared] parseLink:mdMutable.string];
                for (id<WKMatchToken> autoToken in autoLinkTokens) {
                    if (autoToken.type != WKatchTokenTypeLink) continue;
                    // Check if this URL overlaps with any existing clickable token
                    BOOL overlaps = NO;
                    for (id<WKMatchToken> existing in clickableTokens) {
                        NSRange ar = autoToken.range;
                        NSRange er = existing.range;
                        if (ar.location < er.location + er.length && er.location < ar.location + ar.length) {
                            overlaps = YES;
                            break;
                        }
                    }
                    if (overlaps) continue;
                    // Create a clickable link token for the pure URL
                    WKLinkToken *linkToken = [WKLinkToken new];
                    linkToken.range = autoToken.range;
                    linkToken.linkText = autoToken.text;
                    linkToken.linkContent = autoToken.text;
                    linkToken.text = autoToken.text;
                    [clickableTokens addObject:linkToken];
                    [mdMutable addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:autoToken.range];
                    [mdMutable addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:autoToken.range];
                }

                mdMutable.tokens = clickableTokens;

                return mdMutable;
            }
        }
    }

    if (!useMarkdown) {
        // 原有逻辑：entity tokens + 自动 URL 检测
        NSString *textForRender = renderContent.length > 0 ? renderContent : content;
        NSArray<id<WKMatchToken>> *entityTokens = [self getTokens:message text:textForRender];

        // 自动检测 URL 链接（补充 entity 中未包含的链接）
        NSArray<id<WKMatchToken>> *linkTokens = [[WKRichTextParseService shared] parseLink:textForRender];
        NSMutableArray<id<WKMatchToken>> *tokens = [NSMutableArray arrayWithArray:entityTokens];
        for (id<WKMatchToken> linkToken in linkTokens) {
            if(linkToken.type != WKatchTokenTypeLink) {
                continue;
            }
            BOOL overlaps = NO;
            for (id<WKMatchToken> entityToken in entityTokens) {
                NSRange lr = linkToken.range;
                NSRange er = entityToken.range;
                if(lr.location < er.location + er.length && er.location < lr.location + lr.length) {
                    overlaps = YES;
                    break;
                }
            }
            if(!overlaps) {
                [tokens addObject:linkToken];
            }
        }

        // 自动检测手写/复制的 @mention（补充 entity 中未包含的 @提及）
        NSArray<id<WKMatchToken>> *autoMentionTokens = [self detectMentionsInText:textForRender channel:message.message.channel existingTokens:tokens];
        if (autoMentionTokens.count > 0) {
            [tokens addObjectsFromArray:autoMentionTokens];
        }

        [attrStr lim_render:textForRender tokens:tokens];
    }

    return attrStr;
}

/// 自动检测文本中的 @mention（匹配群成员或联系人）
+(NSArray<id<WKMatchToken>>*) detectMentionsInText:(NSString*)text channel:(WKChannel*)channel existingTokens:(NSArray<id<WKMatchToken>>*)existingTokens {
    if (!text || text.length == 0) return @[];

    NSMutableArray<id<WKMatchToken>> *result = [NSMutableArray array];

    // 用正则找出所有 @xxx 片段（@后跟非空白字符）
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"@(\\S+)" options:0 error:nil];
    if (!regex) return @[];

    NSArray<NSTextCheckingResult*> *matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    if (matches.count == 0) return @[];

    // 获取可匹配的成员/联系人列表
    NSArray<WKChannelMember*> *members = nil;
    if (channel.channelType == WK_GROUP) {
        members = [[WKSDK shared].channelManager getMembersWithChannel:channel];
    }

    for (NSTextCheckingResult *match in matches) {
        NSRange fullRange = [match range];           // @xxx 的完整范围
        NSRange nameRange = [match rangeAtIndex:1];  // xxx 部分

        // 检查是否与已有 token 重叠，避免重复
        BOOL overlaps = NO;
        for (id<WKMatchToken> token in existingTokens) {
            if (token.type != WKatchTokenTypeMetion) continue;
            NSRange tr = token.range;
            if (fullRange.location < tr.location + tr.length && tr.location < fullRange.location + fullRange.length) {
                overlaps = YES;
                break;
            }
        }
        if (overlaps) continue;

        NSString *mentionName = [text substringWithRange:nameRange];
        NSString *matchedUID = nil;

        // 在群成员中匹配（名字/备注/uid）
        if (members) {
            for (WKChannelMember *member in members) {
                WKChannelInfo *memberInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:member.memberUid]];
                if (memberInfo) {
                    if (([memberInfo.name isEqualToString:mentionName]) ||
                        (memberInfo.remark && [memberInfo.remark isEqualToString:mentionName]) ||
                        ([memberInfo.displayName isEqualToString:mentionName]) ||
                        ([member.memberUid isEqualToString:mentionName])) {
                        matchedUID = member.memberUid;
                        break;
                    }
                } else if ([member.memberUid isEqualToString:mentionName] ||
                           (member.memberName && [member.memberName isEqualToString:mentionName])) {
                    matchedUID = member.memberUid;
                    break;
                }
            }
        }

        // 群成员没匹配到，尝试从联系人缓存中按名字匹配
        if (!matchedUID) {
            NSArray<WKChannelInfo*> *allContacts = [[WKChannelInfoDB shared] queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal follow:WKChannelInfoFollowFriend];
            for (WKChannelInfo *info in allContacts) {
                if (([info.name isEqualToString:mentionName]) ||
                    (info.remark && [info.remark isEqualToString:mentionName]) ||
                    ([info.displayName isEqualToString:mentionName])) {
                    matchedUID = info.channel.channelId;
                    break;
                }
            }
        }

        if (matchedUID) {
            WKMetionToken *token = [WKMetionToken new];
            token.range = fullRange;
            token.uid = matchedUID;
            token.text = [text substringWithRange:fullRange];
            [result addObject:token];
        }
    }

    return result;
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

/// 提取消息的原始文本内容（合并流式内容）
+(NSString*) getRawContent:(WKMessageModel*)message {
    WKTextContent *textContent = (WKTextContent*)[message content];
    if (message.remoteExtra.contentEdit) {
        textContent = (WKTextContent*)message.remoteExtra.contentEdit;
    }
    NSMutableString *content = [[NSMutableString alloc] initWithString:textContent.content ?: @""];
    if (message.streams && message.streams.count > 0) {
        for (WKStream *stream in message.streams) {
            if ([stream.content isKindOfClass:WKTextContent.class]) {
                [content appendString:((WKTextContent*)stream.content).content];
            }
        }
    }
    return content;
}

/// 判断是否为 BotFather 好友审批消息
+(BOOL) isBotFatherApproveMessage:(WKMessageModel*)model {
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    if (!botfatherUID || botfatherUID.length == 0) return NO;
    if (![model.channel.channelId isEqualToString:botfatherUID]) return NO;
    if (model.isSend) return NO;
    NSString *rawContent = [[self class] getRawContent:model];
    return [rawContent containsString:@"/approve"];
}

/// 用正则从文本中提取指定前缀的完整命令（如 /approve uid botname）
+(NSString*) extractCommand:(NSString*)content prefix:(NSString*)prefix {
    if (!content || !prefix) return nil;
    NSString *pattern = [NSString stringWithFormat:@"%@\\s+\\S+(?:\\s+\\S+)?", [NSRegularExpression escapedPatternForString:prefix]];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    if (!regex) return nil;
    NSTextCheckingResult *match = [regex firstMatchInString:content options:0 range:NSMakeRange(0, content.length)];
    if (!match) return nil;
    return [content substringWithRange:match.range];
}

/// 计算表格部分的高度（不含顶部间距）
+(CGFloat) tableHeightForMessage:(WKMessageModel*)message {
    NSString *content = [[self class] getRawContent:message];
    if (![WKMarkdownRenderer containsTable:content]) return 0;
    NSInteger rowCount = [WKMarkdownRenderer tableRowCount:content];
    if (rowCount <= 0) return 0;
    return kTableToolbarHeight + rowCount * kTableRowHeight + kTableExtraPadding;
}

/// 分段计算内容高度（与 layoutSubviews 中逐段布局逻辑完全一致）
/// 使用静态 UILabel.sizeThatFits: 测量文本高度，与 layoutSubviews 使用相同的测量方式，
/// 避免 boundingRectWithSize: 对长文本+复杂属性字符串的高度低估。
+(CGFloat) segmentedContentHeightForMessage:(WKMessageModel*)model {
    static WKMemoryCache *segHeightCache;
    if (!segHeightCache) {
        segHeightCache = [[WKMemoryCache alloc] init];
        segHeightCache.maxCacheNum = 100;
    }

    // 流式消息不缓存
    BOOL isStreaming = model.streamOn && model.streamFlag != WKStreamFlagEnd;
    NSString *cacheKey = [NSString stringWithFormat:@"%@-segH", model.clientMsgNo];
    if (model.remoteExtra.contentEdit) {
        cacheKey = [NSString stringWithFormat:@"%@-segH-edit-%lu", model.clientMsgNo, model.remoteExtra.editedAt];
    }
    if (!isStreaming) {
        NSNumber *cached = [segHeightCache getCache:cacheKey];
        if (cached) return cached.floatValue;
    }

    NSString *rawContent = [[self class] getRawContent:model];
    NSArray *segments = [WKMarkdownRenderer splitContentSegments:rawContent];
    if (segments.count == 0) return 0;

    CGFloat maxWidth = [WKApp shared].config.messageContentMaxWidth;
    UIColor *textColor = model.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.messageRecvTextColor;
    NSString *colorHex = [textColor toHexRGB];
    CGFloat totalHeight = 0;

    // 用静态 UILabel 测量文本段高度（与 layoutSubviews 中 sizeThatFits: 一致）
    static UILabel *measureLabel;
    if (!measureLabel) {
        measureLabel = [[UILabel alloc] init];
        measureLabel.numberOfLines = 0;
        measureLabel.lineBreakMode = NSLineBreakByWordWrapping;
    }
    measureLabel.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];

    for (NSUInteger i = 0; i < segments.count; i++) {
        NSDictionary *seg = segments[i];
        NSString *type = seg[@"type"];
        NSString *content = seg[@"content"];
        CGFloat spacing = (i < segments.count - 1) ? kTableTopSpace : 0;

        if ([type isEqualToString:@"text"]) {
            // 与 refresh: 中的渲染逻辑完全一致：
            // markdown 文本走 WKMarkdownRenderer，非 markdown 走 lim_render
            if ([WKMarkdownRenderer containsMarkdown:content]) {
                NSAttributedString *mdAttr = [WKMarkdownRenderer render:content fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
                if (mdAttr) {
                    measureLabel.attributedText = mdAttr;
                } else {
                    measureLabel.text = content;
                }
            } else {
                // 非 markdown：用 lim_render 渲染（带段落样式），与 refresh: 中一致
                NSMutableAttributedString *plainAttr = [[NSMutableAttributedString alloc] init];
                plainAttr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
                plainAttr.textColor = textColor;
                [plainAttr lim_render:content tokens:nil];
                measureLabel.attributedText = plainAttr;
            }
            // 用 sizeThatFits: 测量（与 layoutSubviews 中完全一致）
            CGSize fitSize = [measureLabel sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)];
            totalHeight += ceil(fitSize.height) + spacing;
        } else {
            // 表格段：工具栏 + 表格行高 + 额外 padding
            NSInteger rowCount = [WKMarkdownRenderer tableRowCount:content];
            totalHeight += kTableToolbarHeight + rowCount * kTableRowHeight + kTableExtraPadding + spacing;
        }
    }

    if (!isStreaming) {
        [segHeightCache setCache:@(totalHeight) forKey:cacheKey];
    }
    return totalHeight;
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
        attrStr.linkColor = [UIColor blueColor];
    }else {
        attrStr.textColor = [WKApp shared].config.messageRecvTextColor;
        attrStr.linkColor = [UIColor blueColor];
    }
    // @mention 下划线 + 区分发送/接收的颜色
    if(model.isSend) {
        // 紫色气泡上用白色，醒目
        attrStr.metionColor = [UIColor whiteColor];
    } else {
        // 白色气泡上用主题紫色
        attrStr.metionColor = [WKApp shared].config.themeColor;
    }
    attrStr.metionUnderline = true;

    // 分段渲染：文本段用 UILabel，表格段用 WKWebView，按原始顺序排列
    NSString *rawContent = [[self class] getRawContent:model];
    BOOL hasTable = [WKMarkdownRenderer containsTable:rawContent];

    // 无表格 或 有表格但分段未创建时，才设置 textLbl
    if (!hasTable) {
        // 无表格：textLbl 显示全部内容
        self.textLbl.attributedText = attrStr;
        self.textLbl.tokens = attrStr.tokens;
        self.textLbl.lim_size =[[self class] textSize:attrStr messageModel:model];
    } else if (!self.segmentsBuilt) {
        // 有表格且首次构建：仅设置内容，不设 lim_size 为全文尺寸
        // lim_size 会在段落构建完成后根据第一段文本正确设置
        self.textLbl.attributedText = attrStr;
        self.textLbl.tokens = attrStr.tokens;
    }

    if (hasTable) {
        // 表格 cell 用唯一 reuseIdentifier，不会被复用给其他消息，只需创建一次
        if (!self.segmentsBuilt) {
            [self clearSegmentViews];
            NSArray *segments = [WKMarkdownRenderer splitContentSegments:rawContent];
            UIColor *textColor = model.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.messageRecvTextColor;
            BOOL firstTextUsed = NO;
            for (NSDictionary *seg in segments) {
                NSString *type = seg[@"type"];
                NSString *content = seg[@"content"];
                if ([type isEqualToString:@"text"]) {
                    // 统一用 WKMarkdownRenderer 渲染文本段（和 getContentAttrStr: 同一套逻辑，确保高度一致）
                    NSString *colorHex = [textColor toHexRGB];
                    UILabel *lbl;
                    if (!firstTextUsed) {
                        // 第一个文本段复用 textLbl（支持点击链接等交互）
                        firstTextUsed = YES;
                        lbl = self.textLbl;
                        lbl.hidden = NO;
                    } else {
                        lbl = [[UILabel alloc] init];
                        lbl.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
                        lbl.textColor = textColor;
                        lbl.numberOfLines = 0;
                        lbl.lineBreakMode = NSLineBreakByWordWrapping;
                        lbl.backgroundColor = [UIColor clearColor];
                        [self.messageContentView addSubview:lbl];
                    }
                    // markdown 渲染 + 链接提取
                    if ([WKMarkdownRenderer containsMarkdown:content]) {
                        NSAttributedString *mdAttr = [WKMarkdownRenderer render:content fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
                        if (mdAttr) {
                            NSMutableAttributedString *mutable = [[NSMutableAttributedString alloc] initWithAttributedString:mdAttr];
                            // 提取 markdown 链接 token 并移除 NSLinkAttributeName（UILabel 不支持）
                            NSMutableArray<id<WKMatchToken>> *tokens = [NSMutableArray array];
                            [mutable enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, mutable.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
                                if (value) {
                                    WKLinkToken *token = [WKLinkToken new];
                                    token.range = range;
                                    token.linkText = [mutable.string substringWithRange:range];
                                    if ([value isKindOfClass:[NSURL class]]) {
                                        token.linkContent = [(NSURL*)value absoluteString];
                                    } else if ([value isKindOfClass:[NSString class]]) {
                                        token.linkContent = (NSString*)value;
                                    }
                                    token.text = token.linkText;
                                    [tokens addObject:token];
                                }
                            }];
                            [mutable enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, mutable.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
                                if (value) {
                                    [mutable removeAttribute:NSLinkAttributeName range:range];
                                    [mutable addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:range];
                                    [mutable addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
                                }
                            }];
                            // 自动检测纯 URL
                            NSArray *autoLinks = [[WKRichTextParseService shared] parseLink:mutable.string];
                            for (id<WKMatchToken> autoToken in autoLinks) {
                                if (autoToken.type != WKatchTokenTypeLink) continue;
                                BOOL overlaps = NO;
                                for (id<WKMatchToken> existing in tokens) {
                                    NSRange ar = autoToken.range, er = existing.range;
                                    if (ar.location < er.location + er.length && er.location < ar.location + ar.length) { overlaps = YES; break; }
                                }
                                if (!overlaps) {
                                    [tokens addObject:autoToken];
                                    [mutable addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:autoToken.range];
                                    [mutable addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:autoToken.range];
                                }
                            }
                            mutable.tokens = tokens;
                            lbl.attributedText = mutable;
                            if ([lbl respondsToSelector:@selector(setTokens:)]) {
                                [(id)lbl setTokens:tokens];
                            }
                        } else {
                            lbl.text = content;
                        }
                    } else {
                        // 非 markdown：纯文本 + URL 检测
                        NSMutableAttributedString *plainAttr = [[NSMutableAttributedString alloc] init];
                        plainAttr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
                        NSArray *tokens = [[WKRichTextParseService shared] parseLink:content];
                        [plainAttr lim_render:content tokens:tokens];
                        plainAttr.textColor = textColor;
                        plainAttr.linkColor = [UIColor blueColor];
                        lbl.attributedText = plainAttr;
                        if ([lbl respondsToSelector:@selector(setTokens:)]) {
                            [(id)lbl setTokens:plainAttr.tokens];
                        }
                    }
                    [self.segmentViews addObject:lbl];
                } else {
                    // 表格段：容器（圆角灰色背景）+ 工具栏 + WebView
                    NSInteger tableIndex = (NSInteger)self.tableRawContents.count;
                    [self.tableRawContents addObject:content];

                    UIView *container = [[UIView alloc] init];
                    container.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF6/255.0 alpha:1.0];
                    container.layer.cornerRadius = 8.0;
                    container.clipsToBounds = YES;

                    UIView *toolbar = [self createTableToolbar:tableIndex];
                    [container addSubview:toolbar];

                    WKWebView *wv = [self createSegmentWebView];
                    // 表格在灰色容器内，文字始终用深色（不跟随发送/接收消息颜色）
                    NSString *tableColorHex = @"#333333";
                    NSString *tableHTML = [WKMarkdownRenderer extractTableHTML:content fontSize:[WKApp shared].config.messageTextFontSize textColorHex:tableColorHex];
                    if (tableHTML) { [wv loadHTMLString:tableHTML baseURL:nil]; }
                    [container addSubview:wv];

                    NSInteger rowCount = [WKMarkdownRenderer tableRowCount:content];
                    container.tag = (NSInteger)(kTableToolbarHeight + rowCount * kTableRowHeight + kTableExtraPadding);

                    [self.messageContentView addSubview:container];
                    [self.segmentViews addObject:container];
                    [self.tableWebViews addObject:wv];
                    [self.tableToolbars addObject:toolbar];

                    UIScrollView *overlay = [self createSegmentOverlay];
                    [self.contentView addSubview:overlay];
                    [self.tableOverlays addObject:overlay];
                }
            }
            // 如果第一个段不是文本段，隐藏 textLbl
            if (!firstTextUsed) {
                self.textLbl.hidden = YES;
            } else {
                // 段落构建后 textLbl 内容已是第一段文本，须重置 lim_size
                // 避免仍保持全文尺寸导致溢出（转发时触发）
                CGSize fitSize = [self.textLbl sizeThatFits:CGSizeMake([WKApp shared].config.messageContentMaxWidth, CGFLOAT_MAX)];
                self.textLbl.lim_size = fitSize;
            }
            self.segmentsBuilt = YES;
        }
    } else {
        self.textLbl.hidden = NO;
        [self clearSegmentViews];
        self.segmentsBuilt = NO;
    }

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

    // BotFather 审批按钮
    if ([[self class] isBotFatherApproveMessage:model]) {
        self.botActionView.hidden = NO;
        NSString *rawContent = [[self class] getRawContent:model];
        self.approveCommand = [[self class] extractCommand:rawContent prefix:@"/approve"];
        self.rejectCommand = [[self class] extractCommand:rawContent prefix:@"/reject"];
    } else {
        self.botActionView.hidden = YES;
    }

}

-(void) onTapWithGestureRecognizer:(TapLongTapOrDoubleTapGestureRecognizerWrap*)gesture {
   // [self.textLbl onTap:gesture];
    // 表格工具栏复制按钮点击检测（参考 BotFather 按钮模式）
    for (NSUInteger i = 0; i < self.tableToolbars.count; i++) {
        UIView *toolbar = self.tableToolbars[i];
        // 找到工具栏中的复制按钮
        for (UIView *sub in toolbar.subviews) {
            if (![sub isKindOfClass:[UIButton class]]) continue;
            CGRect btnInContentView = [self.contentView convertRect:sub.bounds fromView:sub];
            if (CGRectContainsPoint(btnInContentView, gesture.tapPoint)) {
                [self copyTableTapped:(UIButton*)sub];
                return;
            }
        }
    }
    // BotFather 审批按钮点击检测
    if (!self.botActionView.hidden) {
        CGPoint pointInBotAction = [self.botActionView convertPoint:gesture.tapPoint fromView:self.contentView];
        if (CGRectContainsPoint(self.approveBtn.frame, pointInBotAction)) {
            [self approveBtnTap];
            return;
        }
        if (CGRectContainsPoint(self.rejectBtn.frame, pointInBotAction)) {
            [self rejectBtnTap];
            return;
        }
    }
    if([self replyAtPoint:gesture.tapPoint]) {
        [self replyBoxTap];
        return;
    }
    // 检查所有文本段 label 的 token（包括 textLbl 和分段创建的 label）
    NSArray *labelsToCheck = (self.segmentViews.count > 0) ? self.segmentViews : @[self.textLbl];
    for (UIView *v in labelsToCheck) {
        if (![v isKindOfClass:[UILabel class]]) continue;
        UILabel *lbl = (UILabel *)v;
        CGPoint point = [lbl convertPoint:gesture.tapPoint fromView:self.contentView];
        if (![lbl pointInside:point withEvent:nil]) continue;
        if (![lbl respondsToSelector:@selector(matchDidTapAttributedTextInLabelWithPoint:)]) continue;
        id<WKMatchToken> token = [(id)lbl matchDidTapAttributedTextInLabelWithPoint:point];
        if (token) {
            if (token.type == WKatchTokenTypeMetion) {
                [self didMetionClick:token];
            } else if (token.type == WKatchTokenTypeLink) {
                [self didLinkClick:token.text];
            } else if (token.type == WKatchTokenTypeLink2) {
                WKLinkToken *linToken = (WKLinkToken *)token;
                NSString *linkTarget = linToken.linkContent ?: linToken.linkText;
                [self didLinkClick:linkTarget];
            }
            return;
        }
    }
    
}

-(WKTapLongTapOrDoubleTapGestureRecognizerEvent*) tapActionAtPoint:(CGPoint)point {
    // 表格遮罩区域 + 工具栏区域：让手势识别器 fail，使触摸事件传递到遮罩/按钮
    for (UIScrollView *overlay in self.tableOverlays) {
        if (CGRectContainsPoint(overlay.frame, point)) {
            return [WKTapLongTapOrDoubleTapGestureRecognizerEvent action:WKTapLongTapOrDoubleTapGestureRecognizerActionFail];
        }
    }
    // 表格工具栏区域：不 fail，走 onTapWithGestureRecognizer: 处理复制按钮点击
    return [super tapActionAtPoint:point];
}

-(BOOL) shouldBeginContextGestureAtPoint:(CGPoint)point {
    CGPoint pointInContentView = [self.contentView convertPoint:point fromView:self.bubbleBackgroundView.superview];
    // 表格遮罩区域不触发长按菜单
    if (self.tableOverlays.count > 0) {
        for (UIScrollView *overlay in self.tableOverlays) {
            if (CGRectContainsPoint(overlay.frame, pointInContentView)) {
                return NO;
            }
        }
    }
    // 表格工具栏区域不触发长按菜单
    for (UIView *toolbar in self.tableToolbars) {
        CGRect toolbarInContentView = [self.contentView convertRect:toolbar.bounds fromView:toolbar];
        if (CGRectContainsPoint(toolbarInContentView, pointInContentView)) {
            return NO;
        }
    }
    return [super shouldBeginContextGestureAtPoint:point];
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

    // 分段布局：按顺序排列文本段和表格段
    if (self.segmentViews.count > 0) {
        CGFloat segTop = replyBoxBottom;
        NSInteger tableIdx = 0;
        CGFloat contentW = self.messageContentView.lim_width;
        for (NSUInteger i = 0; i < self.segmentViews.count; i++) {
            UIView *v = self.segmentViews[i];
            CGFloat spacing = (i < self.segmentViews.count - 1) ? kTableTopSpace : 0;
            if ([v isKindOfClass:[UILabel class]]) {
                CGSize fitSize = [v sizeThatFits:CGSizeMake(contentW, CGFLOAT_MAX)];
                v.frame = CGRectMake(0, segTop, contentW, fitSize.height);
                segTop += fitSize.height + spacing;
            } else {
                // 表格容器布局（容器内含 toolbar + webview）
                CGFloat tableH = v.tag > 0 ? v.tag : (kTableToolbarHeight + kTableRowHeight + kTableExtraPadding);
                v.frame = CGRectMake(0, segTop, contentW, tableH);

                // 容器内部布局：toolbar 在顶部，webview 紧跟其下
                if (tableIdx < (NSInteger)self.tableToolbars.count) {
                    UIView *toolbar = self.tableToolbars[tableIdx];
                    toolbar.frame = CGRectMake(0, 0, contentW, kTableToolbarHeight);
                    // 复制按钮靠右
                    for (UIView *sub in toolbar.subviews) {
                        if ([sub isKindOfClass:[UIButton class]]) {
                            sub.frame = CGRectMake(contentW - 36, 0, 36, kTableToolbarHeight);
                        }
                        // 底部分隔线
                        if (sub.tag == 9999) {
                            sub.frame = CGRectMake(0, kTableToolbarHeight - 0.5, contentW, 0.5);
                        }
                    }
                }
                if (tableIdx < (NSInteger)self.tableWebViews.count) {
                    WKWebView *wv = self.tableWebViews[tableIdx];
                    wv.frame = CGRectMake(0, kTableToolbarHeight, contentW, tableH - kTableToolbarHeight);
                }
                if (tableIdx < (NSInteger)self.tableOverlays.count) {
                    // overlay 只覆盖 webview 区域（跳过 toolbar）
                    CGRect containerInContentView = [self.contentView convertRect:v.frame fromView:self.messageContentView];
                    CGRect overlayRect = CGRectMake(containerInContentView.origin.x, containerInContentView.origin.y + kTableToolbarHeight, containerInContentView.size.width, containerInContentView.size.height - kTableToolbarHeight);
                    self.tableOverlays[tableIdx].frame = overlayRect;
                    tableIdx++;
                }
                segTop += tableH + spacing;
            }
        }
    }

    // BotFather 审批按钮布局
    if (!self.botActionView.hidden) {
        CGFloat top = self.textLbl.lim_top + self.textLbl.lim_size.height + kBotActionTopSpace;
        if (self.segmentViews.count > 0) {
            UIView *lastSeg = self.segmentViews.lastObject;
            top = CGRectGetMaxY(lastSeg.frame) + kBotActionTopSpace;
        }
        self.botActionView.frame = CGRectMake(0, top, self.messageContentView.lim_width, kBotActionBtnHeight);
        CGFloat btnW = (self.botActionView.lim_width - kBotActionBtnSpacing) / 2.0;
        self.rejectBtn.frame = CGRectMake(0, 0, btnW, kBotActionBtnHeight);
        self.approveBtn.frame = CGRectMake(btnW + kBotActionBtnSpacing, 0, btnW, kBotActionBtnHeight);
    }

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
        if(position == WKBubblePostionFirst || position == WKBubblePostionSingle) {
            self.nameLbl.lim_left =  WK_CONTENT_INSETS.left+WKLastBubbleOffsetSpace;
        }else{
            self.nameLbl.lim_left =  WK_CONTENT_INSETS.left;
        }

        self.nameLbl.lim_top =  WK_CONTENT_INSETS.top;
        // 收缩nameLbl宽度为文字实际宽度
        CGSize fitSize = [self.nameLbl sizeThatFits:CGSizeMake(self.messageContentView.lim_width, WK_NICKNAME_HEIGHT)];
        self.nameLbl.lim_width = MIN(fitSize.width, self.messageContentView.lim_width);
    } else {
        self.nameLbl.lim_width = self.messageContentView.lim_width;
    }

    // Bot标识布局：紧跟nameLbl右侧，垂直居中对齐
    self.botBadgeLbl.lim_left = self.nameLbl.lim_left + self.nameLbl.lim_width + 6.0f;
    self.botBadgeLbl.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.botBadgeLbl.lim_height) / 2.0f;
}

+(UIEdgeInsets) contentEdgeInsets:(WKMessageModel*)model {
    
    UIEdgeInsets edgeInsets = [super contentEdgeInsets:model];
    
   
    if([self isShowName:model]) {
        return UIEdgeInsetsMake(edgeInsets.top + WK_NICKNAME_HEIGHT + 10.0f, edgeInsets.left, edgeInsets.bottom, edgeInsets.right);
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

#pragma mark -- WKNavigationDelegate & UIScrollViewDelegate (表格滑动)

-(void) webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // 找到对应的 overlay，设置 contentSize
    NSUInteger idx = [self.tableWebViews indexOfObject:webView];
    if (idx == NSNotFound || idx >= self.tableOverlays.count) return;
    UIScrollView *overlay = self.tableOverlays[idx];
    [webView evaluateJavaScript:@"Math.max(document.body.scrollWidth, document.documentElement.scrollWidth)" completionHandler:^(id result, NSError *error) {
        if (!result || error) return;
        CGFloat contentWidth = [result floatValue];
        CGFloat frameWidth = overlay.frame.size.width;
        if (contentWidth > frameWidth && frameWidth > 0) {
            overlay.contentSize = CGSizeMake(contentWidth, overlay.frame.size.height);
        }
    }];
}

-(void) scrollViewDidScroll:(UIScrollView *)scrollView {
    // 遮罩层滑动时，同步偏移到对应的 WebView
    NSUInteger idx = [self.tableOverlays indexOfObject:scrollView];
    if (idx != NSNotFound && idx < self.tableWebViews.count) {
        self.tableWebViews[idx].scrollView.contentOffset = scrollView.contentOffset;
    }
}

#pragma mark -- BotFather 审批按钮

-(void) approveBtnTap {
    if (self.approveCommand) {
        [self.conversationContext sendTextMessage:self.approveCommand];
    }
}

-(void) rejectBtnTap {
    if (self.rejectCommand) {
        [self.conversationContext sendTextMessage:self.rejectCommand];
    }
}

@end
