//
//  WKTextMessageCell.m
//  WuKongBase
//
//  Created by tt on 2019/12/28.
//

#import "WKTextMessageCell.h"
#import "WKMessageTextView.h"
#import <objc/runtime.h>
#import <objc/message.h>
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
#import "WKExternalViewerResolver.h"
#import "WKMessageListView.h"
#import "WKReply+ExternalGroup.h"

#define replyNameFontSize    13.0f
#define replyContentFontSize 13.0f
#define replyAvatarSize      22.0f   // 头像从 16→22，更清晰

#define splitWidth      3.0f    // 左侧彩色竖线宽度（原来是 0 且被隐藏）
#define replyBoxPadH    8.0f    // 引用块水平内边距
#define replyBoxPadV    6.0f    // 引用块垂直内边距
#define replyItemSpacing 3.0f  // 头像/名称行 与 内容行之间的间距

#define replyNameLeftSpace 10.0f

#define textTopSpace 8.0f // 消息内容顶部距离

#define securityTipTopSpace 20.0f // 安全提醒距离文本顶部距离

#define securityTipFontSize 12.0f

#define replyToNameSpace 4.0f // 回复离名字的距离

#define kTableTopSpace 8.0f
#define kTableExtraPadding 10.0f
#define kTableToolbarHeight 36.0f

#define kBotActionBtnHeight 32.0f
#define kBotActionTopSpace 10.0f
#define kBotActionBtnSpacing 10.0f

@interface WKTextMessageCell ()<CNContactViewControllerDelegate,CNContactPickerDelegate,WKNavigationDelegate,UIScrollViewDelegate,UITextViewDelegate,UIGestureRecognizerDelegate>

@property(nonatomic,strong) WKMessageTextView *textLbl; // 原 UILabel，改为 UITextView 子类，天然支持文字选择
@property(nonatomic,strong) id selectLinkData;

// ---------- 分段渲染（文本段=UILabel，表格段=WKWebView）----------
@property(nonatomic,strong) NSMutableArray<UIView*> *segmentViews;       // 按顺序的 UILabel / WKWebView
@property(nonatomic,strong) NSMutableArray<WKWebView*> *tableWebViews;   // 表格 WebView 引用
@property(nonatomic,strong) NSMutableArray<UIScrollView*> *tableOverlays; // 滑动遮罩（在 contentView 上）
@property(nonatomic,strong) NSMutableArray<UIView*> *tableToolbars;      // 表格工具栏
@property(nonatomic,strong) NSMutableArray<NSString*> *tableRawContents; // 表格原始 markdown 内容（供复制用）
@property(nonatomic,assign) BOOL segmentsBuilt; // 分段视图是否已创建

// ---------- 链接卡片 ----------
@property(nonatomic,strong) UIView *linkCardView;
@property(nonatomic,assign) BOOL isLinkCard;

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

// ---------- 超长文本截断 ----------
@property(nonatomic,strong) UIButton *viewFullTextBtn;

@end

static const NSInteger kTextTruncateThreshold = 10000; // 超过此长度截断
static const NSInteger kTextPreviewLength = 8000;      // 预览显示的字符数
static const CGFloat kViewFullTextBtnHeight = 36.0f;  // "查看全文"按钮高度


// UITextView 子类：屏蔽系统复制/粘贴菜单，只保留自定义菜单
// 参考 Android SelectTextHelper CursorHandle.onTouchEvent：
// ACTION_MOVE → dismiss popup；ACTION_UP → show popup

// ── 自定义选区句柄（加到 window 上，不在 cell 层级内，零手势冲突） ──

@interface WKSelectionHandle : UIView
@property(nonatomic, assign) BOOL isStart;
@property(nonatomic, copy) void(^onDrag)(CGPoint locationInWindow);
@property(nonatomic, copy) void(^onDragEnd)(void);
- (instancetype)initWithStart:(BOOL)isStart;
- (void)positionAtWindowPoint:(CGPoint)pt;
@end

@implementation WKSelectionHandle {
    CGPoint _dragOffset;
}
- (instancetype)initWithStart:(BOOL)isStart {
    CGFloat pad = 20, lineH = 20, circleR = 6;
    self = [super initWithFrame:CGRectMake(0, 0, circleR*2+pad*2, lineH+circleR*2+pad)];
    if (self) {
        _isStart = isStart;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(wk_pan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGFloat pad = 20, lineW = 2, lineH = 20, circleR = 6;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor systemBlueColor] setFill];
    CGFloat cx = rect.size.width / 2;
    if (self.isStart) {
        CGContextFillEllipseInRect(ctx, CGRectMake(cx-circleR, pad, circleR*2, circleR*2));
        CGContextFillRect(ctx, CGRectMake(cx-lineW/2, pad+circleR*2, lineW, lineH));
    } else {
        CGContextFillRect(ctx, CGRectMake(cx-lineW/2, pad, lineW, lineH));
        CGContextFillEllipseInRect(ctx, CGRectMake(cx-circleR, pad+lineH, circleR*2, circleR*2));
    }
}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return CGRectContainsPoint(CGRectInset(self.bounds, -10, -10), point);
}
- (void)wk_pan:(UIPanGestureRecognizer *)gr {
    CGPoint loc = [gr locationInView:nil];
    if (gr.state == UIGestureRecognizerStateChanged) {
        if (self.onDrag) self.onDrag(loc);
    } else if (gr.state == UIGestureRecognizerStateEnded || gr.state == UIGestureRecognizerStateCancelled) {
        if (self.onDragEnd) self.onDragEnd();
    }
}
- (CGPoint)anchorOffset {
    CGFloat pad = 20, lineH = 20, circleR = 6, cx = self.bounds.size.width / 2;
    return self.isStart ? CGPointMake(cx, pad+circleR*2) : CGPointMake(cx, pad+lineH);
}
- (void)positionAtWindowPoint:(CGPoint)pt {
    CGPoint a = [self anchorOffset];
    self.frame = CGRectMake(pt.x-a.x, pt.y-a.y, self.bounds.size.width, self.bounds.size.height);
}
@end

@implementation WKTextMessageCell

/// WebView 加载完成后 JS 返回的实际表格内容高度（key = "clientMsgNo-tableIdx"）
static NSMutableDictionary *_jsTableHeights;
+ (NSMutableDictionary *)jsTableHeights {
    if (!_jsTableHeights) _jsTableHeights = [NSMutableDictionary dictionary];
    return _jsTableHeights;
}

/// 与 CSS buildTableWebViewCSS 中行高保持一致：padding(10+10) + lineHeight(fontSize*1.2) + border(~2)
+ (CGFloat)tableRowHeight {
    return ceil([WKApp shared].config.messageTextFontSize * 1.2 + 22.0f);
}

+ (WKMessageTextView *)sharedMeasureTV {
    static WKMessageTextView *tv;
    if (!tv) {
        tv = [[WKMessageTextView alloc] init];
    }
    tv.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    return tv;
}

/// 宽度：NSLayoutManager usedRect（实际最宽行，用于气泡宽度）
/// 高度：取 MAX(sizeThatFits, boundingRect)
///   - sizeThatFits：UITextView 排版高度（NSLayoutManager），防止 UITextView 截断
///   - boundingRect：CoreText 高度（UILabel 时代的测量方式），通常比 sizeThatFits 略大，
///     这个"多出来的"底部空间刚好吸收时间戳(trailingView)对最后一行文字的视觉叠加。
///     UILabel 时代一直依赖这个隐式 padding，换成 UITextView 后如果只用精确的
///     sizeThatFits 高度，时间戳会覆盖最后一行。
+ (CGSize)measureTextViewSize:(NSAttributedString *)attrStr maxWidth:(CGFloat)maxWidth {
    // Bugly #9386: sharedMeasureTV 是进程级静态 UITextView，NSTextStorage/NSLayoutManager 不线程安全。
    // pulldown/pullup 的后台预计算线程与主线程（channelInfoUpdate/refresh 等）并发进入该方法时，
    // 一方在 tv.attributedText=... 期间（textStorage beginEditing 未收束）另一方调 setFrame: 触发布局
    // 会抛 NSInternalInconsistencyException。非主线程统一 dispatch_sync 切回主线程串行化。
    if (![NSThread isMainThread]) {
        __block CGSize size = CGSizeZero;
        dispatch_sync(dispatch_get_main_queue(), ^{
            size = [[self class] measureTextViewSize:attrStr maxWidth:maxWidth];
        });
        return size;
    }
    WKMessageTextView *tv = [[self class] sharedMeasureTV];
    // Bugly #9455: heightForRowAtIndexPath 是 UITableView 直接回调的热路径，一旦 setAttributedText
    // 在 UIKit 内部抛异常（残留脏 textStorage、非法 attachment、字符串属性冲突等）就会 abort 整个 App。
    // 兜底：捕获后退到 NSAttributedString boundingRectWithSize:（纯 CoreText，不依赖 UITextView）。
    @try {
        tv.frame = CGRectMake(0, 0, maxWidth, 10000);
        tv.attributedText = attrStr;
        NSAttributedString *normalizedAttr = tv.attributedText;

        CGFloat tvH = [tv sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)].height;
        CGFloat brH = [normalizedAttr boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                            options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                            context:nil].size.height;
        CGFloat h = MAX(ceil(tvH), ceil(brH));

        NSLayoutManager *lm = tv.layoutManager;
        NSTextContainer *tc = tv.textContainer;
        [lm ensureLayoutForTextContainer:tc];
        CGRect usedRect = [lm usedRectForTextContainer:tc];
        CGFloat w = MIN(ceil(usedRect.size.width), maxWidth);

        // R4 fix (Critical privacy): 测量在 cell 渲染热径上,
        // 不能打消息正文预览(用户数据 + 性能污染). DEBUG-only 保留测量维度 metadata。
#if DEBUG
        NSLog(@"[BubbleHeight] measure: textLen=%lu maxW=%.1f | tvH=%.2f brH=%.2f → h=%.0f w=%.0f",
              (unsigned long)attrStr.string.length, maxWidth, tvH, brH, h, w);
#endif

        return CGSizeMake(w, h);
    } @catch (NSException *e) {
        NSLog(@"[BubbleHeight] measure exception, fallback to boundingRect: name=%@ reason=%@",
              e.name, e.reason);
        CGFloat fbH = 0;
        @try {
            fbH = [attrStr boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                        context:nil].size.height;
        } @catch (NSException *inner) {
            NSLog(@"[BubbleHeight] fallback boundingRect also failed: %@", inner.reason);
            CGFloat font = [WKApp shared].config.messageTextFontSize;
            fbH = font * 1.4 * MAX(1, (NSInteger)ceilf((float)attrStr.string.length / MAX(8, (NSInteger)(maxWidth / MAX(1, font))))); // 粗略估算：字符数/每行可容纳字符数 × 行高
        }
        return CGSizeMake(maxWidth, ceil(MAX(fbH, 1)));
    }
}

+ (CGFloat)measureTextViewHeight:(NSAttributedString *)attrStr maxWidth:(CGFloat)maxWidth {
    return [[self class] measureTextViewSize:attrStr maxWidth:maxWidth].height;
}

-(void) invalidateSegments {
    self.segmentsBuilt = NO;
    [self clearSegmentViews];
}


+ (CGSize)sizeForMessage:(WKMessageModel *)model {
   CGSize size = [super sizeForMessage:model];
    return size;
}

+(WKMemoryCache*) textAttrCache {
    static WKMemoryCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[WKMemoryCache alloc] init];
        cache.maxCacheNum = 500;
    });
    return cache;
}

+(NSString*) textAttrCacheKey:(WKMessageModel*)message {
    NSString *key = [NSString stringWithFormat:@"%llu%@",message.messageId,message.clientMsgNo];
    if(message.remoteExtra.contentEdit) {
        key = [NSString stringWithFormat:@"%@-edit-%lu",message.clientMsgNo,message.remoteExtra.editedAt];
    }
    // 始终把当前 style 拼进 key：cmark renderer 的色板 / 数学 attachment 的图像
    // 都跟 isDark 绑定，深色模式切换后必须 invalidate 旧 attrStr。原实现只在 html
    // 路径加了 style，markdown / LaTeX 走另外的分支会拿到陈旧颜色。
    key = [NSString stringWithFormat:@"%@-style-%lu",key,(unsigned long)WKApp.shared.config.style];
    return key;
}

+(NSMutableAttributedString*) plainTextAttrStr:(WKMessageModel*)model {
    NSString *content = [self getRawContent:model];
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:content ?: @""];
    attrStr.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    UIColor *textColor = model.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.messageRecvTextColor;
    [attrStr addAttribute:NSForegroundColorAttributeName value:textColor range:NSMakeRange(0, attrStr.length)];
    return attrStr;
}

+ (CGSize)contentSizeForMessage:(WKMessageModel *)model {
    NSString *checkContent = [self getRawContent:model];
    if ([checkContent hasPrefix:@"[链接]"]) {
        return CGSizeMake(220, 70);
    }
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
        // 引用块高度 = 上下内边距 + max(头像,名字行) + 行间距 + 内容行
        CGFloat replyRow1H = MAX(replyAvatarSize, replyNameSize.height);
        CGFloat replyBoxH  = replyBoxPadV + replyRow1H + replyItemSpacing + replyContentSize.height + replyBoxPadV;
        size = CGSizeMake(MAX(MAX(messageTextSize.width, replyNameSize.width + replyAvatarSize + 4.0f + splitWidth + replyBoxPadH * 2), replyContentSize.width + splitWidth + replyBoxPadH * 2),
                          messageTextSize.height + replyBoxH + textTopSpace + nameTopSpace);
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

    // 超长文本截断时增加"查看全文"按钮高度
    if ([self isLongText:model]) {
        size.height += kViewFullTextBtnHeight;
    }

    return CGSizeMake(MAX(size.width, nicknameWidth), size.height);

}


