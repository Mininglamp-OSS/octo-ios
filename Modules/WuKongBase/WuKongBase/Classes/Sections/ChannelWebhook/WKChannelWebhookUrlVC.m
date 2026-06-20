//
//  WKChannelWebhookUrlVC.m
//  WuKongBase
//

#import "WKChannelWebhookUrlVC.h"
#import "WuKongBase.h"
#import "WKIncomingWebhook.h"
#import <objc/runtime.h>

#define WK_WURL_H_PAD 16.0f
#define WK_WURL_CODE_FONT_SIZE 12.0f
#define WK_WURL_BODY_FONT_SIZE 14.0f

@interface WKChannelWebhookUrlVC ()
@property(nonatomic,strong) UIScrollView *scrollView;
@property(nonatomic,strong) UIView *bottomBar;
@property(nonatomic,strong) UIButton *doneBtn;

// 复制状态反馈（每个独立计时器）
@property(nonatomic,strong) NSMutableDictionary<NSString *, UIButton *> *feedbackBtns;
@property(nonatomic,strong) NSMutableDictionary<NSString *, NSString *> *feedbackOrigTitles;
@end

@implementation WKChannelWebhookUrlVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.feedbackBtns = [NSMutableDictionary dictionary];
    self.feedbackOrigTitles = [NSMutableDictionary dictionary];

    [self buildHeaderBar];
    [self.view addSubview:self.scrollView];
    [self.view addSubview:self.bottomBar];

    [self renderContent];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat barH = 64.0f + self.view.safeAreaInsets.bottom;
    self.bottomBar.frame = CGRectMake(0, self.view.lim_height - barH, self.view.lim_width, barH);
    self.doneBtn.frame = CGRectMake(WK_WURL_H_PAD, 12, self.view.lim_width - WK_WURL_H_PAD * 2, 44);

    CGFloat topInset = 44 + 6; // 标题栏高度近似
    self.scrollView.frame = CGRectMake(0, topInset, self.view.lim_width, self.view.lim_height - topInset - barH);
}

#pragma mark - 自管 title bar（present 模式没有 UINavigationController）

- (void)buildHeaderBar {
    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [WKApp shared].config.backgroundColor;
    [self.view addSubview:bar];

    UILabel *titleLbl = [UILabel new];
    titleLbl.text = LLang(@"Webhook 创建成功");
    titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    titleLbl.font = [[WKApp shared].config appFontOfSize:17.0f];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [bar addSubview:titleLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:LLang(@"完成") forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:15.0f];
    [closeBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(onClosePressed) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:closeBtn];

    // 用 frame 而非 autolayout，与项目其余模块风格统一
    CGFloat W = self.view.lim_width;
    bar.frame = CGRectMake(0, 0, W, 44);
    titleLbl.frame = CGRectMake(80, 8, W - 160, 28);
    closeBtn.frame = CGRectMake(W - 70, 6, 60, 32);

    // 分割线
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 43.5, W, 0.5)];
    line.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.2];
    [bar addSubview:line];
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.backgroundColor = [WKApp shared].config.backgroundColor;
        _scrollView.alwaysBounceVertical = YES;
    }
    return _scrollView;
}

- (UIView *)bottomBar {
    if (!_bottomBar) {
        _bottomBar = [[UIView alloc] init];
        _bottomBar.backgroundColor = [WKApp shared].config.backgroundColor;
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1000, 0.5)];
        line.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.2];
        line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_bottomBar addSubview:line];

        _doneBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _doneBtn.backgroundColor = [WKApp shared].config.themeColor;
        [_doneBtn setTitle:LLang(@"我已复制并保存，关闭") forState:UIControlStateNormal];
        [_doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _doneBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
        _doneBtn.layer.cornerRadius = 10;
        _doneBtn.layer.masksToBounds = YES;
        [_doneBtn addTarget:self action:@selector(onClosePressed) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:_doneBtn];
    }
    return _bottomBar;
}

- (void)onClosePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Content

- (NSString *)apiBaseUrl {
    return [WKApp shared].config.apiBaseUrl ?: @"";
}

- (NSString *)absUrlOrEmpty:(NSString *)rel {
    return WKIncomingWebhookAbsoluteURL(rel, [self apiBaseUrl]);
}

