//
//  OctoSummaryDetailVC.m
//  OctoContext
//

#import "OctoSummaryDetailVC.h"
#import "OctoSummaryAPI.h"
#import "OctoSummaryActionSheet.h"
#import "OctoSummaryMarkdownRender.h"
#import "OctoCitationBadgeView.h"
#import "OctoSummaryDateFormat.h"
#import "OctoDetailSourcesView.h"
#import "OctoRelatedChatSheet.h"
#import "OctoSummaryEditVC.h"
#import "OctoSummaryConfirmVC.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WuKongIMSDK/WKTextContent.h>
#import <WuKongBase/WuKongBase-Swift.h>           // WKMarkdownRenderer (Swift)
#import <WebKit/WebKit.h>

@interface OctoSummaryDetailVC () <UITextViewDelegate, WKNavigationDelegate>
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) OctoDetailSourcesView *sourcesView;
@property(nonatomic, strong) UILabel *createdAtLabel;
@property(nonatomic, strong) UIView *processingView;
@property(nonatomic, strong) UIActivityIndicatorView *processingSpinner;
@property(nonatomic, strong) UILabel *processingTitle;
@property(nonatomic, strong) UILabel *processingDesc;
@property(nonatomic, strong) UILabel *waitingTitle;
@property(nonatomic, strong) UIButton *waitingActionBtn;

// 总结内容容器 + 顺序分段渲染
//   - 文本段: UITextView (selectable=NO + 强制 TK1, 修首次点击跳动)
//   - 表格段: WKWebView 渲染 cmark-gfm 出的 HTML, citation 通过预处理 [N] → [N](octo-cit://N)
//             嵌入为 <a>, WKNavigationDelegate 拦截 octo-cit:// 触发 RelatedChatSheet
@property(nonatomic, strong) UIView *contentContainer;
@property(nonatomic, strong) NSMutableArray<UIView *> *contentSegments;

@property(nonatomic, strong) UIButton *moreBtn;
@property(nonatomic, strong) OctoSummaryDetail *detail;
@property(nonatomic, strong) NSTimer *pollTimer;

// 底部悬浮 footer (转发到聊天 + 编辑), 只在 completed 时出现
@property(nonatomic, strong) UIView *bottomBar;
@property(nonatomic, strong) UIButton *footerForwardBtn;
@property(nonatomic, strong) UIButton *footerEditBtn;
@end