-(void) initUI {
    [super initUI];
    // 原 UILabel，现改为 WKMessageTextView（UITextView 子类）
    // 构造函数已配置 display-only 默认值：
    //   scrollEnabled=NO, editable=NO, selectable=NO,
    //   textContainerInset=zero, lineFragmentPadding=0, maximumNumberOfLines=0
    self.textLbl = [[WKMessageTextView alloc] init];
    self.textLbl.delegate = self; // 用于 shouldInteractWithURL: 处理链接点击
    [self.textLbl setFont:[[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize]];
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

-(void) viewFullTextTapped {
    NSString *fullText = [[self class] getFullRawContent:self.messageModel];
    // 用简单的全文查看页面展示
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = LLang(@"查看全文");
    vc.view.backgroundColor = [WKApp shared].config.backgroundColor;
    UITextView *textView = [[UITextView alloc] initWithFrame:vc.view.bounds];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.text = fullText;
    textView.editable = NO;
    textView.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
    textView.textColor = [WKApp shared].config.defaultTextColor;
    textView.backgroundColor = [UIColor clearColor];
    textView.contentInset = UIEdgeInsetsMake(10, 10, 10, 10);
    [vc.view addSubview:textView];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

static const NSUInteger kWebViewPoolLimit = 4;
static NSMutableArray<WKWebView*> *_webViewPool;
static WKWebViewConfiguration *_sharedWebViewConfig;

+(NSMutableArray<WKWebView*>*) webViewPool {
    if (!_webViewPool) {
        _webViewPool = [NSMutableArray array];
    }
    return _webViewPool;
}

+(WKWebViewConfiguration*) sharedWebViewConfig {
    if (!_sharedWebViewConfig) {
        _sharedWebViewConfig = [[WKWebViewConfiguration alloc] init];
    }
    return _sharedWebViewConfig;
}

-(void) clearSegmentViews {
    // 回收 WKWebView 到复用池
    for (WKWebView *wv in self.tableWebViews) {
        wv.navigationDelegate = nil;
        [wv stopLoading];
        [wv loadHTMLString:@"" baseURL:nil];
        NSMutableArray *pool = [WKTextMessageCell webViewPool];
        if (pool.count < kWebViewPoolLimit) {
            [pool addObject:wv];
        }
    }
    for (UIView *v in self.segmentViews) {
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
    NSMutableArray *pool = [WKTextMessageCell webViewPool];
    WKWebView *wv = nil;
    if (pool.count > 0) {
        wv = pool.lastObject;
        [pool removeLastObject];
        wv.frame = CGRectZero;
    } else {
        // 卡顿诊断：WKWebView pool MISS → 现场新 alloc。WebKit 首次 alloc 200~500ms
        // (走 WebContent XPC 拉起 + ScreenTime dispatch_once)。如果同一会话里反复 MISS
        // 说明池容量太小或者 cell 重用没把 webview 还回池。
        NSLog(@"[CellPerf] webview POOL_MISS: alloc new WKWebView (pool=%lu)", (unsigned long)pool.count);
        wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[WKTextMessageCell sharedWebViewConfig]];
    }
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
    // tap 手势：将点击透传到 WebView，通过 JS 找到链接并触发导航
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTableLinkTap:)];
    [sv addGestureRecognizer:tap];
    return sv;
}

- (void)handleTableLinkTap:(UITapGestureRecognizer *)gr {
    NSInteger idx = [self.tableOverlays indexOfObject:gr.view];
    if (idx == NSNotFound || idx >= self.tableWebViews.count) return;
    WKWebView *wv = self.tableWebViews[idx];
    CGPoint pt = [gr locationInView:gr.view];
    // overlay 从 toolbar 底部开始覆盖 WebView，tap 坐标 = CSS client 坐标（无需补偿）
    // elementFromPoint 使用 client 坐标，WebView 内部处理 scrollOffset
    NSString *js = [NSString stringWithFormat:
        @"(function(){"
        @"var el=document.elementFromPoint(%f,%f);"
        @"if(!el)return;"
        @"var a=el.tagName==='A'?el:(el.closest?el.closest('a'):null);"
        @"if(a&&a.href)window.location.href=a.href;"
        @"})()", pt.x, pt.y];
    [wv evaluateJavaScript:js completionHandler:nil];
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
    if(message.streamOn && message.streamFlag!=WKStreamFlagEnd) {
        return [self getContentAttrStr:message];
    }

    NSString *key = [self textAttrCacheKey:message];
    id rawContent = [message content];
    if(message.remoteExtra.contentEdit) {
        rawContent = message.remoteExtra.contentEdit;
    }
    if (![rawContent isKindOfClass:[WKTextContent class]]) {
        return [[NSMutableAttributedString alloc] initWithString:@""];
    }
    NSMutableAttributedString *attrStr = [[self textAttrCache] getCache:key];
    if(attrStr) {
        return attrStr;
    }

    // 卡顿诊断：textAttrCache MISS。重点关注同一个 key 是否反复 miss。
    // 反复 miss = key 计算错位 / 缓存被频繁淘汰 / 该消息内容太特殊触发 parse 异常慢。
    CFAbsoluteTime _parseT0 = CFAbsoluteTimeGetCurrent();
    attrStr = [self getContentAttrStr:message];
    CGFloat _parseMs = (CFAbsoluteTimeGetCurrent() - _parseT0) * 1000;
    if (_parseMs > 4.0) {
        NSString *_preview = @"";
        if ([rawContent respondsToSelector:@selector(content)]) {
            NSString *_t = [(id)rawContent content];
            if ([_t isKindOfClass:[NSString class]]) {
                _preview = _t.length > 40 ? [_t substringToIndex:40] : _t;
                _preview = [_preview stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"];
            }
        }
        NSLog(@"[CellPerf] parseAttr MISS: %.1fms key=%@ preview=[%@]", _parseMs, key, _preview);
    }

    if(key) {
        [[self textAttrCache] setCache:attrStr forKey:key];
    }
    return attrStr;
}

+(NSMutableAttributedString*) getContentAttrStr:(WKMessageModel*)message {
    id rawObj = [message content];
    if(message.remoteExtra.contentEdit) {
        rawObj = message.remoteExtra.contentEdit;
    }
    // 类型保护：竞态下 content 可能不是 WKTextContent
    if (![rawObj isKindOfClass:[WKTextContent class]]) {
        NSMutableAttributedString *fallback = [[NSMutableAttributedString alloc] initWithString:@""];
        return fallback;
    }
    WKTextContent *textContent = (WKTextContent*)rawObj;
    NSMutableString *content = [[NSMutableString alloc] initWithString:textContent.content ?: @""];
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

    // LaTeX 预处理：若包含 LaTeX 命令，转成 Markdown，数学段抽成 ￼ 占位符。
    // 命中预处理后必须走 markdown 渲染路径（即使产物的 containsMarkdown 返回 false）。
    NSArray<WKLaTeXMathSegment*> *mathSegments = nil;
    if (![textContent.format isEqualToString:@"html"] && [WKLaTeXPreprocessor containsLaTeX:renderContent]) {
        @try {
            WKLaTeXPreprocessResult *pp = [WKLaTeXPreprocessor preprocess:renderContent];
            renderContent = pp.markdown;
            mathSegments = pp.mathSegments;
        } @catch (NSException *exception) {
            NSLog(@"[LaTeXPreprocessor] exception, fallback to raw text: %@", exception);
        }
    }

    BOOL useMarkdown = NO;
    if (![textContent.format isEqualToString:@"html"]) {
        if (renderContent.length > 0 && (mathSegments != nil || [WKMarkdownRenderer containsMarkdown:renderContent])) {
            UIColor *textColor = message.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.messageRecvTextColor;
            NSString *colorHex = [textColor toHexRGB];
            NSAttributedString *mdAttr = nil;
            @try {
                mdAttr = [WKMarkdownRenderer render:renderContent fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex dynamicTextColor:textColor];
            if (mdAttr && mdAttr.length > 0) {
                useMarkdown = YES;
                NSMutableAttributedString *mdMutable = [[NSMutableAttributedString alloc] initWithAttributedString:mdAttr];
                mdMutable.font = attrStr.font;

                // LaTeX 数学占位符 → 等宽样式 TeX 源文本（Phase 1）。继承占位符所在
                // run 的颜色/段落样式，所以嵌在 heading/quote/list 里时行高与排版
                // 与现有 markdown 一致。Phase 2 接入 iosMath 时只改这里的实现。
                if (mathSegments.count > 0) {
                    BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
                    [WKLaTeXPreprocessor replaceMathPlaceholdersIn:mdMutable
                                                         segments:mathSegments
                                                         fontSize:[WKApp shared].config.messageTextFontSize
                                                           isDark:isDark];
                }

                // 从 cmark-gfm 渲染结果中提取可点击的 tokens
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
                    [mdMutable addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:89.0f/255.0f green:121.0f/255.0f blue:240.0f/255.0f alpha:1.0f] range:range];
                    [mdMutable addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
                }

                // 2. 从消息 entities 中提取 @mention tokens，在渲染后的文本中查找匹配位置
                NSArray<WKMessageEntity*> *entities = message.content.entities;
                if (message.remoteExtra.contentEdit) {
                    entities = message.remoteExtra.contentEdit.entities;
                }
                NSLog(@"[Mention] markdown路径: msgNo=%@ entities=%lu rawLen=%lu mdLen=%lu",
                      message.clientMsgNo, (unsigned long)(entities ? entities.count : 0),
                      (unsigned long)content.length, (unsigned long)mdMutable.string.length);
                if (entities) {
                    NSString *renderedText = mdMutable.string;
                    NSMutableIndexSet *usedRanges = [NSMutableIndexSet indexSet];
                    for (WKMessageEntity *entity in entities) {
                        NSLog(@"[Mention]   entity: type=%@ range=(%lu,%lu) value=%@",
                              entity.type, (unsigned long)entity.range.location, (unsigned long)entity.range.length, entity.value ?: @"(nil)");
                        if (![entity.type isEqualToString:WKMentionRichTextStyle]) {
                            NSLog(@"[Mention]     → 跳过(非mention类型)");
                            continue;
                        }
                        if (entity.range.location + entity.range.length > content.length) {
                            NSLog(@"[Mention]     → 跳过(range越界: %lu+%lu > %lu)",
                                  (unsigned long)entity.range.location, (unsigned long)entity.range.length, (unsigned long)content.length);
                            continue;
                        }
                        NSString *mentionText = [content substringWithRange:entity.range];
                        if ([mentionText hasSuffix:@" "]) {
                            mentionText = [mentionText substringToIndex:mentionText.length - 1];
                        }
                        if (![mentionText hasPrefix:@"@"]) {
                            NSLog(@"[Mention]     → 跳过(非@开头: \"%@\")", mentionText);
                            continue;
                        }
                        // 在渲染后的文本中查找这段 @xxx（跳过已使用的位置，避免重复匹配）
                        NSRange searchRange = NSMakeRange(0, renderedText.length);
                        NSRange foundRange = NSMakeRange(NSNotFound, 0);
                        while (searchRange.location < renderedText.length) {
                            foundRange = [renderedText rangeOfString:mentionText options:0 range:searchRange];
                            if (foundRange.location == NSNotFound) break;
                            if (![usedRanges containsIndexesInRange:foundRange]) break;
                            searchRange.location = foundRange.location + foundRange.length;
                            searchRange.length = renderedText.length - searchRange.location;
                            foundRange.location = NSNotFound;
                        }
                        if (foundRange.location != NSNotFound) {
                            [usedRanges addIndexesInRange:foundRange];
                            WKMetionToken *token = [WKMetionToken new];
                            token.range = foundRange;
                            token.uid = entity.value ?: @"";
                            token.text = mentionText;
                            [clickableTokens addObject:token];
                            UIColor *mentionColor = message.isSend ? [UIColor whiteColor] : [WKApp shared].config.themeColor;
                            [mdMutable addAttribute:NSForegroundColorAttributeName value:mentionColor range:foundRange];
                            [mdMutable addAttribute:NSUnderlineStyleAttributeName value:@1 range:foundRange];
                            NSLog(@"[Mention]     ✅ 找到: \"%@\" → rendered位置(%lu,%lu) uid=%@",
                                  mentionText, (unsigned long)foundRange.location, (unsigned long)foundRange.length, entity.value ?: @"");
                        } else {
                            NSLog(@"[Mention]     ❌ 未找到: \"%@\" 在rendered文本中不存在", mentionText);
                            // 打印渲染文本中所有包含@的位置，帮助排查
                            NSRange atRange = [renderedText rangeOfString:@"@"];
                            if (atRange.location != NSNotFound) {
                                NSUInteger start = atRange.location;
                                NSUInteger end = MIN(start + 20, renderedText.length);
                                NSLog(@"[Mention]       rendered文本中@附近: \"%@\"", [renderedText substringWithRange:NSMakeRange(start, end - start)]);
                            }
                        }
                    }
                } else {
                    NSLog(@"[Mention]   无entities");
                }

                // 三态 mention：广播 token（@所有人 / @所有AI / @all）在 markdown 渲染后的文本中高亮
                // 这些 token 不在 entities 中，需要按文本扫描补齐 pill 样式
                // Locale-independent 标签集 — 必须覆盖任意 sender locale 渲染出的 wire text
                // （Chinese "所有AI" / English "All AIs" 都可能到达任意 receiver），
                // 不能只用 receiver 的当前 locale。
                {
                    NSString *renderedText = mdMutable.string;
                    NSMutableArray<NSString*> *broadcastTokens = [NSMutableArray array];
                    NSMutableSet<NSString*> *seenTokens = [NSMutableSet set];
                    NSArray<NSString*> *labelCandidates = @[
                        @"所有人",           // Chinese canonical
                        @"所有AI",           // Chinese canonical
                        @"all",              // legacy English
                        @"All People",       // en.lproj 所有人
                        @"All AIs",          // en.lproj 所有AI
                        LLang(@"所有人"),     // current locale (may add future translations)
                        LLang(@"所有AI"),     // current locale
                    ];
                    for (NSString *label in labelCandidates) {
                        if (label.length == 0) continue;
                        NSString *tok = [NSString stringWithFormat:@"@%@", label];
                        NSString *key = tok.lowercaseString;
                        if ([seenTokens containsObject:key]) continue;
                        [seenTokens addObject:key];
                        [broadcastTokens addObject:tok];
                    }
                    // 长度降序：保证 "@All AIs" 优先于 "@all" 命中
                    [broadcastTokens sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
                        if (a.length > b.length) return NSOrderedAscending;
                        if (a.length < b.length) return NSOrderedDescending;
                        return NSOrderedSame;
                    }];
                    UIColor *mentionColor = message.isSend ? [UIColor whiteColor] : [WKApp shared].config.themeColor;
                    for (NSString *bt in broadcastTokens) {
                        if (bt.length <= 1) continue;
                        NSRange searchRange = NSMakeRange(0, renderedText.length);
                        while (searchRange.location < renderedText.length) {
                            NSRange found = [renderedText rangeOfString:bt options:0 range:searchRange];
                            if (found.location == NSNotFound) break;
                            searchRange.location = found.location + found.length;
                            searchRange.length = renderedText.length - searchRange.location;
                            // 跳过与已有 token 重叠的位置
                            BOOL overlaps = NO;
                            for (id<WKMatchToken> existing in clickableTokens) {
                                NSRange er = existing.range;
                                if (found.location < er.location + er.length && er.location < found.location + found.length) {
                                    overlaps = YES; break;
                                }
                            }
                            if (overlaps) continue;
                            WKMetionToken *token = [WKMetionToken new];
                            token.range = found;
                            token.uid = @"all"; // broadcast sentinel
                            token.text = bt;
                            [clickableTokens addObject:token];
                            [mdMutable addAttribute:NSForegroundColorAttributeName value:mentionColor range:found];
                            [mdMutable addAttribute:NSUnderlineStyleAttributeName value:@1 range:found];
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
                    [mdMutable addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:89.0f/255.0f green:121.0f/255.0f blue:240.0f/255.0f alpha:1.0f] range:autoToken.range];
                    [mdMutable addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:autoToken.range];
                }

                mdMutable.tokens = clickableTokens;

                return mdMutable;
            }
            } @catch (NSException *exception) {
                NSLog(@"[Markdown] render exception caught, fallback to plain text: %@", exception);
                // fallback 到纯文本渲染
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

        // --- @mention 诊断日志 ---
        {
            NSInteger mentionCount = 0;
            for (id<WKMatchToken> t in tokens) {
                if (t.type == WKatchTokenTypeMetion) mentionCount++;
            }
            if ([textForRender containsString:@"@"]) {
                NSLog(@"[Mention] 非markdown路径: msgNo=%@ entityMentions=%lu autoMentions=%lu totalMentions=%ld text前30=\"%@\"",
                      message.clientMsgNo,
                      (unsigned long)entityTokens.count, (unsigned long)autoMentionTokens.count, (long)mentionCount,
                      textForRender.length > 30 ? [textForRender substringToIndex:30] : textForRender);
            }
        }

        [attrStr lim_render:textForRender tokens:tokens];
    }

    return attrStr;
}

/// 自动检测文本中的 @mention（用已知成员/联系人名字反向匹配，支持名字含空格）
+(NSArray<id<WKMatchToken>>*) detectMentionsInText:(NSString*)text channel:(WKChannel*)channel existingTokens:(NSArray<id<WKMatchToken>>*)existingTokens {
    if (!text || text.length == 0) return @[];

    NSMutableArray<id<WKMatchToken>> *result = [NSMutableArray array];

    // 收集所有候选名字 -> uid 的映射（名字按长度降序，优先匹配长名字）
    NSMutableArray<NSDictionary*> *candidates = [NSMutableArray array];

    // 三态 mention：广播 token（@所有人 / @所有AI / @all）始终参与高亮，与 @所有人 同色 pill
    // uid 统一用 "all" sentinel — 点击不跳人卡片，仅作渲染标记
    // Locale-independent：必须覆盖所有可能的 wire text（任意 sender locale 渲染结果），
    // 不能只用 receiver 的 LLang 当前 locale。
    NSArray<NSString*> *broadcastNames = @[
        @"所有人",           // Chinese canonical
        @"所有AI",           // Chinese canonical
        @"all",              // legacy English
        @"All People",       // en.lproj 所有人
        @"All AIs",          // en.lproj 所有AI
        LLang(@"所有人"),     // current locale (may add future translations)
        LLang(@"所有AI"),     // current locale
    ];
    NSMutableSet *broadcastSeen = [NSMutableSet set];
    for (NSString *bname in broadcastNames) {
        if (bname.length == 0) continue;
        NSString *seenKey = bname.lowercaseString;
        if ([broadcastSeen containsObject:seenKey]) continue;
        [broadcastSeen addObject:seenKey];
        [candidates addObject:@{@"name": bname, @"uid": @"all"}];
    }

    NSArray<WKChannelMember*> *members = nil;
    if (channel.channelType == WK_GROUP) {
        members = [[WKSDK shared].channelManager getMembersWithChannel:channel];
    }
    if (members) {
        for (WKChannelMember *member in members) {
            NSString *uid = member.memberUid;
            WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:uid]];
            NSMutableSet *names = [NSMutableSet set];
            if (info) {
                if (info.name.length > 0) [names addObject:info.name];
                if (info.remark.length > 0) [names addObject:info.remark];
                if (info.displayName.length > 0) [names addObject:info.displayName];
            }
            if (member.memberName.length > 0) [names addObject:member.memberName];
            if (uid.length > 0) [names addObject:uid];
            for (NSString *name in names) {
                [candidates addObject:@{@"name": name, @"uid": uid}];
            }
        }
    }

    // 补充联系人
    NSArray<WKChannelInfo*> *allContacts = [[WKChannelInfoDB shared] queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal follow:WKChannelInfoFollowFriend];
    NSMutableSet *memberUids = [NSMutableSet set];
    for (NSDictionary *c in candidates) [memberUids addObject:c[@"uid"]];
    for (WKChannelInfo *info in allContacts) {
        if ([memberUids containsObject:info.channel.channelId]) continue;
        NSMutableSet *names = [NSMutableSet set];
        if (info.name.length > 0) [names addObject:info.name];
        if (info.remark.length > 0) [names addObject:info.remark];
        if (info.displayName.length > 0) [names addObject:info.displayName];
        for (NSString *name in names) {
            [candidates addObject:@{@"name": name, @"uid": info.channel.channelId}];
        }
    }

    // 按名字长度降序排列，优先匹配长名字（避免短前缀误匹配）
    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [@([b[@"name"] length]) compare:@([a[@"name"] length])];
    }];

    // 已匹配的范围（防止重叠）
    NSMutableArray<NSValue*> *matchedRanges = [NSMutableArray array];

    for (NSDictionary *candidate in candidates) {
        NSString *name = candidate[@"name"];
        NSString *uid = candidate[@"uid"];
        NSString *pattern = [NSString stringWithFormat:@"@%@", name];

        NSRange searchRange = NSMakeRange(0, text.length);
        while (searchRange.location < text.length) {
            NSRange found = [text rangeOfString:pattern options:0 range:searchRange];
            if (found.location == NSNotFound) break;

            // 推进搜索范围
            searchRange.location = found.location + found.length;
            searchRange.length = text.length - searchRange.location;

            // 检查与已有 token 和已匹配范围是否重叠
            BOOL overlaps = NO;
            for (id<WKMatchToken> token in existingTokens) {
                if (token.type != WKatchTokenTypeMetion) continue;
                NSRange tr = token.range;
                if (found.location < tr.location + tr.length && tr.location < found.location + found.length) {
                    overlaps = YES; break;
                }
            }
            if (!overlaps) {
                for (NSValue *v in matchedRanges) {
                    NSRange mr = [v rangeValue];
                    if (found.location < mr.location + mr.length && mr.location < found.location + found.length) {
                        overlaps = YES; break;
                    }
                }
            }
            if (overlaps) continue;

            [matchedRanges addObject:[NSValue valueWithRange:found]];

            WKMetionToken *token = [WKMetionToken new];
            token.range = found;
            token.uid = uid;
            token.text = [text substringWithRange:found];
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
                    // 范围越界检查
                    if(messageEntiy.range.location + messageEntiy.range.length > text.length) continue;
                   NSString *mentionText =  [text substringWithRange:messageEntiy.range];
                    // 验证提取的文本确实以 @ 开头（防止 entity range 偏移）
                    if (![mentionText hasPrefix:@"@"]) continue;

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

/// 判断消息文本是否超长需要截断
+(BOOL) isLongText:(WKMessageModel*)message {
    // 流式消息不截断（内容还在增长）
    if (message.streamOn && message.streamFlag != WKStreamFlagEnd) return NO;
    NSString *full = [self getFullRawContent:message];
    return full.length > kTextTruncateThreshold;
}

/// 提取完整原始文本（不截断）
+(NSString*) getFullRawContent:(WKMessageModel*)message {
    id rawContent = [message content];
    if (message.remoteExtra.contentEdit) {
        rawContent = message.remoteExtra.contentEdit;
    }
    if (![rawContent isKindOfClass:[WKTextContent class]]) {
        return @"";
    }
    WKTextContent *textContent = (WKTextContent*)rawContent;
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

/// 提取消息的原始文本内容（合并流式内容，超长时截断）
+(NSString*) getRawContent:(WKMessageModel*)message {
    id rawContent = [message content];
    if (message.remoteExtra.contentEdit) {
        rawContent = message.remoteExtra.contentEdit;
    }
    // 类型保护：非 WKTextContent 时返回空字符串，避免崩溃
    if (![rawContent isKindOfClass:[WKTextContent class]]) {
        return @"";
    }
    WKTextContent *textContent = (WKTextContent*)rawContent;
    NSMutableString *content = [[NSMutableString alloc] initWithString:textContent.content ?: @""];
    if (message.streams && message.streams.count > 0) {
        for (WKStream *stream in message.streams) {
            if ([stream.content isKindOfClass:WKTextContent.class]) {
                [content appendString:((WKTextContent*)stream.content).content];
            }
        }
    }
    // 超长文本截断为预览长度，避免 cmark-gfm 渲染超长 Markdown 卡顿
    if (content.length > kTextTruncateThreshold) {
        // 流式消息不截断
        if (!(message.streamOn && message.streamFlag != WKStreamFlagEnd)) {
            return [content substringToIndex:kTextPreviewLength];
        }
    }
    return content;
}

/// 判断是否为 BotFather 好友审批消息
/// 帮助文本包含多个 /command，审批消息只包含 /approve 和 /reject 两个命令
+(BOOL) isBotFatherApproveMessage:(WKMessageModel*)model {
    NSString *botfatherUID = [WKApp shared].config.botfatherUID;
    if (!botfatherUID || botfatherUID.length == 0) return NO;
    if (![model.channel.channelId isEqualToString:botfatherUID]) return NO;
    if (model.isSend) return NO;
    NSString *rawContent = [[self class] getRawContent:model];
    if (![rawContent containsString:@"/approve"]) return NO;
    // 帮助文本会包含 /help、/newbot 等多个命令，排除这种情况
    if ([rawContent containsString:@"/help"] || [rawContent containsString:@"/newbot"]) return NO;
    return YES;
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
    return kTableToolbarHeight + rowCount * [[self class] tableRowHeight] + kTableExtraPadding;
}

/// 分段计算内容高度（与 layoutSubviews 中逐段布局逻辑完全一致）
/// 使用 measureTextViewHeight: 测量（与 layoutSubviews 中 UITextView.sizeThatFits: 一致）
+ (WKMemoryCache *)segHeightCache {
    static WKMemoryCache *cache;
    if (!cache) {
        cache = [[WKMemoryCache alloc] init];
        cache.maxCacheNum = 0;
    }
    return cache;
}

+(CGFloat) segmentedContentHeightForMessage:(WKMessageModel*)model {
    WKMemoryCache *segHeightCache = [[self class] segHeightCache];

    // 流式消息不缓存
    BOOL isStreaming = model.streamOn && model.streamFlag != WKStreamFlagEnd;
    NSString *modeTag = ([WKApp shared].config.style == WKSystemStyleDark) ? @"d" : @"l";
    NSString *cacheKey = [NSString stringWithFormat:@"%@-segH-%@", model.clientMsgNo, modeTag];
    if (model.remoteExtra.contentEdit) {
        cacheKey = [NSString stringWithFormat:@"%@-segH-edit-%lu-%@", model.clientMsgNo, model.remoteExtra.editedAt, modeTag];
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
    UIFont *baseFont = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];

    NSInteger tableSegIdx = 0;
    for (NSUInteger i = 0; i < segments.count; i++) {
        NSDictionary *seg = segments[i];
        NSString *type = seg[@"type"];
        NSString *content = seg[@"content"];
        CGFloat spacing = (i < segments.count - 1) ? kTableTopSpace : 0;

        if ([type isEqualToString:@"text"]) {
            // LaTeX 预处理：与 layoutSubviews 的实际渲染路径保持一致，否则未预处理
            // 的原始 LaTeX 命令（\subsection / \textbf / \begin{quote} 等）会被 cmark
            // 当成普通文本，行数被大量高估，气泡留出大块空白。
            NSArray<WKLaTeXMathSegment*> *segMathSegments = nil;
            NSString *measureContent = content;
            if ([WKLaTeXPreprocessor containsLaTeX:measureContent]) {
                @try {
                    WKLaTeXPreprocessResult *pp = [WKLaTeXPreprocessor preprocess:measureContent];
                    measureContent = pp.markdown;
                    segMathSegments = pp.mathSegments;
                } @catch (NSException *e) {
                    NSLog(@"[LaTeXPreprocessor] seg-measure exception: %@", e);
                }
            }

            NSAttributedString *attrForMeasure = nil;
            if (segMathSegments != nil || [WKMarkdownRenderer containsMarkdown:measureContent]) {
                @try {
                    attrForMeasure = [WKMarkdownRenderer render:measureContent fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex];
                } @catch (NSException *e) {
                    attrForMeasure = nil;
                }
            }
            if (!attrForMeasure) {
                NSMutableAttributedString *plainAttr = [[NSMutableAttributedString alloc] init];
                plainAttr.font = baseFont;
                plainAttr.textColor = textColor;
                [plainAttr lim_render:measureContent tokens:nil];
                attrForMeasure = plainAttr;
            }
            // 数学占位符替换成 iosMath 附件（或 monospace 回退），让 boundingRect 能
            // 正确累计 attachment 带来的行高变化。注意：与实际渲染共享 NSCache，
            // 这里命中后 layoutSubviews 那次重渲染无额外开销。
            if (segMathSegments.count > 0) {
                BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
                NSMutableAttributedString *mutableMeasure = [[NSMutableAttributedString alloc] initWithAttributedString:attrForMeasure];
                [WKLaTeXPreprocessor replaceMathPlaceholdersIn:mutableMeasure
                                                     segments:segMathSegments
                                                     fontSize:[WKApp shared].config.messageTextFontSize
                                                       isDark:isDark];
                attrForMeasure = mutableMeasure;
            }
            // boundingRect 是线程安全的，可在后台线程调用
            // +4 补偿 boundingRect 与 UILabel.sizeThatFits 的测量偏差
            CGRect rect = [attrForMeasure boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                                       context:nil];
            totalHeight += ceil(rect.size.height) + 4.0f + spacing;
        } else {
            // 表格段：优先使用 JS 返回的实际内容高度，否则用公式估算
            NSString *jsKey = [NSString stringWithFormat:@"%@-%ld", model.clientMsgNo, (long)tableSegIdx];
            NSNumber *jsHeight = [[self class] jsTableHeights][jsKey];
            if (jsHeight) {
                totalHeight += [jsHeight floatValue] + spacing;
            } else {
                NSInteger rowCount = [WKMarkdownRenderer tableRowCount:content];
                totalHeight += kTableToolbarHeight + rowCount * [[self class] tableRowHeight] + kTableExtraPadding + spacing;
            }
            tableSegIdx++;
        }
    }

    if (!isStreaming) {
        [segHeightCache setCache:@(totalHeight) forKey:cacheKey];
    }
    return totalHeight;
}

+(CGSize) textSize:(NSMutableAttributedString*)attrStr messageModel:(WKMessageModel*)model{
    CGFloat maxWidth = [WKApp shared].config.messageContentMaxWidth;

    if(model.streamOn && model.streamFlag!=WKStreamFlagEnd) { // 流式消息不缓存
        return [[self class] measureTextViewSize:attrStr maxWidth:maxWidth];
    }

    NSString *key = [NSString stringWithFormat:@"%@-size",model.clientMsgNo];
    if(model.remoteExtra.contentEdit) {
        key = [NSString stringWithFormat:@"%@-size-edit-%lu",model.clientMsgNo,model.remoteExtra.editedAt];
    }
    static WKMemoryCache *memoryCache;
    if(!memoryCache) {
        memoryCache = [[WKMemoryCache alloc] init];
        memoryCache.maxCacheNum = 0; // 数值缓存，内存极小，不设上限
    }
    NSString  *sizeStr =  [memoryCache getCache:key];
    if(sizeStr) {
        return CGSizeFromString(sizeStr);
    }
    CGSize size = [[self class] measureTextViewSize:attrStr maxWidth:maxWidth];
    [memoryCache setCache:NSStringFromCGSize(size) forKey:key];
    return size;
}

/// 用 sharedMeasureTV 的 layoutManager 测量最后一行宽度（与 textSize: 使用同一排版引擎）
+ (CGFloat)measureLastLineWidth:(NSAttributedString *)attrStr maxWidth:(CGFloat)maxWidth {
    // 与 measureTextViewSize: 共用 sharedMeasureTV，同样需要串行到主线程，理由见 Bugly #9386 注释。
    if (![NSThread isMainThread]) {
        __block CGFloat width = 0;
        dispatch_sync(dispatch_get_main_queue(), ^{
            width = [[self class] measureLastLineWidth:attrStr maxWidth:maxWidth];
        });
        return width;
    }
    WKMessageTextView *tv = [[self class] sharedMeasureTV];
    // Bugly #9455 同源兜底：UIKit 测量异常时返回 0（时间戳不贴最后一行，不影响正确性，仅视觉上略松）。
    @try {
        tv.frame = CGRectMake(0, 0, maxWidth, 10000);
        tv.attributedText = attrStr;
        NSLayoutManager *lm = tv.layoutManager;
        NSTextContainer *tc = tv.textContainer;
        [lm ensureLayoutForTextContainer:tc];
        if (attrStr.length == 0) return 0;
        NSUInteger lastGlyphIdx = [lm glyphIndexForCharacterAtIndex:attrStr.length - 1];
        CGRect lastLineRect = [lm lineFragmentUsedRectForGlyphAtIndex:lastGlyphIdx effectiveRange:nil];
        return lastLineRect.size.width;
    } @catch (NSException *e) {
        NSLog(@"[BubbleHeight] measureLastLineWidth exception, fallback=0: name=%@ reason=%@",
              e.name, e.reason);
        return 0;
    }
}

+(CGFloat) textLastlineWidth:(NSMutableAttributedString*)attrStr messageModel:(WKMessageModel*)model{
    CGFloat maxWidth = [WKApp shared].config.messageContentMaxWidth;

    if(model.streamOn && model.streamFlag!=WKStreamFlagEnd) { // 流式消息不缓存
        return [[self class] measureLastLineWidth:attrStr maxWidth:maxWidth];
    }

    NSString *key = [NSString stringWithFormat:@"%@-lastLine",model.clientMsgNo];
    if(model.remoteExtra.contentEdit) {
        key = [NSString stringWithFormat:@"%@-lastLine-edit-%lu",model.clientMsgNo,model.remoteExtra.editedAt];
    }
    static WKMemoryCache *memoryCache;
    if(!memoryCache) {
        memoryCache = [[WKMemoryCache alloc] init];
        memoryCache.maxCacheNum = 0; // 数值缓存，内存极小，不设上限
    }
    NSNumber  *lastLineWidth =  [memoryCache getCache:key];
    if(lastLineWidth) {
        return lastLineWidth.floatValue;
    }
    CGFloat lastLineWidthF = [[self class] measureLastLineWidth:attrStr maxWidth:maxWidth];
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

    // 检测链接卡片
    NSString *rawText = [[self class] getRawContent:model];
    if ([rawText hasPrefix:@"[链接]"]) {
        [self showLinkCard:rawText model:model];
        return;
    }
    // 非链接卡片：隐藏卡片视图，正常渲染文本
    self.linkCardView.hidden = YES;
    self.isLinkCard = NO;
    self.textLbl.hidden = NO;

    NSMutableAttributedString *attrStr = [[self class] parseAndCacheTextMessage:model];

    if(model.isSend) {
        attrStr.textColor =  [WKApp shared].config.messageSendTextColor;
        // 紫色气泡上用偏青的亮蓝色，避免蓝紫混淆看不清
        attrStr.linkColor = [UIColor colorWithRed:168.0f/255.0f green:222.0f/255.0f blue:255.0f/255.0f alpha:1.0f]; // #A8DEFF
    }else {
        attrStr.textColor = [WKApp shared].config.messageRecvTextColor;
        attrStr.linkColor = [UIColor colorWithRed:89.0f/255.0f green:121.0f/255.0f blue:240.0f/255.0f alpha:1.0f]; // #5979F0
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
        // --- 诊断日志 ---
        {
            CGSize ts = self.textLbl.lim_size;
            CGFloat fitH = [self.textLbl sizeThatFits:CGSizeMake(ts.width, CGFLOAT_MAX)].height;
            if (fitH > ts.height + 1.0) {
                NSLog(@"[BubbleHeight] ⚠️ refresh溢出: msgNo=%@ lim_size=(%.1f,%.1f) fitH=%.1f Δ=%.1f textLbl.frame.w=%.1f",
                      model.clientMsgNo, ts.width, ts.height, fitH, fitH - ts.height, self.textLbl.frame.size.width);
            }
        }
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
            NSString *colorHex = [textColor toHexRGB];
            BOOL firstTextUsed = NO;
            for (NSDictionary *seg in segments) {
                NSString *type = seg[@"type"];
                NSString *content = seg[@"content"];
                if ([type isEqualToString:@"text"]) {
                    // LaTeX 预处理：与 getContentAttrStr: 主路径同源逻辑。
                    NSArray<WKLaTeXMathSegment*> *segMathSegments = nil;
                    if ([WKLaTeXPreprocessor containsLaTeX:content]) {
                        @try {
                            WKLaTeXPreprocessResult *pp = [WKLaTeXPreprocessor preprocess:content];
                            content = pp.markdown;
                            segMathSegments = pp.mathSegments;
                        } @catch (NSException *e) {
                            NSLog(@"[LaTeXPreprocessor] table seg exception: %@", e);
                        }
                    }
                    // 统一用 WKMarkdownRenderer 渲染文本段（和 getContentAttrStr: 同一套逻辑，确保高度一致）
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
                    if (segMathSegments != nil || [WKMarkdownRenderer containsMarkdown:content]) {
                        NSAttributedString *mdAttr = nil;
                        @try {
                            mdAttr = [WKMarkdownRenderer render:content fontSize:[WKApp shared].config.messageTextFontSize textColorHex:colorHex dynamicTextColor:textColor];
                        } @catch (NSException *e) { mdAttr = nil; }
                        if (mdAttr) {
                            NSMutableAttributedString *mutable = [[NSMutableAttributedString alloc] initWithAttributedString:mdAttr];
                            if (segMathSegments.count > 0) {
                                BOOL isDark = [WKApp shared].config.style == WKSystemStyleDark;
                                [WKLaTeXPreprocessor replaceMathPlaceholdersIn:mutable
                                                                     segments:segMathSegments
                                                                     fontSize:[WKApp shared].config.messageTextFontSize
                                                                       isDark:isDark];
                            }
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
                            UIColor *segLinkColor = model.isSend
                                ? [UIColor colorWithRed:168.0f/255.0f green:222.0f/255.0f blue:255.0f/255.0f alpha:1.0f]  // #A8DEFF
                                : [UIColor colorWithRed:89.0f/255.0f green:121.0f/255.0f blue:240.0f/255.0f alpha:1.0f]; // #5979F0
                            [mutable enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, mutable.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
                                if (value) {
                                    [mutable removeAttribute:NSLinkAttributeName range:range];
                                    [mutable addAttribute:NSForegroundColorAttributeName value:segLinkColor range:range];
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
                                    [mutable addAttribute:NSForegroundColorAttributeName value:segLinkColor range:autoToken.range];
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
                        plainAttr.linkColor = model.isSend
                            ? [UIColor colorWithRed:168.0f/255.0f green:222.0f/255.0f blue:255.0f/255.0f alpha:1.0f]  // #A8DEFF
                            : [UIColor colorWithRed:89.0f/255.0f green:121.0f/255.0f blue:240.0f/255.0f alpha:1.0f]; // #5979F0
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
                    container.tag = (NSInteger)(kTableToolbarHeight + rowCount * [[self class] tableRowHeight] + kTableExtraPadding);

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

    // 超长文本：显示"查看全文"按钮（样式参考 bot 审批按钮）
    if ([[self class] isLongText:model]) {
        if (!self.viewFullTextBtn) {
            self.viewFullTextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            [self.viewFullTextBtn setTitle:LLang(@"查看全文") forState:UIControlStateNormal];
            [self.viewFullTextBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
            self.viewFullTextBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
            self.viewFullTextBtn.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.1];
            self.viewFullTextBtn.layer.cornerRadius = 4.0f;
            self.viewFullTextBtn.layer.masksToBounds = YES;
            [self.messageContentView addSubview:self.viewFullTextBtn];
        }
        self.viewFullTextBtn.hidden = NO;
    } else {
        self.viewFullTextBtn.hidden = YES;
    }

    self.replyBox.hidden = YES;
    if([[self class] hasReply:model]) {
        self.replyBox.hidden = NO;
        // · 消息气泡内的引用预览追加 @SpaceName —— 对齐 web PR #1073 / Android ReplyExternalFieldsHelper
        NSString *baseName = model.content.reply.fromName.length > 0
            ? model.content.reply.fromName : LLang(@"未知用户");
        NSString *viewerSpaceId = [WKExternalViewerResolver currentViewerSpaceId];
        WKExternalResolveResult *res = [WKExternalViewerResolver
            resolveWithHomeSpaceId:model.content.reply.fromHomeSpaceId
                     homeSpaceName:model.content.reply.fromHomeSpaceName
                  isExternalLegacy:@(model.content.reply.fromIsExternal ? 1 : 0)
             sourceSpaceNameLegacy:model.content.reply.fromSourceSpaceName
                     viewerSpaceId:viewerSpaceId];
        if (res.isExternal && res.sourceSpaceName.length > 0) {
            // 硬约束：attributedText 设置时必须先清 .text，避免 UIKit 互斥坑
            self.replyNameLbl.text = nil;
            self.replyNameLbl.attributedText = [self buildReplyNameAttrWithBase:baseName spaceName:res.sourceSpaceName];
        } else {
            self.replyNameLbl.attributedText = nil;
            self.replyNameLbl.text = baseName;
        }
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
    // 链接卡片点击：打开 URL
    if (self.isLinkCard && self.linkCardView && !self.linkCardView.hidden) {
        NSString *url = objc_getAssociatedObject(self.linkCardView, "linkURL");
        if (url.length > 0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
        }
        return;
    }
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
    // "查看全文"按钮点击检测
    if (self.viewFullTextBtn && !self.viewFullTextBtn.hidden) {
        CGPoint pointInContent = [self.messageContentView convertPoint:gesture.tapPoint fromView:self.contentView];
        if (CGRectContainsPoint(self.viewFullTextBtn.frame, pointInContent)) {
            [self viewFullTextTapped];
            return;
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
        if (![v isKindOfClass:[UILabel class]] && ![v isKindOfClass:[UITextView class]]) continue;
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
    if ([self wk_isInSelectionMode]) return NO;
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
    // 选区模式且临时切换为全文本时，跳过分段布局重算（保持手动设置的尺寸）
    BOOL selHadSegments = [objc_getAssociatedObject(self, "kSelHadSegments") boolValue];
    if (selHadSegments && [self wk_isInSelectionMode]) {
        NSLog(@"[SelDebug] layoutSubviews SKIPPED (selection mode). bubble=%@ textLbl=%@ cell=%@",
              NSStringFromCGSize(self.bubbleBackgroundView.lim_size),
              NSStringFromCGSize(self.textLbl.lim_size),
              NSStringFromCGSize(self.frame.size));
        struct objc_super superSuper = { self, [UITableViewCell class] };
        ((void(*)(struct objc_super*, SEL))objc_msgSendSuper)(&superSuper, @selector(layoutSubviews));
        return;
    }

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
        // 引用块：背景色随发送/接收方向调整
        if (self.messageModel.isSend) {
            self.replyBox.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.18f];
        } else {
            self.replyBox.backgroundColor = [UIColor colorWithRed:0.93f green:0.93f blue:0.95f alpha:1.0f];
        }

        CGFloat replyRow1H = MAX(replyAvatarSize, replyNameSize.height);
        CGFloat replyBoxH  = replyBoxPadV + replyRow1H + replyItemSpacing + replyContentSize.height + replyBoxPadV;

        self.replyBox.lim_top = !self.nameLbl.hidden ? replyToNameSpace : 0.0f;
        self.replyBox.lim_width = self.messageContentView.lim_width;
        self.replyBox.lim_height = replyBoxH;

        // 左侧彩色竖线
        self.splitView.lim_left = 0.0f;
        self.splitView.lim_top = 0.0f;
        self.splitView.lim_width = splitWidth;
        self.splitView.lim_height = replyBoxH;

        // 头像（22×22）
        CGFloat contentLeft = splitWidth + replyBoxPadH;
        self.replyAvatarIcon.lim_left = contentLeft;
        self.replyAvatarIcon.lim_top = replyBoxPadV + (replyRow1H - replyAvatarSize) / 2.0f;
        self.replyAvatarIcon.lim_width = replyAvatarSize;
        self.replyAvatarIcon.lim_height = replyAvatarSize;

        // 名字（右侧紧邻头像）：给满可用宽度，由 label 的 lineBreakMode 决定是否截断
        CGFloat nameLeft = contentLeft + replyAvatarSize + 4.0f;
        CGFloat nameMaxW = self.replyBox.lim_width - nameLeft - replyBoxPadH;
        self.replyNameLbl.lim_left   = nameLeft;
        self.replyNameLbl.lim_top    = replyBoxPadV + (replyRow1H - replyNameSize.height) / 2.0f;
        self.replyNameLbl.lim_width  = MAX(0, nameMaxW);  // 全部可用宽度
        self.replyNameLbl.lim_height = replyNameSize.height;

        // 内容（第二行，与头像左对齐）：同理给满可用宽度
        CGFloat contentMaxW = self.replyBox.lim_width - contentLeft - replyBoxPadH;
        self.replyContentLbl.lim_left   = contentLeft;
        self.replyContentLbl.lim_top    = replyBoxPadV + replyRow1H + replyItemSpacing;
        self.replyContentLbl.lim_width  = MAX(0, contentMaxW);
        self.replyContentLbl.lim_height = replyContentSize.height;

        replyBoxBottom = self.replyBox.lim_bottom + textTopSpace;
    }
    
    self.textLbl.lim_left = 0.0f;
    self.textLbl.lim_top = replyBoxBottom;
    // 非分段模式：textLbl 渲染宽度必须 = 测量宽度（maxWidth），
    // lim_size.width 来自 usedRect（最宽行，可能 < maxWidth），
    // 但高度是在 maxWidth 下计算的，所以渲染宽度也必须用 messageContentView 宽度。
    if (self.segmentViews.count == 0) {
        CGFloat renderW = self.messageContentView.lim_width;
        if (renderW > self.textLbl.lim_width) {
            self.textLbl.lim_width = renderW;
        }
        // --- 诊断日志 ---
        {
            CGFloat fitH = [self.textLbl sizeThatFits:CGSizeMake(self.textLbl.lim_width, CGFLOAT_MAX)].height;
            if (fitH > self.textLbl.lim_height + 1.0) {
                NSLog(@"[BubbleHeight] ⚠️ layout溢出: textLbl=(%.1f,%.1f,%.1f,%.1f) fitH=%.1f Δ=%.1f contentView=(%.1f,%.1f)",
                      self.textLbl.lim_left, self.textLbl.lim_top, self.textLbl.lim_width, self.textLbl.lim_height,
                      fitH, fitH - self.textLbl.lim_height,
                      self.messageContentView.lim_width, self.messageContentView.lim_height);
            }
        }
    }
    // 分段布局：按顺序排列文本段和表格段
    if (self.segmentViews.count > 0) {
        CGFloat segTop = replyBoxBottom;
        NSInteger tableIdx = 0;
        CGFloat contentW = self.messageContentView.lim_width;
        for (NSUInteger i = 0; i < self.segmentViews.count; i++) {
            UIView *v = self.segmentViews[i];
            CGFloat spacing = (i < self.segmentViews.count - 1) ? kTableTopSpace : 0;
            if ([v isKindOfClass:[UILabel class]] || [v isKindOfClass:[UITextView class]]) {
                CGSize fitSize = [v sizeThatFits:CGSizeMake(contentW, CGFLOAT_MAX)];
                v.frame = CGRectMake(0, segTop, contentW, fitSize.height);
                segTop += fitSize.height + spacing;
            } else {
                // 表格容器布局（容器内含 toolbar + webview）
                CGFloat tableH = v.tag > 0 ? v.tag : (kTableToolbarHeight + [[self class] tableRowHeight] + kTableExtraPadding);
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

    // "查看全文"按钮布局
    if (self.viewFullTextBtn && !self.viewFullTextBtn.hidden) {
        CGFloat btnTop = self.textLbl.lim_top + self.textLbl.lim_size.height;
        if (self.segmentViews.count > 0) {
            UIView *lastSeg = self.segmentViews.lastObject;
            btnTop = CGRectGetMaxY(lastSeg.frame);
        }
        self.viewFullTextBtn.frame = CGRectMake(0, btnTop, self.messageContentView.lim_width, kViewFullTextBtnHeight);
    }

    self.securityTipLbl.hidden = YES;
    
   

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

    // 实名 ✓ 徽章 + Bot 标识：紧跟 nameLbl 右侧，realname → bot 串行。
    // 父类 layoutName 在 WKTextMessageCell 这里被完全覆写，必须在子类显式排
    // realnameVerifiedImgView，否则它会停留在 initUI 时的 (0,0,12,12) 旧 frame
    // —— 表现为「徽章卡在气泡左上角」（P1-1 同型坑）。
    CGFloat afterNameRight = self.nameLbl.lim_left + self.nameLbl.lim_width;
    if (!self.realnameVerifiedImgView.hidden) {
        self.realnameVerifiedImgView.lim_width = 12.0f;
        self.realnameVerifiedImgView.lim_height = 12.0f;
        self.realnameVerifiedImgView.lim_left = afterNameRight + 6.0f;
        self.realnameVerifiedImgView.lim_top = self.nameLbl.lim_top + (self.nameLbl.lim_height - self.realnameVerifiedImgView.lim_height) / 2.0f;
        afterNameRight = self.realnameVerifiedImgView.lim_left + self.realnameVerifiedImgView.lim_width;
    }
    self.botBadgeLbl.lim_left = afterNameRight + 6.0f;
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
        _replyBox.layer.cornerRadius = 6.0f;
        _replyBox.clipsToBounds = YES;
    }
    return _replyBox;
}

-(void) replyBoxTap {
    if(!self.messageModel.content.reply || self.messageModel.content.reply.messageSeq == 0) {
        return;
    }
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
        _splitView.backgroundColor = [WKApp shared].config.themeColor;
        // 不再隐藏：作为左侧彩色竖线显示（原设计是 hidden=YES 且 width=0）
    }
    return _splitView;
}

- (UILabel *)replyNameLbl {
    if(!_replyNameLbl) {
        _replyNameLbl = [[UILabel alloc] init];
        _replyNameLbl.font = [[WKApp shared].config appFontOfSize:replyNameFontSize];
        _replyNameLbl.numberOfLines = 1;
        _replyNameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _replyNameLbl;
}

// · 拼接「发送者名 + 灰色 @SpaceName 后缀」的 NSAttributedString。
// 样式对齐 WKMemberCell v2（）：基名用 isSend-aware 主色，@Space 用浅灰 + 更小字号。
// 传入 baseColor 而不是读 replyNameLbl.textColor —— 调用方在 build 之后才 set textColor，
// 这里直接计算最终色以避免依赖顺序。
- (NSAttributedString *)buildReplyNameAttrWithBase:(NSString *)baseName
                                         spaceName:(NSString *)spaceName {
    UIColor *baseColor = [self.messageModel isSend]
        ? [WKApp shared].config.messageTipColor
        : [WKApp shared].config.tipColor;
    if (!baseColor) { baseColor = [UIColor darkGrayColor]; }
    UIFont *baseFont = self.replyNameLbl.font
        ?: [[WKApp shared].config appFontOfSize:replyNameFontSize];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc]
        initWithString:(baseName ?: @"")
            attributes:@{NSFontAttributeName: baseFont,
                         NSForegroundColorAttributeName: baseColor}];
    UIColor *suffixColor = [UIColor colorWithRed:153.0f/255.0f
                                           green:153.0f/255.0f
                                            blue:153.0f/255.0f
                                           alpha:1.0f];
    UIFont *suffixFont = [[WKApp shared].config appFontOfSize:replyNameFontSize - 1.0f];
    NSString *suffix = [NSString stringWithFormat:@" @%@", spaceName ?: @""];
    [attr appendAttributedString:[[NSAttributedString alloc]
        initWithString:suffix
            attributes:@{NSFontAttributeName: suffixFont,
                         NSForegroundColorAttributeName: suffixColor}]];
    return attr;
}

- (UILabel *)replyContentLbl {
    if(!_replyContentLbl) {
        _replyContentLbl = [[UILabel alloc] init];
        _replyContentLbl.font = [[WKApp shared].config appFontOfSize:replyContentFontSize];
        _replyContentLbl.numberOfLines = 1;
        _replyContentLbl.lineBreakMode = NSLineBreakByTruncatingTail;
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
    // 可用宽度 = 最大宽度 - 竖线 - 左右内边距 - 头像 - 头像右间距
    CGFloat maxW = [WKApp shared].config.messageContentMaxWidth
        - splitWidth - replyBoxPadH - replyAvatarSize - 4.0f - replyBoxPadH;
    NSString *name = message.content.reply.fromName;
    if (!name.length) name = LLang(@"未知用户");  // 与 refreshModel: 显示值一致
    return [self getTextSize:name maxWidth:maxW fontSize:replyNameFontSize];
}

+(CGSize) getReplyContentSize:(WKMessageModel *)message {
    // 可用宽度 = 最大宽度 - 竖线 - 左右内边距
    CGFloat maxW = [WKApp shared].config.messageContentMaxWidth
        - splitWidth - replyBoxPadH * 2;
    return [self getTextSize:[message.content.reply.content conversationDigest] maxWidth:maxW fontSize:replyContentFontSize];
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
    // Skip broadcast sentinel UIDs — these are not real users
    if ([atUID isEqualToString:@"all"] || [atUID isEqualToString:@"__ais__"]) {
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

-(void) webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    NSString *scheme = url.scheme.lowercaseString;
    // 拦截所有 http/https 导航（包括 JS window.location.href 触发的），用系统浏览器打开
    // about:blank 是 loadHTMLString 的初始加载，需要放行
    if (url && ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"])) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

-(void) webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSUInteger idx = [self.tableWebViews indexOfObject:webView];
    if (idx == NSNotFound) return;

    NSString *js = @"JSON.stringify({w:Math.max(document.body.scrollWidth,document.documentElement.scrollWidth),h:Math.max(document.body.scrollHeight,document.documentElement.scrollHeight)})";
    [webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (!result || error) return;
        NSData *data = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dims = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!dims) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            CGFloat contentWidth  = [dims[@"w"] floatValue];
            CGFloat contentHeight = [dims[@"h"] floatValue];

            // 水平滚动 overlay
            if (idx < self.tableOverlays.count) {
                UIScrollView *overlay = self.tableOverlays[idx];
                if (contentWidth > overlay.frame.size.width && overlay.frame.size.width > 0) {
                    overlay.contentSize = CGSizeMake(contentWidth, overlay.frame.size.height);
                }
            }

            // 动态高度修正：用 JS 实际高度替换公式估算
            UIView *container = webView.superview;
            if (!container || !self.messageModel) return;
            CGFloat actualContainerH = kTableToolbarHeight + ceil(contentHeight);
            CGFloat currentH = (CGFloat)container.tag;
            if (fabs(actualContainerH - currentH) < 2.0) return; // 误差 <2px 无需修正

            container.tag = (NSInteger)actualContainerH;
            NSString *jsKey = [NSString stringWithFormat:@"%@-%lu", self.messageModel.clientMsgNo, (unsigned long)idx];
            [[WKTextMessageCell jsTableHeights] setObject:@(actualContainerH) forKey:jsKey];

            // 清除分段高度缓存（让 segmentedContentHeightForMessage: 使用 JS 实际高度重新计算）
            NSString *modeTag = ([WKApp shared].config.style == WKSystemStyleDark) ? @"d" : @"l";
            NSString *cacheKey = [NSString stringWithFormat:@"%@-segH-%@", self.messageModel.clientMsgNo, modeTag];
            [[[self class] segHeightCache] setCache:nil forKey:cacheKey];

            // 触发 UITableView 重新计算 cell 高度
            UIView *v = self.superview;
            while (v && ![v isKindOfClass:[UITableView class]]) v = v.superview;
            if ([v isKindOfClass:[UITableView class]]) {
                UITableView *tv = (UITableView *)v;
                [tv beginUpdates];
                [tv endUpdates];
            }
        });
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

#pragma mark - Link Card

- (void)showLinkCard:(NSString *)rawText model:(WKMessageModel *)model {
    self.isLinkCard = YES;
    // 彻底隐藏所有可能残留的子视图
    self.textLbl.hidden = YES;
    self.textLbl.text = nil;
    self.textLbl.attributedText = nil;
    self.textLbl.lim_size = CGSizeZero;
    for (UIView *seg in self.segmentViews) seg.hidden = YES;
    self.replyBox.hidden = YES;
    self.botActionView.hidden = YES;
    self.securityTipLbl.hidden = YES;
    // 隐藏 messageContentView 上所有非 linkCardView 的子视图
    for (UIView *sub in self.messageContentView.subviews) {
        if (sub != self.linkCardView) sub.hidden = YES;
    }

    // 解析 JSON
    NSString *jsonStr = [rawText substringFromIndex:@"[链接]".length];
    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *cardData = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    NSString *title = cardData[@"title"] ?: @"";
    NSString *url = cardData[@"url"] ?: @"";
    NSString *iconURL = cardData[@"icon"] ?: @"";

    // 创建或复用卡片视图
    if (!self.linkCardView) {
        self.linkCardView = [[UIView alloc] init];
        [self.messageContentView addSubview:self.linkCardView];
    }
    self.linkCardView.hidden = NO;

    // 清除旧的子视图
    for (UIView *sub in self.linkCardView.subviews) [sub removeFromSuperview];

    CGFloat cardW = 220;
    CGFloat cardH = 70;
    self.linkCardView.frame = CGRectMake(0, 0, cardW, cardH);

    // favicon（右侧）
    CGFloat iconSize = 32;
    UIImageView *faviconView = [[UIImageView alloc] initWithFrame:CGRectMake(cardW - iconSize - 10, (cardH - iconSize) / 2, iconSize, iconSize)];
    faviconView.contentMode = UIViewContentModeScaleAspectFit;
    faviconView.layer.cornerRadius = 4;
    faviconView.layer.masksToBounds = YES;
    faviconView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.1];
    // 默认链接图标（程序化绘制地球图标）
    faviconView.image = [[self class] defaultLinkIcon];
    [self.linkCardView addSubview:faviconView];

    // 异步加载 favicon
    if (iconURL.length > 0) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:iconURL]];
            if (data) {
                UIImage *icon = [UIImage imageWithData:data];
                if (icon) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        faviconView.image = icon;
                    });
                }
            }
        });
    }

    // 标题
    CGFloat textW = cardW - iconSize - 24;
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 10, textW, 22)];
    titleLbl.text = title.length > 0 ? title : url;
    titleLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    titleLbl.textColor = model.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.defaultTextColor;
    titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.linkCardView addSubview:titleLbl];

    // URL（截断显示域名）
    NSURL *parsedURL = [NSURL URLWithString:url];
    NSString *displayURL = parsedURL.host ?: url;
    UILabel *urlLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 34, textW, 16)];
    urlLbl.text = displayURL;
    urlLbl.font = [UIFont systemFontOfSize:11];
    urlLbl.textColor = model.isSend ? [[UIColor whiteColor] colorWithAlphaComponent:0.7] : [UIColor grayColor];
    urlLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.linkCardView addSubview:urlLbl];

    // 底部分隔线
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(8, cardH - 20, cardW - 16, 0.5)];
    sep.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
    [self.linkCardView addSubview:sep];

    // "网页" 标签
    UILabel *webLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, cardH - 18, 60, 16)];
    webLabel.text = LLang(@"网页");
    webLabel.font = [UIFont systemFontOfSize:10];
    webLabel.textColor = model.isSend ? [[UIColor whiteColor] colorWithAlphaComponent:0.5] : [UIColor lightGrayColor];
    [self.linkCardView addSubview:webLabel];

    // 存储 URL 供点击使用
    objc_setAssociatedObject(self.linkCardView, "linkURL", url, OBJC_ASSOCIATION_COPY_NONATOMIC);

    // 更新 messageContentView 大小
    self.messageContentView.frame = CGRectMake(self.messageContentView.frame.origin.x,
                                                self.messageContentView.frame.origin.y,
                                                cardW, cardH);
}