- (void)renderContent {
    CGFloat W = self.view.lim_width;
    CGFloat y = 12.0f;

    // 顶部红色警示横条
    UIView *warning = [self warningBannerAtY:y width:W];
    [self.scrollView addSubview:warning];
    y = CGRectGetMaxY(warning.frame) + 12;

    // Webhook 地址卡片
    NSString *nativeAbs = [self absUrlOrEmpty:(self.webhook.urlNative.length > 0 ? self.webhook.urlNative : self.webhook.url)];
    UIView *addrCard = [self urlCardAtY:y
                                  width:W
                                  title:LLang(@"Webhook 地址")
                                    url:nativeAbs
                              feedbackKey:@"url:native"];
    [self.scrollView addSubview:addrCard];
    y = CGRectGetMaxY(addrCard.frame) + 18;

    // 「调用示例」分节标题
    UILabel *examplesTitle = [UILabel new];
    examplesTitle.frame = CGRectMake(WK_WURL_H_PAD + 8, y, W - WK_WURL_H_PAD * 2 - 8, 22);
    examplesTitle.text = LLang(@"调用示例");
    examplesTitle.font = [[WKApp shared].config appFontOfSize:13.0f];
    examplesTitle.textColor = [WKApp shared].config.tipColor;
    [self.scrollView addSubview:examplesTitle];
    y = CGRectGetMaxY(examplesTitle.frame) + 8;

    // 通用 native curl 卡片
    NSString *nativeSample = LLang(@"**构建成功** ✅ 详情见 [#123](https://example.com/build/123)");
    NSString *nativeCurl = [self buildCurlForKey:@"native" url:nativeAbs sample:nativeSample];
    UIView *nativeCard = [self curlCardAtY:y
                                     width:W
                                     title:LLang(@"通用 (native)")
                                  codeText:nativeCurl
                                      note:LLang(@"content 按 Markdown 渲染。")
                               feedbackKey:@"example:native"];
    [self.scrollView addSubview:nativeCard];
    y = CGRectGetMaxY(nativeCard.frame) + 12;

    // GitHub 卡片
    NSString *githubAbs = [self absUrlOrEmpty:self.webhook.urlGithub];
    if (githubAbs.length > 0) {
        UIView *ghCard = [self githubCardAtY:y width:W url:githubAbs];
        [self.scrollView addSubview:ghCard];
        y = CGRectGetMaxY(ghCard.frame) + 12;
    }

    // 企业微信 curl 卡片
    NSString *wecomAbs = [self absUrlOrEmpty:self.webhook.urlWecom];
    if (wecomAbs.length > 0) {
        NSString *wecomCurl = [self buildCurlForKey:@"wecom" url:wecomAbs sample:LLang(@"构建成功 ✅")];
        UIView *wecomCard = [self curlCardAtY:y
                                        width:W
                                        title:LLang(@"企业微信机器人兼容")
                                     codeText:wecomCurl
                                         note:LLang(@"兼容企业微信群机器人格式，可直接迁移现有机器人 URL。")
                                  feedbackKey:@"example:wecom"];
        [self.scrollView addSubview:wecomCard];
        y = CGRectGetMaxY(wecomCard.frame) + 12;
    }

    self.scrollView.contentSize = CGSizeMake(W, y + 24);
}

#pragma mark - 警示横条

- (UIView *)warningBannerAtY:(CGFloat)y width:(CGFloat)W {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(WK_WURL_H_PAD, y, W - WK_WURL_H_PAD * 2, 0)];
    card.backgroundColor = [UIColor colorWithRed:0xFF/255.0 green:0xF1/255.0 blue:0xF0/255.0 alpha:1.0];
    card.layer.cornerRadius = 8;
    card.layer.masksToBounds = YES;

    UILabel *iconLbl = [UILabel new];
    iconLbl.text = @"⚠️";
    iconLbl.font = [UIFont systemFontOfSize:16];
    iconLbl.frame = CGRectMake(12, 12, 20, 20);
    [card addSubview:iconLbl];

    UILabel *text = [UILabel new];
    text.font = [[WKApp shared].config appFontOfSize:13.0f];
    text.textColor = [UIColor colorWithRed:0xD3/255.0 green:0x3A/255.0 blue:0x2C/255.0 alpha:1.0];
    text.numberOfLines = 0;
    text.text = LLang(@"出于安全考虑，以下地址仅此一次完整展示，请立即复制保存；丢失后只能重置。");
    text.frame = CGRectMake(40, 10, card.lim_width - 52, 0);
    [text sizeToFit];
    text.lim_width = card.lim_width - 52;
    [card addSubview:text];

    card.lim_height = MAX(44, CGRectGetMaxY(text.frame) + 10);
    return card;
}

#pragma mark - URL 卡片