@implementation OctoSummaryDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor systemBackgroundColor]
            : [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF7/255.0 alpha:1.0];
    }];
    // 标题固定 "智能总结" (用户要求): 不再随 detail.title 变化, 因为详情页本身已经在 body
    // 大标题里展示总结主题, nav 上再放总结主题就重复了。
    self.navigationBar.title = LLang(@"智能总结");

    self.moreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.moreBtn setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
    self.moreBtn.tintColor = [UIColor labelColor];
    self.moreBtn.frame = CGRectMake(0, 0, 28, 28);
    [self.moreBtn addTarget:self action:@selector(onMore:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationBar.rightView = self.moreBtn;

    self.scroll = [UIScrollView new];
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];

    self.titleLabel = [UILabel new];
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.textColor = [UIColor labelColor];
    [self.scroll addSubview:self.titleLabel];

    self.sourcesView = [[OctoDetailSourcesView alloc] initWithFrame:CGRectZero];
    __weak typeof(self) ws = self;
    self.sourcesView.onToggle = ^(BOOL expanded) {
        // chip 折叠/展开 → 高度变化, 触发 scroll 内容重排
        [ws relayoutContent];
    };
    [self.scroll addSubview:self.sourcesView];

    self.createdAtLabel = [UILabel new];
    self.createdAtLabel.font = [UIFont systemFontOfSize:12];
    self.createdAtLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.5];
    [self.scroll addSubview:self.createdAtLabel];

    // contentView: selectable = NO 是修 "首次点击文本会跳一下" 的关键 ——
    self.contentContainer = [UIView new];
    self.contentContainer.backgroundColor = [UIColor systemBackgroundColor];
    self.contentContainer.layer.cornerRadius = 12;
    self.contentContainer.clipsToBounds = YES;
    self.contentContainer.hidden = YES;
    [self.scroll addSubview:self.contentContainer];
    self.contentSegments = [NSMutableArray array];

    // processing
    self.processingView = [UIView new];
    // 浅色: #FCF3FF (品牌紫的极淡铺底); 深色: 用深紫调与黑底分层, 又与品牌紫 spinner
    // 视觉一致, 不会出现 "白底白字看不见" 的问题。两态都和 contentContainer 的
    // systemBackgroundColor 形成层级对比。
    self.processingView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0x2A/255.0 green:0x1A/255.0 blue:0x38/255.0 alpha:1.0];
        }
        return [UIColor colorWithRed:0xFC/255.0 green:0xF3/255.0 blue:0xFF/255.0 alpha:1.0];
    }];
    self.processingView.layer.cornerRadius = 16;
    self.processingView.hidden = YES;
    [self.scroll addSubview:self.processingView];
    self.processingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.processingSpinner.color = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
    [self.processingView addSubview:self.processingSpinner];
    self.processingTitle = [UILabel new];
    self.processingTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.processingTitle.textColor = [UIColor labelColor];
    self.processingTitle.text = LLang(@"AI正在分析聊天记录...");
    self.processingTitle.textAlignment = NSTextAlignmentCenter;
    [self.processingView addSubview:self.processingTitle];
    self.processingDesc = [UILabel new];
    self.processingDesc.font = [UIFont systemFontOfSize:13];
    self.processingDesc.textColor = [UIColor.labelColor colorWithAlphaComponent:0.6];
    self.processingDesc.text = LLang(@"可能需要一会儿时间,请稍候");
    self.processingDesc.numberOfLines = 0;
    self.processingDesc.textAlignment = NSTextAlignmentCenter;
    [self.processingView addSubview:self.processingDesc];

    // waiting
    self.waitingTitle = [UILabel new];
    self.waitingTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.waitingTitle.textColor = [UIColor labelColor];
    self.waitingTitle.numberOfLines = 0;
    self.waitingTitle.textAlignment = NSTextAlignmentCenter;
    self.waitingTitle.hidden = YES;
    [self.scroll addSubview:self.waitingTitle];
    self.waitingActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.waitingActionBtn setTitle:LLang(@"查看确认状态") forState:UIControlStateNormal];
    [self.waitingActionBtn addTarget:self action:@selector(onWaitingAction) forControlEvents:UIControlEventTouchUpInside];
    self.waitingActionBtn.hidden = YES;
    [self.scroll addSubview:self.waitingActionBtn];

    [self buildBottomBar];

    [self loadDetail];
}

- (void)dealloc { [self.pollTimer invalidate]; }

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.pollTimer invalidate];
    self.pollTimer = nil;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = CGRectGetMaxY(self.navigationBar.frame);

    // 底部悬浮按钮区:占 bottomBarH + bottomSafe; scroll 自身底部留出空间, 不被遮挡。
    CGFloat bottomBarH = self.bottomBar.hidden ? 0 : 72;
    CGFloat bottomSafe = self.view.safeAreaInsets.bottom;
    if (!self.bottomBar.hidden) {
        self.bottomBar.frame = CGRectMake(0,
                                          self.view.bounds.size.height - bottomBarH - bottomSafe,
                                          self.view.bounds.size.width, bottomBarH + bottomSafe);
        [self layoutBottomBarButtons];
    }

    self.scroll.frame = CGRectMake(0, top,
                                   self.view.bounds.size.width,
                                   self.view.bounds.size.height - top);
    self.scroll.contentInset = UIEdgeInsetsMake(0, 0,
                                                 (self.bottomBar.hidden ? 0 : bottomBarH + bottomSafe + 12),
                                                 0);
    [self relayoutContent];
}