+ (UIImage *)defaultLinkIcon {
    CGSize s = CGSizeMake(32, 32);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;
    // 灰色地球图标
    UIColor *color = [UIColor colorWithWhite:0.65 alpha:1.0];
    [color setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    // 圆
    CGContextAddEllipseInRect(ctx, CGRectMake(4, 4, 24, 24));
    CGContextStrokePath(ctx);
    // 横线
    CGContextMoveToPoint(ctx, 4, 16);
    CGContextAddLineToPoint(ctx, 28, 16);
    CGContextStrokePath(ctx);
    // 竖椭圆
    CGContextAddEllipseInRect(ctx, CGRectMake(11, 4, 10, 24));
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - 气泡内文字选择（自定义句柄，参考 Android SelectTextHelper）

// ── 选区状态 associated object keys ──

static const char kSelectionMenusKey   = 0;
static const char kSelectionVisibleKey = 1;
static const char kSelStartHandleKey   = 2;
static const char kSelEndHandleKey     = 3;
static const char kSelOrigAttrTextKey  = 4;
static const char kSelRangeLocKey      = 5;
static const char kSelRangeLenKey      = 6;
static const char kSelWindowTapKey     = 7;
static const char kSelNavKey           = 8;
static const char kSelTimerKey         = 9;
static const char kSelTableViewKey     = 10;
static void *kSelScrollKVOCtx          = &kSelScrollKVOCtx;

// 判断是否处于选区模式
-(BOOL) wk_isInSelectionMode {
    return objc_getAssociatedObject(self, &kSelStartHandleKey) != nil;
}

-(void) startInBubbleTextSelectionWithMenuItems:(NSArray*)menuItems {
    if ([self wk_isInSelectionMode]) return;

    self.transform = CGAffineTransformIdentity;

    // 含表格的分段消息：临时切换为纯文本模式
    BOOL hasSegments = self.segmentsBuilt && self.segmentViews.count > 1;
    if (hasSegments) {
        NSString *fullRawText = [[self class] getRawContent:self.messageModel];
        if (fullRawText.length > 0) {
            objc_setAssociatedObject(self, "kSelHadSegments", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, "kSelOrigSegAttrText", [self.textLbl.attributedText copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, "kSelOrigSegSize", [NSValue valueWithCGSize:self.textLbl.lim_size], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            // 隐藏分段视图
            for (UIView *v in self.segmentViews) {
                if (v != self.textLbl) v.hidden = YES;
            }
            for (UIScrollView *o in self.tableOverlays) { o.hidden = YES; }

            // 用完整文本替换 textLbl
            self.textLbl.attributedText = nil;
            self.textLbl.text = fullRawText;
            self.textLbl.font = [[WKApp shared].config appFontOfSize:[WKApp shared].config.messageTextFontSize];
            self.textLbl.textColor = self.messageModel.isSend ? [WKApp shared].config.messageSendTextColor : [WKApp shared].config.messageRecvTextColor;
            self.textLbl.hidden = NO;
            CGSize fullSize = [self.textLbl sizeThatFits:CGSizeMake([WKApp shared].config.messageContentMaxWidth, CGFLOAT_MAX)];
            self.textLbl.lim_size = fullSize;

            // 构建与 heightForRowAtIndexPath 一致的缓存 key
            NSInteger bubblePos = [[self class] bubblePosition:self.messageModel];
            NSString *heightKey = [NSString stringWithFormat:@"%@-bp%ld", self.messageModel.clientMsgNo, (long)bubblePos];
            if (self.messageModel.remoteExtra.contentEdit) {
                heightKey = [NSString stringWithFormat:@"%@-e%lu", heightKey, (unsigned long)self.messageModel.remoteExtra.editedAt];
            }

            UIEdgeInsets contentInsets = [[self class] contentEdgeInsets:self.messageModel];
            UIEdgeInsets bubbleInsets = [[self class] bubbleEdgeInsets:self.messageModel contentSize:fullSize];
            CGFloat newCellHeight = fullSize.height + contentInsets.top + contentInsets.bottom + bubbleInsets.top + bubbleInsets.bottom;

            NSNumber *origH = [[WKMessageListView cellHeightCache] objectForKey:heightKey];
            NSLog(@"[SelDebug] key=%@ origHeight=%@ newHeight=%.1f", heightKey, origH, newCellHeight);
            objc_setAssociatedObject(self, "kSelOrigHeight", origH, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, "kSelHeightKey", heightKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [[WKMessageListView cellHeightCache] setObject:@(newCellHeight) forKey:heightKey];

            // 更新气泡大小
            self.messageContentView.lim_size = fullSize;
            self.bubbleBackgroundView.lim_size = CGSizeMake(
                fullSize.width + contentInsets.left + contentInsets.right,
                fullSize.height + contentInsets.top + contentInsets.bottom
            );

            NSLog(@"[SelDebug] BEFORE tableView update: cell.frame=%@ bubble=%@ contentView=%@ textLbl=%@",
                  NSStringFromCGRect(self.frame),
                  NSStringFromCGSize(self.bubbleBackgroundView.lim_size),
                  NSStringFromCGSize(self.messageContentView.lim_size),
                  NSStringFromCGSize(self.textLbl.lim_size));

            // wk_isInSelectionMode 此时还未设置（后面才设置 kSelRangeLocKey），
            // 所以需要提前设置标记让 layoutSubviews 跳过重算
            // kSelHadSegments 已设置，但 wk_isInSelectionMode 依赖 kSelRangeLocKey
            // → 先设置 kSelRangeLocKey/kSelRangeLenKey，让 wk_isInSelectionMode 返回 YES
            NSUInteger textLen = self.textLbl.text.length;
            objc_setAssociatedObject(self, &kSelRangeLocKey, @0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, &kSelRangeLenKey, @(textLen), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            // 触发 tableView 更新高度
            UIView *v = self.superview;
            while (v && ![v isKindOfClass:[UITableView class]]) v = v.superview;
            if ([v isKindOfClass:[UITableView class]]) {
                UITableView *tv = (UITableView *)v;
                [UIView performWithoutAnimation:^{
                    [tv beginUpdates];
                    [tv endUpdates];
                }];

                // beginUpdates/endUpdates 期间 layoutSubviews 可能被触发并覆盖气泡大小
                // 重新强制设置正确的尺寸
                self.textLbl.lim_size = fullSize;
                self.messageContentView.lim_size = fullSize;
                self.bubbleBackgroundView.lim_size = CGSizeMake(
                    fullSize.width + contentInsets.left + contentInsets.right,
                    fullSize.height + contentInsets.top + contentInsets.bottom
                );

                NSLog(@"[SelDebug] AFTER fix: cell.frame=%@ bubble=%@ contentView=%@ textLbl=%@",
                      NSStringFromCGRect(self.frame),
                      NSStringFromCGSize(self.bubbleBackgroundView.lim_size),
                      NSStringFromCGSize(self.messageContentView.lim_size),
                      NSStringFromCGSize(self.textLbl.lim_size));
            } else {
                NSLog(@"[SelDebug] ERROR: tableView not found in superview chain");
            }
        }
    }

    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    CGFloat bottomMargin = 80.0f + window.safeAreaInsets.bottom;
    CGRect visibleArea = CGRectMake(0, window.safeAreaInsets.top, window.frame.size.width,
                                    window.frame.size.height - window.safeAreaInsets.top - bottomMargin);
    CGRect tvInWindow = [self.textLbl convertRect:self.textLbl.bounds toView:nil];
    CGRect visibleFrame = CGRectIntersection(tvInWindow, visibleArea);
    if (CGRectIsNull(visibleFrame) || visibleFrame.size.height < 4) return;

    // 保存状态
    objc_setAssociatedObject(self, &kSelectionMenusKey, menuItems ?: @[], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kSelectionVisibleKey, [NSValue valueWithCGRect:visibleFrame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 保存原始 attributedText
    objc_setAssociatedObject(self, &kSelOrigAttrTextKey, [self.textLbl.attributedText copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 全选范围（分段模式已提前设置，非分段模式在这里设置）
    if (!hasSegments) {
        NSUInteger textLen = self.textLbl.text.length;
        objc_setAssociatedObject(self, &kSelRangeLocKey, @0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kSelRangeLenKey, @(textLen), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSUInteger textLen = self.textLbl.text.length;

    // 应用高亮
    [self wk_applyHighlightForRange:NSMakeRange(0, textLen)];

    // 创建句柄加到 window
    __weak typeof(self) weakSelf = self;
    WKSelectionHandle *startHandle = [[WKSelectionHandle alloc] initWithStart:YES];
    WKSelectionHandle *endHandle = [[WKSelectionHandle alloc] initWithStart:NO];

    startHandle.onDrag = ^(CGPoint windowPt) { [weakSelf wk_handleDrag:YES point:windowPt]; };
    startHandle.onDragEnd = ^{ [weakSelf wk_handleDragEnd]; };
    endHandle.onDrag = ^(CGPoint windowPt) { [weakSelf wk_handleDrag:NO point:windowPt]; };
    endHandle.onDragEnd = ^{ [weakSelf wk_handleDragEnd]; };

    [window addSubview:startHandle];
    [window addSubview:endHandle];
    objc_setAssociatedObject(self, &kSelStartHandleKey, startHandle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kSelEndHandleKey, endHandle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 定位句柄
    [self wk_updateHandlePositions];

    // KVO 监听 tableView 滚动，实时更新句柄位置
    UIView *v = self.superview;
    while (v && ![v isKindOfClass:[UITableView class]]) v = v.superview;
    if ([v isKindOfClass:[UITableView class]]) {
        [v addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:kSelScrollKVOCtx];
        objc_setAssociatedObject(self, &kSelTableViewKey, v, OBJC_ASSOCIATION_ASSIGN);
    }

    // 禁用导航滑动返回
    UIResponder *responder = self;
    while (responder) {
        if ([responder isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)responder;
            for (UIGestureRecognizer *gr in nav.view.gestureRecognizers) {
                if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) gr.enabled = NO;
            }
            objc_setAssociatedObject(self, &kSelNavKey, nav, OBJC_ASSOCIATION_ASSIGN);
            break;
        }
        responder = [responder nextResponder];
    }

    // window tap（点击气泡外 dismiss）
    UITapGestureRecognizer *windowTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(wk_selectionWindowTap:)];
    windowTap.cancelsTouchesInView = NO;
    windowTap.delegate = self;
    [window addGestureRecognizer:windowTap];
    objc_setAssociatedObject(self, &kSelWindowTapKey, windowTap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 通知监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wk_keyboardDismissSelection:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wk_viewDisappearDismissSelection:) name:@"WKConversationViewWillDisappear" object:nil];

    // 显示菜单
    [self wk_showSelectionMenuForRange:NSMakeRange(0, textLen) isAll:YES];
}

-(void) endInBubbleTextSelection {
    if (![self wk_isInSelectionMode]) return;

    // 移除句柄
    WKSelectionHandle *sh = objc_getAssociatedObject(self, &kSelStartHandleKey);
    WKSelectionHandle *eh = objc_getAssociatedObject(self, &kSelEndHandleKey);
    [sh removeFromSuperview];
    [eh removeFromSuperview];
    objc_setAssociatedObject(self, &kSelStartHandleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kSelEndHandleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 恢复原始 attributedText（去除高亮）
    NSAttributedString *orig = objc_getAssociatedObject(self, &kSelOrigAttrTextKey);
    if (orig) self.textLbl.attributedText = orig;
    objc_setAssociatedObject(self, &kSelOrigAttrTextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 移除 window tap
    UITapGestureRecognizer *tap = objc_getAssociatedObject(self, &kSelWindowTapKey);
    if (tap) { [tap.view removeGestureRecognizer:tap]; }
    objc_setAssociatedObject(self, &kSelWindowTapKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 移除 KVO
    UIView *tv = objc_getAssociatedObject(self, &kSelTableViewKey);
    if (tv) {
        @try { [tv removeObserver:self forKeyPath:@"contentOffset" context:kSelScrollKVOCtx]; } @catch (...) {}
        objc_setAssociatedObject(self, &kSelTableViewKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }

    // 恢复导航手势
    UINavigationController *nav = objc_getAssociatedObject(self, &kSelNavKey);
    if (nav) {
        for (UIGestureRecognizer *gr in nav.view.gestureRecognizers) {
            if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) gr.enabled = YES;
        }
        objc_setAssociatedObject(self, &kSelNavKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }

    // 取消 timer
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(wk_reshowMenuAfterScroll) object:nil];
    dispatch_block_t t = objc_getAssociatedObject(self, &kSelTimerKey);
    if (t) { dispatch_block_cancel(t); }
    objc_setAssociatedObject(self, &kSelTimerKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);

    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"WKConversationViewWillDisappear" object:nil];

    // 隐藏菜单
    [self wk_hideSelectionPopup];

    // 恢复系统编辑菜单（自定义选区可能污染了全局 UIMenuController 状态）
    [UIMenuController sharedMenuController].menuItems = nil;

    objc_setAssociatedObject(self, &kSelectionMenusKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kSelectionVisibleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kSelRangeLocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kSelRangeLenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 恢复分段视图和高度
    BOOL hadSegments = [objc_getAssociatedObject(self, "kSelHadSegments") boolValue];
    if (hadSegments) {
        // 恢复 textLbl 原始内容和大小
        NSAttributedString *origAttr = objc_getAssociatedObject(self, "kSelOrigSegAttrText");
        if (origAttr) self.textLbl.attributedText = origAttr;
        NSValue *origSizeVal = objc_getAssociatedObject(self, "kSelOrigSegSize");
        if (origSizeVal) self.textLbl.lim_size = [origSizeVal CGSizeValue];

        // 显示分段视图
        for (UIView *v in self.segmentViews) { v.hidden = NO; }
        for (UIScrollView *o in self.tableOverlays) { o.hidden = NO; }

        // 恢复高度缓存（用保存的完整 key）
        NSString *heightKey = objc_getAssociatedObject(self, "kSelHeightKey");
        NSNumber *origHeight = objc_getAssociatedObject(self, "kSelOrigHeight");
        if (heightKey.length > 0 && origHeight) {
            [[WKMessageListView cellHeightCache] setObject:origHeight forKey:heightKey];
        }

        // 触发 tableView 恢复高度
        UIView *v = self.superview;
        while (v && ![v isKindOfClass:[UITableView class]]) v = v.superview;
        if ([v isKindOfClass:[UITableView class]]) {
            UITableView *tv = (UITableView *)v;
            [UIView performWithoutAnimation:^{
                [tv beginUpdates];
                [tv endUpdates];
            }];
        }

        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
    objc_setAssociatedObject(self, "kSelHadSegments", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "kSelOrigSegAttrText", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "kSelOrigSegSize", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "kSelOrigHeight", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "kSelHeightKey", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

#pragma mark - 自定义选区：高亮、句柄定位、拖拽

-(NSRange) wk_currentSelRange {
    NSUInteger loc = [objc_getAssociatedObject(self, &kSelRangeLocKey) unsignedIntegerValue];
    NSUInteger len = [objc_getAssociatedObject(self, &kSelRangeLenKey) unsignedIntegerValue];
    return NSMakeRange(loc, len);
}

-(void) wk_applyHighlightForRange:(NSRange)range {
    NSAttributedString *orig = objc_getAssociatedObject(self, &kSelOrigAttrTextKey);
    if (!orig) return;
    NSMutableAttributedString *highlighted = [orig mutableCopy];
    if (range.length > 0 && NSMaxRange(range) <= highlighted.length) {
        [highlighted addAttribute:NSBackgroundColorAttributeName
                            value:[[UIColor systemBlueColor] colorWithAlphaComponent:0.3]
                            range:range];
    }
    self.textLbl.attributedText = highlighted;
}

-(void) wk_updateHandlePositions {
    NSRange range = [self wk_currentSelRange];
    if (range.length == 0) return;

    NSLayoutManager *lm = self.textLbl.layoutManager;
    NSTextContainer *tc = self.textLbl.textContainer;
    [lm ensureLayoutForTextContainer:tc];

    // 起始句柄：选区首字符的左上角
    NSUInteger startGlyph = [lm glyphIndexForCharacterAtIndex:range.location];
    CGRect startRect = [lm boundingRectForGlyphRange:NSMakeRange(startGlyph, 1) inTextContainer:tc];
    CGPoint startPt = [self.textLbl convertPoint:CGPointMake(startRect.origin.x, startRect.origin.y) toView:nil];

    // 结束句柄：选区末字符的右下角
    NSUInteger endCharIdx = NSMaxRange(range) - 1;
    NSUInteger endGlyph = [lm glyphIndexForCharacterAtIndex:endCharIdx];
    CGRect endRect = [lm boundingRectForGlyphRange:NSMakeRange(endGlyph, 1) inTextContainer:tc];
    CGPoint endPt = [self.textLbl convertPoint:CGPointMake(CGRectGetMaxX(endRect), CGRectGetMaxY(endRect)) toView:nil];

    WKSelectionHandle *sh = objc_getAssociatedObject(self, &kSelStartHandleKey);
    WKSelectionHandle *eh = objc_getAssociatedObject(self, &kSelEndHandleKey);
    [sh positionAtWindowPoint:startPt];
    [eh positionAtWindowPoint:endPt];
}

-(void) wk_handleDrag:(BOOL)isStart point:(CGPoint)windowPt {
    [self wk_hideSelectionPopup];

    // 转换为 textLbl 本地坐标
    CGPoint local = [self.textLbl convertPoint:windowPt fromView:nil];
    local.x = MAX(0, MIN(local.x, self.textLbl.bounds.size.width));
    local.y = MAX(0, MIN(local.y, self.textLbl.bounds.size.height));

    NSLayoutManager *lm = self.textLbl.layoutManager;
    NSTextContainer *tc = self.textLbl.textContainer;
    CGFloat fraction = 0;
    NSUInteger idx = [lm characterIndexForPoint:local inTextContainer:tc
               fractionOfDistanceBetweenInsertionPoints:&fraction];
    if (idx == NSNotFound) return;

    NSRange cur = [self wk_currentSelRange];
    NSUInteger newStart = cur.location, newEnd = NSMaxRange(cur);

    if (isStart) {
        newStart = idx;
    } else {
        newEnd = idx + 1;
    }
    if (newEnd > self.textLbl.text.length) newEnd = self.textLbl.text.length;
    if (newStart >= newEnd) {
        if (isStart) newStart = newEnd > 0 ? newEnd - 1 : 0;
        else newEnd = newStart + 1;
    }
    if (newEnd > self.textLbl.text.length) newEnd = self.textLbl.text.length;
    if (newStart >= newEnd) return;

    NSRange newRange = NSMakeRange(newStart, newEnd - newStart);
    objc_setAssociatedObject(self, &kSelRangeLocKey, @(newRange.location), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kSelRangeLenKey, @(newRange.length), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self wk_applyHighlightForRange:newRange];
    [self wk_updateHandlePositions];
}

-(void) wk_handleDragEnd {
    NSRange range = [self wk_currentSelRange];
    if (range.length == 0) return;
    BOOL isAll = (range.location == 0 && range.length == self.textLbl.text.length);
    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = dispatch_block_create(0, ^{
        [weakSelf wk_showSelectionMenuForRange:[weakSelf wk_currentSelRange] isAll:isAll];
    });
    objc_setAssociatedObject(self, &kSelTimerKey, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

#pragma mark - window tap dismiss + 通知

-(void) wk_selectionWindowTap:(UITapGestureRecognizer *)gr {
    if (![self wk_isInSelectionMode]) return;
    [self endInBubbleTextSelection];
}

-(BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UITapGestureRecognizer *windowTap = objc_getAssociatedObject(self, &kSelWindowTapKey);
    if (gestureRecognizer == windowTap) {
        CGPoint pt = [touch locationInView:nil];
        // 不拦截句柄区域
        WKSelectionHandle *sh = objc_getAssociatedObject(self, &kSelStartHandleKey);
        WKSelectionHandle *eh = objc_getAssociatedObject(self, &kSelEndHandleKey);
        if (sh && CGRectContainsPoint(sh.frame, pt)) return NO;
        if (eh && CGRectContainsPoint(eh.frame, pt)) return NO;
        // 不拦截菜单卡片
        UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
        UIView *card = [window viewWithTag:kSelectionPopupTag];
        if (card && CGRectContainsPoint(card.frame, pt)) return NO;
        // 不拦截气泡区域（允许用户在文字上操作但不 dismiss）
        CGRect bubbleInWindow = [self.bubbleBackgroundView convertRect:self.bubbleBackgroundView.bounds toView:nil];
        if (CGRectContainsPoint(CGRectInset(bubbleInWindow, -10, -10), pt)) return NO;
    }
    return YES;
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != kSelScrollKVOCtx) { [super observeValueForKeyPath:keyPath ofObject:object change:change context:context]; return; }
    if (![self wk_isInSelectionMode]) return;

    // cell 完全滑出屏幕时自动退出选区模式
    CGRect cellInWindow = [self convertRect:self.bounds toView:nil];
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (window && !CGRectIntersectsRect(cellInWindow, window.bounds)) {
        [self endInBubbleTextSelection];
        return;
    }

    [self wk_hideSelectionPopup];
    [self wk_updateHandlePositions];
    // 滚动停止后重新显示菜单
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(wk_reshowMenuAfterScroll) object:nil];
    [self performSelector:@selector(wk_reshowMenuAfterScroll) withObject:nil afterDelay:0.2];
}

-(void) wk_reshowMenuAfterScroll {
    if (![self wk_isInSelectionMode]) return;
    NSRange range = [self wk_currentSelRange];
    if (range.length == 0) return;
    BOOL isAll = (range.location == 0 && range.length == self.textLbl.text.length);
    [self wk_showSelectionMenuForRange:range isAll:isAll];
}

-(BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    UITapGestureRecognizer *windowTap = objc_getAssociatedObject(self, &kSelWindowTapKey);
    if (gestureRecognizer == windowTap) return YES;
    return NO;
}

-(void) wk_keyboardDismissSelection:(NSNotification *)note {
    if (![self wk_isInSelectionMode]) return;
    [self endInBubbleTextSelection];
}

-(void) wk_viewDisappearDismissSelection:(NSNotification *)note {
    if (![self wk_isInSelectionMode]) return;
    [self endInBubbleTextSelection];
}

#pragma mark - 选区菜单浮层

static const NSInteger kSelectionPopupTag = 0x574B5350;

-(void) wk_hideSelectionPopup {
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    [[window viewWithTag:kSelectionPopupTag] removeFromSuperview];
}

-(void) wk_showSelectionMenuForRange:(NSRange)selRange isAll:(BOOL)isAll {
    [self wk_hideSelectionPopup];

    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    NSArray *menuItems = objc_getAssociatedObject(self, &kSelectionMenusKey) ?: @[];

    NSMutableArray<NSDictionary*> *btns = [NSMutableArray array];
    UIColor *iconTintColor = [WKApp shared].config.contextMenu.primaryColor;
    __weak typeof(self) weakSelf = self;

    if (isAll) {
        for (WKMessageLongMenusItem *item in menuItems) {
            WKMessageLongMenusItem *captured = item;
            [btns addObject:@{
                @"title": item.title ?: @"",
                @"icon": item.icon ?: [NSNull null],
                @"action": ^{ if(captured.onTap) captured.onTap(weakSelf.conversationContext); }
            }];
        }
    } else {
        // 复制选中文字（先快照 range 和 text，因为 dismiss 会清除选区）
        NSRange capturedRange = selRange;
        NSString *capturedText = [self.textLbl.text copy];
        UIImage *copyIcon = [GenerateImageUtils generateTintedImgWithImage:[[WKApp shared] loadImage:@"Conversation/ContextMenu/Copy" moduleID:@"WuKongBase"] color:iconTintColor backgroundColor:nil];
        [btns addObject:@{
            @"title": LLang(@"复制"),
            @"icon": copyIcon ?: [NSNull null],
            @"action": ^{
                if (capturedRange.length > 0 && NSMaxRange(capturedRange) <= capturedText.length) {
                    [[UIPasteboard generalPasteboard] setString:[capturedText substringWithRange:capturedRange]];
                }
            }
        }];
        // 全选
        UIImage *selectIcon = [GenerateImageUtils generateTintedImgWithImage:[[WKApp shared] loadImage:@"Conversation/ContextMenu/Select" moduleID:@"WuKongBase"] color:iconTintColor backgroundColor:nil];
        [btns addObject:@{
            @"title": LLang(@"全选"),
            @"icon": selectIcon ?: [NSNull null],
            @"dismiss": @NO,
            @"action": ^{
                NSUInteger len = weakSelf.textLbl.text.length;
                objc_setAssociatedObject(weakSelf, &kSelRangeLocKey, @0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(weakSelf, &kSelRangeLenKey, @(len), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [weakSelf wk_applyHighlightForRange:NSMakeRange(0, len)];
                [weakSelf wk_updateHandlePositions];
                [weakSelf wk_showSelectionMenuForRange:NSMakeRange(0, len) isAll:YES];
            }
        }];
        // 创建子区
        NSString *capturedSelText = @"";
        if (selRange.length > 0 && NSMaxRange(selRange) <= self.textLbl.text.length) {
            capturedSelText = [self.textLbl.text substringWithRange:selRange];
        }
        if (capturedSelText.length > 50) capturedSelText = [capturedSelText substringToIndex:50];
        for (WKMessageLongMenusItem *item in menuItems) {
            if ([item.title isEqualToString:LLang(@"创建子区")]) {
                WKMessageLongMenusItem *captured = item;
                NSString *threadName = [capturedSelText copy];
                [btns addObject:@{
                    @"title": item.title,
                    @"icon": item.icon ?: [NSNull null],
                    @"action": ^{
                        if (captured.onTap) captured.onTap(weakSelf.conversationContext);
                        if (threadName.length > 0) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                UIViewController *presented = [[WKNavigationManager shared] topViewController].presentedViewController;
                                if ([presented isKindOfClass:[UIAlertController class]]) {
                                    UIAlertController *alert = (UIAlertController *)presented;
                                    if (alert.textFields.count > 0) alert.textFields.firstObject.text = threadName;
                                }
                            });
                        }
                    }
                }];
                break;
            }
        }
    }

    if (!btns.count) return;

    // 布局
    NSInteger colCount = MIN(4, (NSInteger)btns.count);
    NSInteger rowCount = (btns.count + colCount - 1) / colCount;
    CGFloat hPad, cellW, iconSz, cellH, cardW, cardH, cornerR;
    if (isAll) {
        hPad = 12; cardW = MIN(window.frame.size.width - 24, 380); cellW = (cardW - hPad*2) / colCount;
        iconSz = 22; cellH = 12+iconSz+4+13+10; cardH = rowCount*cellH+8; cornerR = 14;
    } else {
        hPad = 6; cellW = 56; iconSz = 18; cellH = 8+iconSz+3+12+6;
        cardW = cellW*colCount+hPad*2; cardH = rowCount*cellH+6; cornerR = 10;
    }

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0,0,cardW,cardH)];
    card.tag = kSelectionPopupTag;
    card.layer.cornerRadius = cornerR; card.clipsToBounds = NO;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.18; card.layer.shadowRadius = 12; card.layer.shadowOffset = CGSizeMake(0,4);

    UIView *clipView = [[UIView alloc] initWithFrame:CGRectMake(0,0,cardW,cardH)];
    clipView.backgroundColor = [WKApp shared].config.style == WKSystemStyleDark
        ? [UIColor colorWithRed:0.18 green:0.18 blue:0.20 alpha:1]
        : [UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1];
    clipView.layer.cornerRadius = cornerR; clipView.clipsToBounds = YES;
    [card addSubview:clipView];

    CGFloat iconTopPad = isAll?12:8, iconTextGap = isAll?4:3, textH = isAll?13:12, cellTopPad = isAll?4:3;
    UIFont *textFont = [UIFont systemFontOfSize:isAll?11:10];
    UIColor *textColor = [WKApp shared].config.defaultTextColor;
    for (NSInteger i = 0; i < (NSInteger)btns.count; i++) {
        NSDictionary *info = btns[i];
        NSInteger col = i % colCount, row = i / colCount;
        CGFloat cellX = hPad + col*cellW, cellY = cellTopPad + row*cellH;
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(cellX,cellY,cellW,cellH)];
        [btn setBackgroundImage:[self wk_imageWithColor:[UIColor colorWithWhite:0.5 alpha:0.15]] forState:UIControlStateHighlighted];
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake((cellW-iconSz)/2,iconTopPad,iconSz,iconSz)];
        iv.contentMode = UIViewContentModeScaleAspectFit; iv.tintColor = textColor;
        id iconObj = info[@"icon"];
        iv.image = (iconObj && iconObj != [NSNull null]) ? (UIImage *)iconObj : [UIImage systemImageNamed:@"ellipsis"];
        [btn addSubview:iv];
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(2,iconTopPad+iconSz+iconTextGap,cellW-4,textH)];
        lbl.text = info[@"title"]; lbl.font = textFont; lbl.textColor = textColor;
        lbl.textAlignment = NSTextAlignmentCenter; lbl.adjustsFontSizeToFitWidth = YES;
        [btn addSubview:lbl];
        NSNumber *shouldDismiss = info[@"dismiss"] ?: @YES;
        objc_setAssociatedObject(btn, "tapBlock", info[@"action"], OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(btn, "shouldDismiss", shouldDismiss, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [btn addTarget:self action:@selector(wk_selectionMenuItemTapped:) forControlEvents:UIControlEventTouchUpInside];
        [clipView addSubview:btn];
        if (col < colCount-1 && i < (NSInteger)btns.count-1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(cellX+cellW-0.25,cellY+8,0.5,cellH-16)];
            sep.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.3];
            [clipView addSubview:sep];
        }
    }

    // 菜单定位（实时计算选区位置，跟随滚动）
    CGRect visFrame;
    NSRange selRangeForPos = selRange;
    if (selRangeForPos.length > 0 && selRangeForPos.location + selRangeForPos.length <= self.textLbl.text.length) {
        NSLayoutManager *lm = self.textLbl.layoutManager;
        NSTextContainer *tc = self.textLbl.textContainer;
        [lm ensureLayoutForTextContainer:tc];
        NSUInteger startGlyph = [lm glyphIndexForCharacterAtIndex:selRangeForPos.location];
        NSUInteger endGlyph = [lm glyphIndexForCharacterAtIndex:NSMaxRange(selRangeForPos) - 1];
        CGRect startRect = [lm boundingRectForGlyphRange:NSMakeRange(startGlyph, 1) inTextContainer:tc];
        CGRect endRect = [lm boundingRectForGlyphRange:NSMakeRange(endGlyph, 1) inTextContainer:tc];
        CGRect unionRect = CGRectUnion(startRect, endRect);
        visFrame = [self.textLbl convertRect:unionRect toView:nil];
    } else {
        visFrame = [self.textLbl convertRect:self.textLbl.bounds toView:nil];
    }
    CGFloat safeTop = window.safeAreaInsets.top + 8;
    CGFloat safeBot = window.frame.size.height - window.safeAreaInsets.bottom - 80;
    CGFloat cardX = MAX(8, MIN(visFrame.origin.x, window.frame.size.width - cardW - 8));
    CGFloat handleGap = 28;
    CGFloat aboveY = visFrame.origin.y - cardH - handleGap;
    CGFloat belowY = visFrame.origin.y + visFrame.size.height + handleGap;
    CGFloat cardY = (aboveY >= safeTop) ? aboveY : belowY;
    cardY = MAX(safeTop, MIN(cardY, safeBot - cardH));
    card.frame = CGRectMake(cardX, cardY, cardW, cardH);
    [window addSubview:card];

    card.alpha = 0; card.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        card.alpha = 1; card.transform = CGAffineTransformIdentity;
    } completion:nil];
}

-(void) wk_selectionMenuItemTapped:(UIButton *)sender {
    void(^block)(void) = objc_getAssociatedObject(sender, "tapBlock");
    if (!block) return;
    BOOL shouldDismiss = [objc_getAssociatedObject(sender, "shouldDismiss") boolValue];
    if (shouldDismiss) {
        [self endInBubbleTextSelection];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            block();
        });
    } else {
        block();
    }
}

/// 含表格消息的全屏文本选择浮层
-(void) showFullTextSelectionOverlayWithMenuItems:(NSArray*)menuItems {
    NSString *rawText = [[self class] getRawContent:self.messageModel];
    if (!rawText.length) return;

    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;

    UIView *dimView = [[UIView alloc] initWithFrame:window.bounds];
    dimView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35f];
    dimView.alpha = 0;
    dimView.tag = 99887;

    CGFloat padding = 16.0f;
    CGFloat maxW = window.bounds.size.width - padding * 2;
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
    tv.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    CGFloat tvMaxH = window.bounds.size.height * 0.5f;
    CGFloat tvH = MIN([tv sizeThatFits:CGSizeMake(maxW, CGFLOAT_MAX)].height + 24.0f, tvMaxH);
    tv.frame = CGRectMake(padding, window.bounds.size.height - tvH - 60.0f, maxW, tvH);

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyBtn setTitle:LLang(@"复制") forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
    copyBtn.backgroundColor = [WKApp shared].config.themeColor;
    [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyBtn.layer.cornerRadius = 10.0f;
    copyBtn.clipsToBounds = YES;
    copyBtn.frame = CGRectMake(padding, tv.frame.origin.y + tv.frame.size.height + 10.0f, maxW, 44.0f);

    [dimView addSubview:tv];
    [dimView addSubview:copyBtn];
    [window addSubview:dimView];

    __weak UIView *weakDim = dimView;
    __weak UITextView *weakTV = tv;
    void(^dismiss)(void) = ^{
        [UIView animateWithDuration:0.2 animations:^{ weakDim.alpha = 0; } completion:^(BOOL f) { [weakDim removeFromSuperview]; }];
    };
    void(^copyAndDismiss)(void) = ^{
        UITextView *strongTV = weakTV;
        NSString *selectedText = nil;
        if (strongTV && strongTV.selectedRange.length > 0) {
            selectedText = [strongTV.text substringWithRange:strongTV.selectedRange];
        }
        if (!selectedText.length) selectedText = strongTV.text;
        if (selectedText.length > 0) {
            [[UIPasteboard generalPasteboard] setString:selectedText];
            [weakDim.superview showHUDWithHide:LLang(@"已复制")];
        }
        dismiss();
    };
    objc_setAssociatedObject(copyBtn, "copyAndDismiss", copyAndDismiss, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [copyBtn addTarget:self action:@selector(wk_fullTextCopyTapped:) forControlEvents:UIControlEventTouchUpInside];

    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(wk_fullTextBgTap:)];
    objc_setAssociatedObject(bgTap, "dismissBlock", dismiss, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [dimView addGestureRecognizer:bgTap];

    [UIView animateWithDuration:0.2 animations:^{ dimView.alpha = 1; }];
    [tv becomeFirstResponder];
    [tv selectAll:nil];
}

-(void) wk_fullTextCopyTapped:(UIButton *)btn {
    void(^block)(void) = objc_getAssociatedObject(btn, "copyAndDismiss");
    if (block) block();
}

-(void) wk_fullTextBgTap:(UITapGestureRecognizer *)gr {
    void(^block)(void) = objc_getAssociatedObject(gr, "dismissBlock");
    if (block) block();
}

-(UIImage *) wk_imageWithColor:(UIColor *)color {
    CGRect r = CGRectMake(0,0,1,1);
    UIGraphicsBeginImageContextWithOptions(r.size, NO, 0);
    [color setFill]; UIRectFill(r);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