- (UIView *)urlCardAtY:(CGFloat)y width:(CGFloat)W title:(NSString *)title url:(NSString *)url feedbackKey:(NSString *)key {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(WK_WURL_H_PAD, y, W - WK_WURL_H_PAD * 2, 0)];
    card.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    card.layer.cornerRadius = 10;
    card.layer.masksToBounds = YES;

    UILabel *titleLbl = [UILabel new];
    titleLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
    titleLbl.textColor = [WKApp shared].config.tipColor;
    titleLbl.text = title;
    titleLbl.frame = CGRectMake(14, 12, card.lim_width - 100, 18);
    [card addSubview:titleLbl];

    UIButton *copyBtn = [self iconCopyButtonWithFeedbackKey:key payload:url];
    copyBtn.frame = CGRectMake(card.lim_width - 78, 8, 70, 26);
    [card addSubview:copyBtn];

    // 灰底等宽 URL 文本框（UITextView 可选中）
    UITextView *tv = [self selectableCodeTextView];
    tv.text = url;
    CGFloat tvW = card.lim_width - 24;
    CGSize fit = [tv sizeThatFits:CGSizeMake(tvW, CGFLOAT_MAX)];
    tv.frame = CGRectMake(12, 38, tvW, MIN(fit.height + 12, 160));
    [card addSubview:tv];

    // 整张卡片点击触发复制（小图标点不准的兜底）
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onCardTappedToCopy:)];
    objc_setAssociatedObject(card, @selector(onCardTappedToCopy:), @[key, url ?: @""], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [card addGestureRecognizer:tap];

    card.lim_height = CGRectGetMaxY(tv.frame) + 10;
    return card;
}

#pragma mark - curl 卡片（native / wecom）

- (UIView *)curlCardAtY:(CGFloat)y
                  width:(CGFloat)W
                  title:(NSString *)title
               codeText:(NSString *)codeText
                   note:(NSString *)note
            feedbackKey:(NSString *)key {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(WK_WURL_H_PAD, y, W - WK_WURL_H_PAD * 2, 0)];
    card.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    card.layer.cornerRadius = 10;
    card.layer.masksToBounds = YES;

    UILabel *titleLbl = [UILabel new];
    titleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
    titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    titleLbl.text = title;
    titleLbl.frame = CGRectMake(14, 12, card.lim_width - 28, 20);
    [card addSubview:titleLbl];

    // 代码块容器
    UIView *codeBg = [[UIView alloc] init];
    codeBg.backgroundColor = [WKChannelWebhookUrlVC codeBackgroundColor];
    codeBg.layer.cornerRadius = 8;
    codeBg.layer.masksToBounds = YES;
    [card addSubview:codeBg];

    UITextView *tv = [self selectableCodeTextView];
    tv.text = codeText;
    CGFloat tvW = card.lim_width - 24 - 16;
    CGSize fit = [tv sizeThatFits:CGSizeMake(tvW, CGFLOAT_MAX)];
    CGFloat tvH = MIN(fit.height + 6, 220);
    tv.frame = CGRectMake(8, 6, tvW, tvH);
    [codeBg addSubview:tv];
    codeBg.frame = CGRectMake(12, 38, card.lim_width - 24, tvH + 12);

    // 说明文字
    UILabel *noteLbl = [UILabel new];
    noteLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    noteLbl.textColor = [WKApp shared].config.tipColor;
    noteLbl.numberOfLines = 0;
    noteLbl.text = note;
    noteLbl.frame = CGRectMake(14, CGRectGetMaxY(codeBg.frame) + 8, card.lim_width - 28, 0);
    [noteLbl sizeToFit];
    noteLbl.lim_width = card.lim_width - 28;

    [card addSubview:noteLbl];

    // 「复制示例」描边按钮
    UIButton *copyBtn = [self outlineCopyButtonWithFeedbackKey:key payload:codeText title:LLang(@"复制示例")];
    CGFloat btnW = 100, btnH = 32;
    copyBtn.frame = CGRectMake(card.lim_width - 14 - btnW,
                               CGRectGetMaxY(noteLbl.frame) + 10,
                               btnW, btnH);
    [card addSubview:copyBtn];

    card.lim_height = CGRectGetMaxY(copyBtn.frame) + 12;
    return card;
}

#pragma mark - GitHub 卡片