- (void)relayoutContent {
    CGFloat w = self.view.bounds.size.width - 32;
    CGFloat y = 12;

    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(w, CGFLOAT_MAX)];
    self.titleLabel.frame = CGRectMake(16, y, w, titleSize.height);
    y += titleSize.height + 10;

    // 来源 chip 流式列表 (折叠/展开自适应高度)
    CGFloat srcH = [self.sourcesView heightForWidth:w];
    if (srcH > 0) {
        self.sourcesView.frame = CGRectMake(16, y, w, srcH);
        y += srcH + 12;     // 来源行 → 创建时间行 间距 12 (用户反馈"目前太紧凑了")
    }

    // 创建时间 (单独一行, "创建于："带冒号)
    if (self.createdAtLabel.text.length > 0) {
        CGSize ts = [self.createdAtLabel sizeThatFits:CGSizeMake(w, CGFLOAT_MAX)];
        self.createdAtLabel.frame = CGRectMake(16, y, w, ts.height);
        y += ts.height + 12;
    }

    if (!self.processingView.hidden) {
        self.processingView.frame = CGRectMake(16, y, w, 200);
        self.processingSpinner.frame = CGRectMake((w - 40) / 2.0, 36, 40, 40);
        self.processingTitle.frame  = CGRectMake(16, 96, w - 32, 24);
        self.processingDesc.frame   = CGRectMake(16, 130, w - 32, 36);
        y += 200 + 12;
    }
    if (!self.waitingTitle.hidden) {
        self.waitingTitle.frame = CGRectMake(16, y, w, 60);
        y += 60 + 4;
        self.waitingActionBtn.frame = CGRectMake(16, y, w, 36);
        y += 36 + 12;
    }
    if (!self.contentContainer.hidden) {
        // 容器 = 所有 segment 的累积高度 + 上下 16 padding。每个 segment 自身的 frame
        // 在创建/收到 webview 高度回调时已写入。这里把 container 高度对齐子总高即可。
        CGFloat innerY = 16;
        CGFloat innerW = w - 28;     // 容器内左右各 14 padding
        for (UIView *seg in self.contentSegments) {
            CGFloat h = seg.frame.size.height;
            if ([seg isKindOfClass:UITextView.class]) {
                CGSize sz = [seg sizeThatFits:CGSizeMake(innerW, CGFLOAT_MAX)];
                h = MAX(ceilf(sz.height), 20);
            }
            seg.frame = CGRectMake(14, innerY, innerW, h);
            innerY += h + 8;          // 段间留 8pt 间距
        }
        CGFloat containerH = MAX(innerY + 8, 80);
        self.contentContainer.frame = CGRectMake(16, y, w, containerH);
        y += containerH + 12;
    }
    self.scroll.contentSize = CGSizeMake(self.view.bounds.size.width, y);
}

#pragma mark - Bottom bar (转发到聊天 + 编辑)

- (void)buildBottomBar {
    self.bottomBar = [UIView new];
    self.bottomBar.backgroundColor = [UIColor systemBackgroundColor];
    self.bottomBar.layer.shadowColor = [UIColor blackColor].CGColor;
    self.bottomBar.layer.shadowOffset = CGSizeMake(0, -2);
    self.bottomBar.layer.shadowOpacity = 0.06;
    self.bottomBar.layer.shadowRadius = 8;
    self.bottomBar.hidden = YES;
    [self.view addSubview:self.bottomBar];

    self.footerForwardBtn = [self makeFooterButton:LLang(@"转发到聊天") primary:NO action:@selector(forwardToChat)];
    self.footerEditBtn    = [self makeFooterButton:LLang(@"编辑")    primary:YES action:@selector(openEditor)];
    [self.bottomBar addSubview:self.footerForwardBtn];
    [self.bottomBar addSubview:self.footerEditBtn];
}

- (UIButton *)makeFooterButton:(NSString *)title primary:(BOOL)primary action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    if (primary) {
        b.backgroundColor = [UIColor labelColor];
        [b setTitleColor:[UIColor systemBackgroundColor] forState:UIControlStateNormal];
    } else {
        b.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.06];
        [b setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    }
    b.layer.cornerRadius = 22;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)layoutBottomBarButtons {
    CGFloat w = self.view.bounds.size.width;
    CGFloat hSide = 16;
    CGFloat gap = 12;
    CGFloat btnW = (w - hSide * 2 - gap) / 2.0;
    CGFloat btnH = 44;
    self.footerForwardBtn.frame = CGRectMake(hSide, 14, btnW, btnH);
    self.footerEditBtn.frame    = CGRectMake(hSide + btnW + gap, 14, btnW, btnH);
}

#pragma mark - Load

- (void)loadDetail {
    int64_t tid = self.taskId.longLongValue;
    if (tid == 0) return;
    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] getSummaryDetail:tid callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error || ![result isKindOfClass:OctoSummaryDetail.class]) {
            [weakSelf.view showHUDWithHide:LLang(@"加载失败")];
            return;
        }
        weakSelf.detail = result;
        [weakSelf renderDetail];
        if (weakSelf.detail.status == OctoTaskStatusProcessing
            || weakSelf.detail.status == OctoTaskStatusPending) {
            [weakSelf scheduleNextPoll];
        }
    }];
}

- (void)scheduleNextPoll {
    [self.pollTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:NO block:^(NSTimer *t) {
        [weakSelf loadDetail];
    }];
}

- (void)renderDetail {
    OctoSummaryDetail *d = self.detail;
    self.titleLabel.text = d.title;

    // 来源 chip 列表 (无 "来自" 前缀, 直接显示每个 source 的胶囊)
    self.sourcesView.items = d.sources;

    // 创建时间: "创建于：yyyy-MM-dd HH:mm" (带冒号)
    if (d.createdAt.length > 0) {
        self.createdAtLabel.text = [NSString stringWithFormat:LLang(@"创建于：%@"),
                                    [OctoSummaryDateFormat localFromISO:d.createdAt]];
    } else {
        self.createdAtLabel.text = @"";
    }

    BOOL processing = (d.status == OctoTaskStatusProcessing || d.status == OctoTaskStatusPending);
    BOOL waiting    = (d.status == OctoTaskStatusWaitingConfirm);
    BOOL completed  = (d.status == OctoTaskStatusCompleted);
    BOOL failed     = (d.status == OctoTaskStatusFailed);
    BOOL cancelled  = (d.status == OctoTaskStatusCancelled);

    self.processingView.hidden = !processing;
    if (processing) [self.processingSpinner startAnimating]; else [self.processingSpinner stopAnimating];

    self.waitingTitle.hidden = !waiting;
    self.waitingActionBtn.hidden = !waiting;
    if (waiting) {
        self.waitingTitle.text = LLang(@"等待参与者确认\n所有参与者确认后开始生成");
    }

    BOOL hasContent = (completed || failed || cancelled);
    self.contentContainer.hidden = !hasContent;
    if (completed) {
        [self renderCompletedContent:d.result.content citations:d.result.citations];
    } else if (failed) {
        NSString *err = d.errorMessage.length > 0 ? d.errorMessage : LLang(@"未知错误");
        NSString *prefix = LLang(@"生成失败:\n");
        [self renderPlainSegmentText:[prefix stringByAppendingString:err]
                                color:[UIColor systemRedColor]];
    } else if (cancelled) {
        [self renderPlainSegmentText:LLang(@"任务已取消")
                                color:[UIColor.labelColor colorWithAlphaComponent:0.5]];
    } else {
        [self clearContentSegments];
    }

    // 底部悬浮按钮: 仅 completed 显示 (转发到聊天 + 编辑都需要有结果存在)
    self.bottomBar.hidden = !completed;
    [self.view setNeedsLayout];

    [self relayoutContent];
}

#pragma mark - Content segments (text + table 混排)

- (void)clearContentSegments {
    for (UIView *v in self.contentSegments) [v removeFromSuperview];
    [self.contentSegments removeAllObjects];
}

/// 失败/取消等"纯文本提示"分支: 只放一个文本 segment。不走 markdown / citation,
/// 避免格式化逻辑命中错位。
- (void)renderPlainSegmentText:(NSString *)text color:(UIColor *)color {
    [self clearContentSegments];
    UITextView *tv = [self makeTextSegment];
    tv.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:14],
        NSForegroundColorAttributeName: color,
    }];
    [self.contentContainer addSubview:tv];
    [self.contentSegments addObject:tv];
    [self relayoutContent];
}