- (UIView *)githubCardAtY:(CGFloat)y width:(CGFloat)W url:(NSString *)url {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(WK_WURL_H_PAD, y, W - WK_WURL_H_PAD * 2, 0)];
    card.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    card.layer.cornerRadius = 10;
    card.layer.masksToBounds = YES;

    UILabel *titleLbl = [UILabel new];
    titleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
    titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    titleLbl.text = LLang(@"GitHub 事件");
    titleLbl.frame = CGRectMake(14, 12, card.lim_width - 28, 20);
    [card addSubview:titleLbl];

    UILabel *intro = [UILabel new];
    intro.font = [[WKApp shared].config appFontOfSize:13.0f];
    intro.textColor = [WKApp shared].config.defaultTextColor;
    intro.numberOfLines = 0;
    intro.text = LLang(@"GitHub 仓库事件无需 curl，把下面这个 Payload URL 登记到仓库 Webhook 设置：");
    intro.frame = CGRectMake(14, CGRectGetMaxY(titleLbl.frame) + 6, card.lim_width - 28, 0);
    [intro sizeToFit];
    intro.lim_width = card.lim_width - 28;
    [card addSubview:intro];

    // URL 框（等宽，selectable）
    UIView *codeBg = [[UIView alloc] init];
    codeBg.backgroundColor = [WKChannelWebhookUrlVC codeBackgroundColor];
    codeBg.layer.cornerRadius = 8;
    codeBg.layer.masksToBounds = YES;
    [card addSubview:codeBg];

    UITextView *tv = [self selectableCodeTextView];
    tv.text = url;
    CGFloat tvW = card.lim_width - 24 - 16;
    CGSize fit = [tv sizeThatFits:CGSizeMake(tvW, CGFLOAT_MAX)];
    tv.frame = CGRectMake(8, 6, tvW, MIN(fit.height + 6, 140));
    [codeBg addSubview:tv];
    codeBg.frame = CGRectMake(12,
                              CGRectGetMaxY(intro.frame) + 10,
                              card.lim_width - 24,
                              tv.lim_height + 12);

    // 复制按钮
    UIButton *copyBtn = [self outlineCopyButtonWithFeedbackKey:@"github:url" payload:url title:LLang(@"复制地址")];
    copyBtn.frame = CGRectMake(card.lim_width - 14 - 100,
                               CGRectGetMaxY(codeBg.frame) + 8,
                               100, 32);
    [card addSubview:copyBtn];

    // 三步说明
    NSArray<NSString *> *steps = @[
        LLang(@"仓库 → Settings → Webhooks → Add webhook"),
        LLang(@"Payload URL 粘贴上面地址，Content type 选 application/json"),
        LLang(@"勾选需要接收的事件（如 push、pull_request），保存"),
    ];
    CGFloat sy = CGRectGetMaxY(copyBtn.frame) + 12;
    for (NSInteger i = 0; i < steps.count; i++) {
        UIView *row = [self stepRowAtY:sy width:card.lim_width index:i + 1 text:steps[i]];
        [card addSubview:row];
        sy = CGRectGetMaxY(row.frame) + 6;
    }

    card.lim_height = sy + 6;
    return card;
}

- (UIView *)stepRowAtY:(CGFloat)y width:(CGFloat)W index:(NSInteger)idx text:(NSString *)text {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(14, y, W - 28, 22)];
    UILabel *badge = [UILabel new];
    badge.text = [NSString stringWithFormat:@"%ld", (long)idx];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.font = [[WKApp shared].config appFontOfSize:11.0f];
    badge.textColor = [WKApp shared].config.themeColor;
    badge.layer.borderWidth = 1;
    badge.layer.borderColor = [WKApp shared].config.themeColor.CGColor;
    badge.layer.cornerRadius = 9;
    badge.layer.masksToBounds = YES;
    badge.frame = CGRectMake(0, 1, 18, 18);
    [row addSubview:badge];

    UILabel *t = [UILabel new];
    t.font = [[WKApp shared].config appFontOfSize:13.0f];
    t.textColor = [WKApp shared].config.defaultTextColor;
    t.numberOfLines = 0;
    t.text = text;
    t.frame = CGRectMake(28, 0, row.lim_width - 28, 0);
    [t sizeToFit];
    t.lim_width = row.lim_width - 28;
    [row addSubview:t];

    row.lim_height = MAX(20, t.lim_height);
    return row;
}

#pragma mark - 通用按钮（图标 / 描边）