/// completed 分支: 解析 markdown 内容里的表格段, 文本段走自家 OctoSummaryMarkdownRender
/// (含 [N] citation 徽章), 表格段走 WKMarkdownRenderer 输出 HTML 由 WKWebView 渲染。
/// citation 在表格里的可点击性: 把 [N] 预处理成 [N](octo-cit://N) 让 cmark 出 <a>,
/// WKNavigationDelegate 拦截 octo-cit:// scheme 触发 RelatedChatSheet。
- (void)renderCompletedContent:(NSString *)content
                     citations:(NSArray<OctoCitationItem *> *)citations {
    [self clearContentSegments];
    NSString *raw = content ?: @"";
    if (raw.length == 0) return;

    BOOL hasTable = [WKMarkdownRenderer containsTable:raw];
    if (!hasTable) {
        UITextView *tv = [self makeTextSegment];
        tv.attributedText = [OctoSummaryMarkdownRender attributedFromContent:raw
                                                                    citations:citations
                                                                     fontSize:14];
        [self.contentContainer addSubview:tv];
        [self.contentSegments addObject:tv];
        [self relayoutContent];
        return;
    }

    NSArray<NSDictionary *> *segments = [WKMarkdownRenderer splitContentSegments:raw];
    for (NSDictionary *seg in segments) {
        NSString *type = seg[@"type"];
        NSString *text = seg[@"content"];
        if (text.length == 0) continue;
        if ([type isEqualToString:@"text"]) {
            UITextView *tv = [self makeTextSegment];
            tv.attributedText = [OctoSummaryMarkdownRender attributedFromContent:text
                                                                        citations:citations
                                                                         fontSize:14];
            [self.contentContainer addSubview:tv];
            [self.contentSegments addObject:tv];
        } else if ([type isEqualToString:@"table"]) {
            // 在传给 cmark 前把 [N] 转 [N](octo-cit://N) —— 让 renderInlineCellContent
            // 把它们转成 <a href="octo-cit://N">[N]</a>, WKNavigationDelegate 接管点击。
            NSString *injected = [self injectCitationLinks:text];
            UIColor *textColor = [UIColor labelColor];
            NSString *colorHex = [self hexFromColor:textColor];
            NSString *html = [WKMarkdownRenderer extractTableHTML:injected
                                                          fontSize:14
                                                      textColorHex:colorHex];
            if (html.length == 0) continue;
            html = [self wrapTableHTML:html];
            WKWebView *wv = [self makeTableSegment];
            [wv loadHTMLString:html baseURL:nil];
            [self.contentContainer addSubview:wv];
            [self.contentSegments addObject:wv];
        }
    }
    [self relayoutContent];
}

- (UITextView *)makeTextSegment {
    UITextView *tv = [UITextView new];
    tv.editable = NO;
    tv.selectable = NO;          // 禁用系统文字选择, 修首次点击 "激活跳动"
    tv.scrollEnabled = NO;
    tv.backgroundColor = [UIColor clearColor];
    // 顶/底各留 4pt 让 markdown 标题(更大字号 → 更高 ascender)不被 frame 顶边裁掉。
    // 之前用 UIEdgeInsetsZero 把 padding 完全抹掉, 第一行 # 标题的 cap-height 超出 y=0
    // 直接被 frame 切掉一半 (用户报"顶部标题文本少显示了一半")。
    tv.textContainerInset = UIEdgeInsetsMake(4, 0, 4, 0);
    tv.textContainer.lineFragmentPadding = 0;
    tv.allowsEditingTextAttributes = NO;
    (void)tv.layoutManager;          // 强制 TextKit 1, 修首次点击布局抖动
    if (@available(iOS 16.0, *)) {
        tv.findInteractionEnabled = NO;
    }
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTextSegmentTap:)];
    [tv addGestureRecognizer:tap];
    return tv;
}

- (WKWebView *)makeTableSegment {
    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 300, 80)
                                       configuration:cfg];
    wv.navigationDelegate = self;
    wv.scrollView.scrollEnabled = NO;
    wv.scrollView.bounces = NO;
    wv.opaque = NO;
    wv.backgroundColor = [UIColor clearColor];
    return wv;
}

/// 表格里的 citation 聚合: 连续相邻的 [N][M]... 合成单条 markdown link, 与正文段
/// (OctoSummaryMarkdownRender.applyCitationsTo:) 同口径; URL host 用下划线连接索引,
/// label 走 OctoSummaryMarkdownRender.badgeTextFromIndices:。点击时 navigation
/// delegate 把 host 拆回 indices 数组下放给 RelatedChatSheet。
- (NSString *)injectCitationLinks:(NSString *)content {
    NSError *err = nil;
    // 一连串紧贴的 [N][M]... 视为一组 (中间无字符);
    // 已是 markdown 链接形式 [N](...) 的不动 (negative lookahead/-behind)。
    NSRegularExpression *runRe = [NSRegularExpression
        regularExpressionWithPattern:@"(?<!\\]\\()(?:\\[\\d+\\])+(?!\\()"
                             options:0
                               error:&err];
    if (!runRe) return content;
    NSArray<NSTextCheckingResult *> *runs = [runRe matchesInString:content
                                                            options:0
                                                              range:NSMakeRange(0, content.length)];
    if (runs.count == 0) return content;

    NSRegularExpression *digitRe = [NSRegularExpression regularExpressionWithPattern:@"\\d+" options:0 error:nil];
    NSMutableString *out = [NSMutableString string];
    NSUInteger cursor = 0;
    for (NSTextCheckingResult *m in runs) {
        if (m.range.location > cursor) {
            [out appendString:[content substringWithRange:NSMakeRange(cursor, m.range.location - cursor)]];
        }
        NSString *runText = [content substringWithRange:m.range];   // e.g. "[1][2][3]"
        NSMutableArray<NSNumber *> *indices = [NSMutableArray array];
        NSMutableArray<NSString *> *idStrs = [NSMutableArray array];
        for (NSTextCheckingResult *dm in [digitRe matchesInString:runText options:0 range:NSMakeRange(0, runText.length)]) {
            NSString *s = [runText substringWithRange:dm.range];
            [indices addObject:@([s integerValue])];
            [idStrs addObject:s];
        }
        if (indices.count == 0) {
            [out appendString:runText];
        } else {
            NSString *label = [OctoSummaryMarkdownRender badgeTextFromIndices:indices];
            // 用下划线串而不是逗号: NSURL host 对逗号不友好, integerValue 解 "1,2,3"
            // 也只会拿到 1 丢掉后面的; 下划线 host (如 "1_3_5") 解析完整且 NSURL 接受。
            NSString *host = [idStrs componentsJoinedByString:@"_"];
            [out appendFormat:@"[%@](octo-cit://%@)", label, host];
        }
        cursor = NSMaxRange(m.range);
    }
    if (cursor < content.length) {
        [out appendString:[content substringFromIndex:cursor]];
    }
    return out;
}

/// 给 extractTableHTML 输出的 HTML 注入: ① 横向滚动容器(用户报"无法左右滑动")
/// ② 深色模式 CSS(用户报"未适配深色") ③ citation 徽章样式。
///
/// 横向滚动: 在 body 外包 .octo-table-wrap{overflow-x:auto}, 表格本身已声明
/// width:max-content + white-space:nowrap, 超出视口时容器内可左右滑。
/// WKWebView 外层 scrollView.scrollEnabled = NO 不影响内部 overflow div 的
/// 触摸滚动 (WebKit 单独处理 inner scroller),所以纵向不会与父 scrollView 抢手势。
///
/// 深色模式: 用 @media (prefers-color-scheme: dark) —— WKWebView 跟随 iOS
/// traitCollection 的 userInterfaceStyle 自动 resolve, 系统切换深浅时 CSS 即时生效,
/// 无需重新 loadHTMLString。
- (NSString *)wrapTableHTML:(NSString *)html {
    if (html.length == 0) return html;
    NSString *injectedCSS =
        @"<style>"
        @"a[href^='octo-cit']{display:inline-block;padding:0 6px;margin:0 1px;"
        @"background:rgba(127,59,245,0.16);color:#7F3BF5;border-radius:7px;"
        @"font-size:11px;font-weight:500;text-decoration:none;line-height:1.6;}"
        @".octo-table-wrap{overflow-x:auto;-webkit-overflow-scrolling:touch;width:100%;}"
        @"@media (prefers-color-scheme: dark){"
        @"  body,*{color:rgba(255,255,255,0.92)!important;}"
        @"  table{border-color:#555!important;}"
        @"  th{background:rgba(255,255,255,0.08)!important;border-color:#555!important;}"
        @"  td{border-color:#444!important;}"
        @"  a[href^='octo-cit']{background:rgba(127,59,245,0.32);color:#D1B7FF;}"
        @"}"
        @"</style></head>";
    html = [html stringByReplacingOccurrencesOfString:@"</head>" withString:injectedCSS];
    html = [html stringByReplacingOccurrencesOfString:@"<body>"
                                            withString:@"<body><div class=\"octo-table-wrap\">"];
    html = [html stringByReplacingOccurrencesOfString:@"</body>"
                                            withString:@"</div></body>"];
    return html;
}

- (NSString *)hexFromColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

#pragma mark - Citation tap (per text segment)