- (UIButton *)iconCopyButtonWithFeedbackKey:(NSString *)key payload:(NSString *)payload {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:LLang(@"复制") forState:UIControlStateNormal];
    btn.titleLabel.font = [[WKApp shared].config appFontOfSize:13.0f];
    [btn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [WKApp shared].config.themeColor.CGColor;
    btn.layer.cornerRadius = 13;
    btn.layer.masksToBounds = YES;
    objc_setAssociatedObject(btn, @selector(iconCopyButtonWithFeedbackKey:payload:), @[key, payload ?: @""], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [btn addTarget:self action:@selector(onCopyButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.feedbackBtns[key] = btn;
    self.feedbackOrigTitles[key] = LLang(@"复制");
    return btn;
}

- (UIButton *)outlineCopyButtonWithFeedbackKey:(NSString *)key payload:(NSString *)payload title:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [[WKApp shared].config appFontOfSize:13.0f];
    [btn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [WKApp shared].config.themeColor.CGColor;
    btn.layer.cornerRadius = 8;
    btn.layer.masksToBounds = YES;
    objc_setAssociatedObject(btn, @selector(iconCopyButtonWithFeedbackKey:payload:), @[key, payload ?: @""], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [btn addTarget:self action:@selector(onCopyButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.feedbackBtns[key] = btn;
    self.feedbackOrigTitles[key] = title;
    return btn;
}

- (void)onCopyButtonPressed:(UIButton *)sender {
    NSArray *pair = objc_getAssociatedObject(sender, @selector(iconCopyButtonWithFeedbackKey:payload:));
    if (pair.count < 2) return;
    NSString *key = pair[0];
    NSString *payload = pair[1];
    [self copyText:payload feedbackKey:key];
}

- (void)onCardTappedToCopy:(UITapGestureRecognizer *)gr {
    NSArray *pair = objc_getAssociatedObject(gr.view, @selector(onCardTappedToCopy:));
    if (pair.count < 2) return;
    NSString *key = pair[0];
    NSString *payload = pair[1];
    [self copyText:payload feedbackKey:key];
}

- (void)copyText:(NSString *)text feedbackKey:(NSString *)key {
    if (text.length == 0) return;
    [UIPasteboard generalPasteboard].string = text;
    [self.view showMsg:LLang(@"已复制")];

    UIButton *btn = self.feedbackBtns[key];
    if (!btn) return;
    NSString *orig = self.feedbackOrigTitles[key] ?: LLang(@"复制");
    [btn setTitle:LLang(@"✓ 已复制") forState:UIControlStateNormal];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [btn setTitle:orig forState:UIControlStateNormal];
    });
}

#pragma mark - 可选中等宽代码 TextView

- (UITextView *)selectableCodeTextView {
    UITextView *tv = [[UITextView alloc] init];
    tv.editable = NO;
    tv.selectable = YES;
    tv.scrollEnabled = NO;
    tv.backgroundColor = [UIColor clearColor];
    tv.textContainerInset = UIEdgeInsetsZero;
    tv.textContainer.lineFragmentPadding = 0;
    tv.textContainer.lineBreakMode = NSLineBreakByCharWrapping;
    tv.font = [UIFont fontWithName:@"Menlo" size:WK_WURL_CODE_FONT_SIZE]
              ?: [UIFont monospacedSystemFontOfSize:WK_WURL_CODE_FONT_SIZE weight:UIFontWeightRegular];
    tv.textColor = [WKApp shared].config.defaultTextColor;
    tv.linkTextAttributes = nil;
    tv.dataDetectorTypes = UIDataDetectorTypeNone; // 不识别"链接"再插一层菜单
    return tv;
}

+ (UIColor *)codeBackgroundColor {
    // 跟随 light/dark；项目里没现成"代码块底色"语义色，自定义两套接近 GROUP.md 文本框灰底的值。
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            if (t.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0x1C/255.0 green:0x1C/255.0 blue:0x1E/255.0 alpha:1.0];
            }
            return [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF7/255.0 alpha:1.0];
        }];
    }
    return [UIColor colorWithRed:0xF5/255.0 green:0xF5/255.0 blue:0xF7/255.0 alpha:1.0];
}

#pragma mark - curl 构造（与 web buildWebhookCurlExample 对齐）

- (NSString *)shellQuote:(NSString *)s {
    NSString *escaped = [s stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    return [NSString stringWithFormat:@"'%@'", escaped];
}

- (NSString *)buildCurlForKey:(NSString *)key url:(NSString *)url sample:(NSString *)sample {
    if (url.length == 0) return @"";
    NSDictionary *body;
    if ([key isEqualToString:@"wecom"]) {
        body = @{ @"msgtype": @"text", @"text": @{ @"content": sample ?: @"" } };
    } else {
        body = @{ @"content": sample ?: @"" };
    }
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *bodyJson = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding] ?: @"{}";

    NSString *quotedUrl = [self shellQuote:url];
    NSString *quotedBody = [self shellQuote:bodyJson];
    return [NSString stringWithFormat:@"curl -X POST %@ \\\n  -H 'Content-Type: application/json' \\\n  -d %@",
            quotedUrl, quotedBody];
}

@end