- (void)onTextSegmentTap:(UITapGestureRecognizer *)g {
    UIView *v = g.view;
    if (![v isKindOfClass:UITextView.class]) return;
    UITextView *tv = (UITextView *)v;
    CGPoint p = [g locationInView:tv];
    p.x -= tv.textContainerInset.left;
    p.y -= tv.textContainerInset.top;
    NSUInteger idx = [tv.layoutManager characterIndexForPoint:p
                                              inTextContainer:tv.textContainer
                     fractionOfDistanceBetweenInsertionPoints:nil];
    if (idx >= tv.attributedText.length) return;
    // 优先取 group 数组 (合并徽章): [1,2,3]; 没有就退化为单 index, 包成单元素数组
    NSArray<NSNumber *> *groupIndices = [tv.attributedText attribute:OctoCitationGroupAttrKey
                                                              atIndex:idx
                                                       effectiveRange:NULL];
    if (groupIndices.count == 0) {
        NSNumber *single = [tv.attributedText attribute:OctoCitationIndexAttrKey
                                                  atIndex:idx
                                           effectiveRange:NULL];
        if (!single) return;
        groupIndices = @[single];
    }
    [self openCitationsByIndices:groupIndices];
}

- (void)openCitationsByIndices:(NSArray<NSNumber *> *)indices {
    if (indices.count == 0) return;
    [OctoRelatedChatSheet presentInVC:self
                            citations:self.detail.result.citations
                        activeIndices:indices];
}

/// 旧入口保留: 表格里的 octo-cit:// 单 index 链路 + 任何遗留单点调用。
- (void)openCitationByIndex:(NSInteger)citationIndex {
    [self openCitationsByIndices:@[@(citationIndex)]];
}

#pragma mark - WKNavigationDelegate (table 内 citation 点击 + 高度自适应)

- (void)webView:(WKWebView *)webView
        decidePolicyForNavigationAction:(WKNavigationAction *)action
                        decisionHandler:(void (^)(WKNavigationActionPolicy))handler {
    NSURL *url = action.request.URL;
    // 拦截 octo-cit://N 或 octo-cit://N_M_K → 打开关联聊天 sheet。
    // 单索引 host = "1" 仍然成立; 聚合 host = "1_3_5" 时按 _ 拆开成 indices 数组。
    if ([url.scheme isEqualToString:@"octo-cit"]) {
        NSString *host = url.host ?: @"";
        NSMutableArray<NSNumber *> *indices = [NSMutableArray array];
        for (NSString *part in [host componentsSeparatedByString:@"_"]) {
            NSInteger v = [part integerValue];
            if (v > 0) [indices addObject:@(v)];
        }
        if (indices.count > 0) [self openCitationsByIndices:indices];
        handler(WKNavigationActionPolicyCancel);
        return;
    }
    // 首次 loadHTMLString 自身的 about:blank / non-http 加载放行
    if (action.navigationType == WKNavigationTypeOther) {
        handler(WKNavigationActionPolicyAllow);
        return;
    }
    // 用户点击表格内其他 <a> 链接: 一律不在 webview 内导航 (避免在 cell 里跳页面)。
    // 后续可在这里接通用 URL 路由。
    handler(WKNavigationActionPolicyCancel);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // 异步取实际内容高度并应用到 webview frame, 完成后触发 relayoutContent。
    // 异步链路 + 主线程回到 main 队列, 不会阻塞 runloop, 也不会 deadlock。
    __weak typeof(self) ws = self;
    [webView evaluateJavaScript:@"document.body.scrollHeight"
              completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if (!ws) return;
        CGFloat h = [result respondsToSelector:@selector(floatValue)]
            ? MAX(20, [result floatValue]) : 80;
        CGRect f = webView.frame;
        if (fabs(f.size.height - h) < 0.5) return;
        f.size.height = h;
        webView.frame = f;
        [ws relayoutContent];
    }];
}

#pragma mark - More menu (WKFloatingMenu, 与列表 cell 同款风格)

/// 详情页菜单只保留 "重新生成 + 删除" / "取消任务 + 删除" 等 ——
/// "编辑" 与 "转发到聊天" 走底部 footer, 不重复出现在菜单。
- (void)onMore:(UIButton *)btn {
    OctoSummaryDetail *d = self.detail;
    if (!d) return;
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    __weak typeof(self) ws = self;
    void (^add)(NSString *, void(^)(void), BOOL) = ^(NSString *title, void (^action)(void), BOOL destructive) {
        [items addObject:@{
            @"title": title,
            @"isDestructive": @(destructive),
            @"action": [action copy],
        }];
    };
    switch (d.status) {
        case OctoTaskStatusProcessing:
        case OctoTaskStatusPending:
        case OctoTaskStatusWaitingConfirm: {
            add(LLang(@"取消任务"), ^{ [ws performCancel]; }, NO);
            break;
        }
        case OctoTaskStatusCompleted: {
            add(LLang(@"重新生成"), ^{ [ws performRegenerate]; }, NO);
            break;
        }
        case OctoTaskStatusCancelled: {
            add(LLang(@"重新生成"), ^{ [ws performRegenerate]; }, NO);
            break;
        }
        case OctoTaskStatusFailed: {
            add(LLang(@"重试"),    ^{ [ws performRegenerate]; }, NO);
            break;
        }
        default: break;
    }
    add(LLang(@"删除"), ^{ [ws confirmDelete]; }, YES);
    CGPoint anchor = [btn.superview convertPoint:btn.center toView:nil];
    [WKFloatingMenu showItems:items atPoint:anchor];
}

- (void)performCancel {
    [[OctoSummaryAPI shared] cancelSummary:self.detail.taskId callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) { [self.view showHUDWithHide:LLang(@"取消失败")]; return; }
        [self.view showHUDWithHide:LLang(@"已取消")];
        [self loadDetail];
    }];
}

- (void)performRegenerate {
    [[OctoSummaryAPI shared] regenerateSummary:self.detail.taskId topic:nil callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) { [self.view showHUDWithHide:LLang(@"重新生成失败")]; return; }
        [self.view showHUDWithHide:LLang(@"已开始重新生成")];
        [self loadDetail];
    }];
}

- (void)confirmDelete {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"确认删除")
                                                                   message:LLang(@"删除后将无法恢复")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull a) {
        [[OctoSummaryAPI shared] deleteSummary:self.detail.taskId callback:^(id _Nullable result, NSError * _Nullable error) {
            if (error) { [self.view showHUDWithHide:LLang(@"删除失败")]; return; }
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Footer actions

- (void)openEditor {
    OctoSummaryEditVC *vc = [OctoSummaryEditVC new];
    vc.detail = self.detail;
    vc.onSaved = ^{ [self loadDetail]; };
    // push 到根 nav (与发起总结/选择聊天页同一栈), 这样保存/返回的 popViewControllerAnimated:
    // 才能正确回到详情页。原 modal 路径 popViewControllerAnimated 走的是根 nav, 但 EditVC
    // 在另一条 modal nav 栈里, pop 没人响应 → "无法返回也无法保存"。
    vc.hidesBottomBarWhenPushed = YES;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)forwardToChat {
    NSString *content = self.detail.result.content;
    if (content.length == 0) {
        [self.view showHUDWithHide:LLang(@"暂无可转发内容")];
        return;
    }
    Class fwdCls = NSClassFromString(@"WKForwardSelectVC");
    if (!fwdCls) return;
    UIViewController *vc = [fwdCls new];
    vc.title = LLang(@"选择聊天");
    void (^onConfirm)(NSArray *) = ^(NSArray *channels) {
        [self performForwardToChannels:channels content:content];
    };
    [vc setValue:onConfirm forKey:@"onConfirmChannels"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)performForwardToChannels:(NSArray *)channels content:(NSString *)content {
    if (channels.count == 0) return;
    NSInteger okCount = 0, failCount = 0;
    for (id ch in channels) {
        if (![ch isKindOfClass:WKChannel.class]) { failCount++; continue; }
        WKTextContent *tc = [[WKTextContent alloc] initWithContent:content];
        WKMessage *msg = [[WKSDK shared].chatManager sendMessage:tc channel:(WKChannel *)ch];
        if (msg) okCount++; else failCount++;
    }
    NSString *msg;
    if (failCount == 0) msg = [NSString stringWithFormat:LLang(@"已转发到 %ld 个聊天"), (long)okCount];
    else                msg = [NSString stringWithFormat:LLang(@"成功 %ld / 失败 %ld"), (long)okCount, (long)failCount];
    [self.view showHUDWithHide:msg];
}

- (void)onWaitingAction {
    OctoSummaryConfirmVC *vc = [OctoSummaryConfirmVC new];
    vc.detail = self.detail;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
