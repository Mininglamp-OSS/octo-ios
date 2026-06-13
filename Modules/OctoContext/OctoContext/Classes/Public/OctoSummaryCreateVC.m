//
//  OctoSummaryCreateVC.m
//  OctoContext
//

#import "OctoSummaryCreateVC.h"
#import "OctoSummaryAPI.h"
#import "OctoSelectedSourcesView.h"
#import <WuKongBase/WuKongBase.h>
#import <WuKongBase/WKThreadService.h>
#import <WuKongBase/WKThreadModel.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

#pragma mark - Constants

static const CGFloat kTopicCardMinH    = 220;   // 主题卡最小高度: 输入区 + chip 行
static const CGFloat kTopicChipsH      = 32;    // chip 行高度(含上下 padding)
static const CGFloat kTopicChipsBottom = 12;
static const CGFloat kSourceCardMinH   = 78;    // "选择聊天" 卡最小高度

@interface OctoSummaryCreateVC () <UITextViewDelegate>

// Topic 卡: 输入框 + 横向滚动模板 chip 行
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) UIView *topicCard;
@property(nonatomic, strong) UITextView *topicTextView;
@property(nonatomic, strong) UILabel *topicPlaceholder;
@property(nonatomic, strong) UIScrollView *chipScroll;
@property(nonatomic, strong) NSMutableArray<UIControl *> *chipButtons;
@property(nonatomic, strong) NSArray<OctoTopicTemplate *> *templates;
@property(nonatomic, copy, nullable) NSString *activeTemplateId;

// 来源卡 + 选中流式列表
@property(nonatomic, strong) UIView *sourceCard;
@property(nonatomic, strong) UILabel *sourceFieldLabel;
@property(nonatomic, strong) UILabel *sourcePlaceholder;
@property(nonatomic, strong) UIButton *sourceChevronBtn;     // 仅这个按钮触发选择, 非整卡
@property(nonatomic, strong) OctoSelectedSourcesView *sourcesPills;
@property(nonatomic, strong) NSMutableArray<OctoSourceItem *> *selectedSources;

// 顶栏按钮 (closeBtn 已移除, 走 WKBaseVC 自动 backButton)
@property(nonatomic, strong) UIButton *submitBtn;
@end

@implementation OctoSummaryCreateVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor systemBackgroundColor]
            : [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF7/255.0 alpha:1.0];
    }];
    self.navigationBar.title = LLang(@"创建总结");

    self.selectedSources = [NSMutableArray array];

    [self buildNavButtons];
    self.scroll = [UIScrollView new];
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];

    [self buildTopicCard];
    [self buildSourceCard];
    [self loadTemplates];

    // 编辑取消/失败任务路径: 把上一次的主题 + 已选 sources 注入, 用户改完后点开始
    // 走的是 createSummary (产生新 task), 后端语义就是"换个主题再跑一遍"。
    [self applyPrefillIfAny];
}

- (void)applyPrefillIfAny {
    if (self.prefilledTopic.length > 0) {
        self.topicTextView.text = self.prefilledTopic;
        self.topicPlaceholder.hidden = YES;
    }
    if (self.prefilledSources.count > 0) {
        [self.selectedSources removeAllObjects];
        [self.selectedSources addObjectsFromArray:self.prefilledSources];
        self.sourcesPills.items = self.selectedSources;
        // 子区 sourceName 兜底: 上游 (聊天详情入口 / 列表编辑回流) 没拿到子区真名,
        // 给的是空字符串或 channelId (含 "____"), 这里统一按 sourceType==Thread 走
        // WKThreadService 异步回填, 与 picker 路径同口径。
        for (OctoSourceItem *s in self.selectedSources) {
            if (s.sourceType != OctoSourceThread) continue;
            BOOL looksHex = [s.sourceName rangeOfString:@"____"].location != NSNotFound
                          || [s.sourceName isEqualToString:s.sourceId];
            if (s.sourceName.length > 0 && !looksHex) continue;
            s.sourceName = LLang(@"子区");
            WKChannel *ch = [WKChannel channelID:s.sourceId channelType:WK_COMMUNITY_TOPIC];
            [self resolveThreadName:s forChannel:ch];
        }
        self.sourcesPills.items = self.selectedSources;
        [self.view setNeedsLayout];
    }
    [self updateSubmitState];
}

#pragma mark - Nav buttons

- (void)buildNavButtons {
    // 左上不再放自定义 ✕。WKBaseVC.viewDidLoad 检测到 viewControllers.count >= 2 时
    // 会自动 setShowBackButton:YES, 走系统返回箭头 + WKNavigationManager pop, 不必在
    // 这里再覆盖 leftView (覆盖反而会把 back arrow 盖掉)。

    self.submitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.submitBtn setTitle:LLang(@"开始总结") forState:UIControlStateNormal];
    // 文字颜色用 systemBackgroundColor 与 labelColor 反向配对: 浅色态 = 白底/黑字 → 反过来就是
    // 黑底/白字; 深色态 = 黑底/白字 → 反过来就是 白底/黑字。两态对比度都自然成立。
    [self.submitBtn setTitleColor:[UIColor systemBackgroundColor] forState:UIControlStateNormal];
    self.submitBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.submitBtn.backgroundColor = [UIColor labelColor];
    self.submitBtn.layer.cornerRadius = 16;
    self.submitBtn.contentEdgeInsets = UIEdgeInsetsMake(5, 16, 5, 16);
    self.submitBtn.alpha = 0.5;
    self.submitBtn.enabled = NO;
    [self.submitBtn addTarget:self action:@selector(onSubmit) forControlEvents:UIControlEventTouchUpInside];
    [self.submitBtn sizeToFit];
    CGRect bf = self.submitBtn.frame; bf.size.height = 32;
    self.submitBtn.frame = bf;
    self.submitBtn.layer.cornerRadius = 16;
    self.navigationBar.rightView = self.submitBtn;
}

#pragma mark - Topic card

- (void)buildTopicCard {
    self.topicCard = [UIView new];
    self.topicCard.backgroundColor = [UIColor systemBackgroundColor];
    self.topicCard.layer.cornerRadius = 16;
    [self.scroll addSubview:self.topicCard];

    self.topicTextView = [UITextView new];
    self.topicTextView.font = [UIFont systemFontOfSize:18];
    self.topicTextView.textColor = [UIColor labelColor];
    self.topicTextView.delegate = self;
    self.topicTextView.backgroundColor = [UIColor clearColor];
    self.topicTextView.scrollEnabled = NO;
    self.topicTextView.textContainerInset = UIEdgeInsetsZero;
    self.topicTextView.textContainer.lineFragmentPadding = 0;
    [self.topicCard addSubview:self.topicTextView];

    self.topicPlaceholder = [UILabel new];
    self.topicPlaceholder.text = LLang(@"请输入你想总结的主题");
    self.topicPlaceholder.font = [UIFont systemFontOfSize:18];
    self.topicPlaceholder.textColor = [UIColor.labelColor colorWithAlphaComponent:0.3];
    [self.topicCard addSubview:self.topicPlaceholder];

    // chip 横向滚动条 —— 嵌在 topicCard 底部
    self.chipScroll = [UIScrollView new];
    self.chipScroll.showsHorizontalScrollIndicator = NO;
    self.chipScroll.alwaysBounceHorizontal = YES;
    [self.topicCard addSubview:self.chipScroll];

    self.chipButtons = [NSMutableArray array];
}

#pragma mark - Source card

- (void)buildSourceCard {
    self.sourceCard = [UIView new];
    self.sourceCard.backgroundColor = [UIColor systemBackgroundColor];
    self.sourceCard.layer.cornerRadius = 12;
    // 不再给整卡挂 tap gesture —— 否则点 pill 上的 ✕ 删除时也会误触发选择页。
    // 仅右侧 chevron 区域的 sourceChevronBtn 触发选择, pill 区域的 ✕ 走 OctoSelectedSourcesView.onRemove。
    [self.scroll addSubview:self.sourceCard];

    self.sourceFieldLabel = [UILabel new];
    self.sourceFieldLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    NSMutableAttributedString *att = [[NSMutableAttributedString alloc] initWithString:LLang(@"选择聊天")];
    [att appendAttributedString:[[NSAttributedString alloc] initWithString:@" *" attributes:@{NSForegroundColorAttributeName: [UIColor systemRedColor]}]];
    self.sourceFieldLabel.attributedText = att;
    [self.sourceCard addSubview:self.sourceFieldLabel];

    self.sourcePlaceholder = [UILabel new];
    self.sourcePlaceholder.text = LLang(@"请选择");
    self.sourcePlaceholder.font = [UIFont systemFontOfSize:14];
    self.sourcePlaceholder.textColor = [UIColor.labelColor colorWithAlphaComponent:0.3];
    [self.sourceCard addSubview:self.sourcePlaceholder];

    self.sourceChevronBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.sourceChevronBtn setImage:[UIImage systemImageNamed:@"chevron.right"] forState:UIControlStateNormal];
    self.sourceChevronBtn.tintColor = [UIColor.labelColor colorWithAlphaComponent:0.3];
    [self.sourceChevronBtn addTarget:self action:@selector(onPickSource) forControlEvents:UIControlEventTouchUpInside];
    [self.sourceCard addSubview:self.sourceChevronBtn];

    self.sourcesPills = [[OctoSelectedSourcesView alloc] initWithFrame:CGRectZero];
    self.sourcesPills.maxRows = 3;
    __weak typeof(self) weakSelf = self;
    self.sourcesPills.onRemove = ^(OctoSourceItem *item) {
        [weakSelf removeSource:item];
    };
    [self.sourceCard addSubview:self.sourcesPills];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = CGRectGetMaxY(self.navigationBar.frame);
    self.scroll.frame = CGRectMake(0, top,
                                   self.view.bounds.size.width,
                                   self.view.bounds.size.height - top);

    CGFloat w = self.view.bounds.size.width - 32;

    // === Topic card ===
    // 输入区高度 = 卡总高 - chip 行 - chip 底 padding - 输入顶 padding(12)
    CGFloat textViewMinH = kTopicCardMinH - kTopicChipsH - kTopicChipsBottom - 12;
    self.topicCard.frame = CGRectMake(16, 12, w, kTopicCardMinH);
    self.topicTextView.frame = CGRectMake(12, 12, w - 24, textViewMinH);
    self.topicPlaceholder.frame = CGRectMake(12, 12, w - 24, 26);
    self.chipScroll.frame = CGRectMake(0,
                                       kTopicCardMinH - kTopicChipsH - kTopicChipsBottom,
                                       w, kTopicChipsH);
    [self layoutChips];

    // === Source card ===
    // 高度 = 78 (label + placeholder) + pills 高度 (有选中时);宽度撑满
    CGFloat pillsW = w - 24;
    CGFloat pillsH = [self.sourcesPills heightForWidth:pillsW];
    BOOL hasSel = self.selectedSources.count > 0;
    CGFloat sourceCardH = hasSel ? (12 + 22 + 8 + pillsH + 12) : kSourceCardMinH;
    self.sourceCard.frame = CGRectMake(16, CGRectGetMaxY(self.topicCard.frame) + 8, w, sourceCardH);
    self.sourceFieldLabel.frame = CGRectMake(12, 12, w - 24, 22);
    if (hasSel) {
        self.sourcePlaceholder.hidden = YES;
        self.sourcesPills.hidden = NO;
        self.sourcesPills.frame = CGRectMake(12, 12 + 22 + 8, pillsW, pillsH);
        self.sourceChevronBtn.frame = CGRectMake(w - 44, 4, 40, 40);
    } else {
        self.sourcePlaceholder.hidden = NO;
        self.sourcesPills.hidden = YES;
        self.sourcePlaceholder.frame = CGRectMake(12, 46, w - 40, 20);
        self.sourceChevronBtn.frame = CGRectMake(w - 44, (kSourceCardMinH - 40) / 2.0, 40, 40);
    }

    self.scroll.contentSize = CGSizeMake(w, CGRectGetMaxY(self.sourceCard.frame) + 24);
}

#pragma mark - Chips

- (NSString *)iconAssetForTemplateId:(NSString *)tid {
    if ([tid isEqualToString:@"weekly_report"])    return @"octo-tpl-calendar";
    if ([tid isEqualToString:@"chat_content"])     return @"octo-tpl-message-square";
    if ([tid isEqualToString:@"project_progress"]) return @"octo-tpl-file-text";
    if ([tid isEqualToString:@"task_tracking"])    return @"octo-tpl-list-checks";
    return @"octo-tpl-file-text";
}

- (UIImage *)imageForChipAsset:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSURL *imgBundleURL = [bundle URLForResource:@"OctoContext_images" withExtension:@"bundle"];
    NSBundle *imgBundle = imgBundleURL ? [NSBundle bundleWithURL:imgBundleURL] : bundle;
    UIImage *img = [UIImage imageNamed:name inBundle:imgBundle compatibleWithTraitCollection:nil];
    // 兜底: 全局 main bundle 搜一次, 防止 imageset 被异常拷到 framework 外层
    if (!img) img = [UIImage imageNamed:name];
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

/// chip 改用 UIControl + UIImageView + UILabel 手工布局, 不走 UIButton 的
/// imageEdgeInsets/titleEdgeInsets/contentEdgeInsets 三件套(同 FAB 老坑:
/// sizeToFit 会把图标压扁或文字截断)。
- (UIControl *)chipControlForTemplate:(OctoTopicTemplate *)tpl active:(BOOL)active {
    UIControl *chip = [UIControl new];
    UIColor *fg = active
        ? [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0]
        : [UIColor labelColor];
    chip.backgroundColor = active
        ? [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:0.10]
        : [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
              return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                  ? [UIColor tertiarySystemBackgroundColor]
                  : [UIColor whiteColor];
          }];
    chip.layer.borderWidth = 1;
    chip.layer.borderColor = active
        ? [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:0.18].CGColor
        : [UIColor.labelColor colorWithAlphaComponent:0.08].CGColor;

    UIImageView *iv = [UIImageView new];
    iv.image = [self imageForChipAsset:[self iconAssetForTemplateId:tpl.templateId]];
    iv.tintColor = fg;
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tag = 901;
    [chip addSubview:iv];

    UILabel *l = [UILabel new];
    l.text = tpl.label;
    l.font = [UIFont systemFontOfSize:13];
    l.textColor = fg;
    l.tag = 902;
    [chip addSubview:l];
    return chip;
}

/// chip 几何: hPad 12 + iconSize 14 + gap 6 + ceil(label.width) + hPad 12, 高 28。
+ (CGSize)chipSizeForTemplate:(OctoTopicTemplate *)tpl {
    UIFont *f = [UIFont systemFontOfSize:13];
    CGSize ts = [tpl.label sizeWithAttributes:@{NSFontAttributeName: f}];
    CGFloat w = 12 + 14 + 6 + ceilf(ts.width) + 12;
    return CGSizeMake(w, 28);
}

- (void)layoutChips {
    CGFloat x = 16;
    CGFloat chipH = 28;
    CGFloat chipY = (kTopicChipsH - chipH) / 2.0;
    for (NSInteger i = 0; i < (NSInteger)self.chipButtons.count; i++) {
        UIControl *chip = self.chipButtons[i];
        OctoTopicTemplate *tpl = self.templates[i];
        CGSize sz = [OctoSummaryCreateVC chipSizeForTemplate:tpl];
        chip.frame = CGRectMake(x, chipY, sz.width, sz.height);
        chip.layer.cornerRadius = sz.height / 2.0;
        UIImageView *iv = (UIImageView *)[chip viewWithTag:901];
        UILabel *l = (UILabel *)[chip viewWithTag:902];
        iv.frame = CGRectMake(12, (sz.height - 14) / 2.0, 14, 14);
        CGFloat lx = 12 + 14 + 6;
        l.frame = CGRectMake(lx, 0, sz.width - lx - 12, sz.height);
        x += sz.width + 8;
    }
    self.chipScroll.contentSize = CGSizeMake(x, kTopicChipsH);
}

- (void)renderChips {
    for (UIView *sub in self.chipScroll.subviews) [sub removeFromSuperview];
    [self.chipButtons removeAllObjects];
    NSInteger maxN = MIN(self.templates.count, (NSUInteger)8);
    for (NSInteger i = 0; i < maxN; i++) {
        OctoTopicTemplate *t = self.templates[i];
        BOOL active = [self.activeTemplateId isEqualToString:t.templateId];
        UIControl *chip = [self chipControlForTemplate:t active:active];
        chip.tag = i;
        [chip addTarget:self action:@selector(onChipTap:) forControlEvents:UIControlEventTouchUpInside];
        [self.chipScroll addSubview:chip];
        [self.chipButtons addObject:chip];
    }
    [self.view setNeedsLayout];
}

- (void)loadTemplates {
    // 离线 fallback: 与 web 同一套, 后端取不到时也能用
    NSArray<NSDictionary *> *fallback = @[
        @{@"id": @"project_progress",@"label": LLang(@"项目进展"), @"pattern": LLang(@"总结{project_name}的项目进展"), @"type": @"parameterized",
          @"placeholders": @[@{@"key": @"project_name", @"label": LLang(@"项目名称")}]},
        @{@"id": @"task_tracking",  @"label": LLang(@"跟踪进度"), @"pattern": LLang(@"总结{task_name}的进度"), @"type": @"parameterized",
          @"placeholders": @[@{@"key": @"task_name", @"label": LLang(@"任务名称")}]},
        @{@"id": @"weekly_report",  @"label": LLang(@"团队周报"), @"pattern": LLang(@"总结本周工作汇报"), @"type": @"fixed"},
        @{@"id": @"chat_content",   @"label": LLang(@"总结聊天"), @"pattern": LLang(@"总结这个聊天的关键内容"), @"type": @"fixed"},
    ];
    NSMutableArray *templates = [NSMutableArray array];
    for (NSDictionary *d in fallback) {
        OctoTopicTemplate *t = [OctoTopicTemplate modelFromDict:d];
        if (t) [templates addObject:t];
    }
    self.templates = templates;
    [self renderChips];

    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] getTopicTemplates:^(id _Nullable result, NSError * _Nullable error) {
        if (error || !result) return;
        // strong-capture: 用户在 templates API 返回前 pop 掉本页时, weakSelf=nil →
        // [nil localizeKnownTemplate:t] 返回 nil → [localized addObject:nil] 抛
        // NSInvalidArgumentException。慢网 + 快速返回是真实可达路径, 这里 hard-fail。
        __strong typeof(weakSelf) ss = weakSelf;
        if (!ss) return;
        NSArray *arr = result;
        if (arr.count == 0) return;
        // 后端返回的 label/pattern 多半是中文 (取决于后端 i18n)。已知 id (weekly_report /
        // chat_content / project_progress / task_tracking) 用前端本地化键覆盖, 切到英文
        // 模式时 chip 文字 + 点击后插入的 pattern 也是英文。未知 id 保留原始 API 文案。
        NSMutableArray *localized = [NSMutableArray array];
        for (OctoTopicTemplate *t in arr) {
            OctoTopicTemplate *m = [ss localizeKnownTemplate:t];
            if (m) [localized addObject:m];
        }
        ss.templates = localized;
        [ss renderChips];
    }];
}

/// 已知 4 个模板 id → 前端 LLang 键。后端加新模板(unknown id)时直接保留原始 API 字段。
- (OctoTopicTemplate *)localizeKnownTemplate:(OctoTopicTemplate *)t {
    static NSDictionary *known = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        known = @{
            @"weekly_report":    @[@"团队周报", @"总结本周工作汇报"],
            @"chat_content":     @[@"总结聊天", @"总结这个聊天的关键内容"],
            @"project_progress": @[@"项目进展", @"总结{project_name}的项目进展"],
            @"task_tracking":    @[@"跟踪进度", @"总结{task_name}的进度"],
        };
    });
    NSArray<NSString *> *keys = known[t.templateId];
    if (!keys) return t;
    OctoTopicTemplate *m = [OctoTopicTemplate new];
    m.templateId  = t.templateId;
    m.icon        = t.icon;
    m.desc        = t.desc;
    m.type        = t.type;
    m.placeholders = t.placeholders;
    m.label   = LLang(keys[0]);
    m.pattern = LLang(keys[1]);
    return m;
}

/// 点 chip:
///  - parameterized: 把 pattern 中的 {key} 整段去掉留空, 把光标定位到原 {key} 处, 弹键盘
///  - fixed: 直接把 pattern 写入输入框, 光标移到末尾, 不弹键盘 (无空可填)
- (void)onChipTap:(UIControl *)c {
    OctoTopicTemplate *tpl = self.templates[c.tag];
    self.activeTemplateId = tpl.templateId;
    [self renderChips];

    NSString *pattern = tpl.pattern ?: tpl.label;
    if ([tpl.type isEqualToString:@"parameterized"]) {
        NSRange r = [pattern rangeOfString:@"{"];
        NSRange end = [pattern rangeOfString:@"}"];
        NSInteger caret = pattern.length;
        NSString *cleaned = pattern;
        if (r.location != NSNotFound && end.location != NSNotFound && end.location > r.location) {
            caret = (NSInteger)r.location;
            NSRange placeholder = NSMakeRange(r.location, end.location - r.location + 1);
            cleaned = [pattern stringByReplacingCharactersInRange:placeholder withString:@""];
        }
        self.topicTextView.text = cleaned;
        self.topicPlaceholder.hidden = (cleaned.length > 0);
        // selectedRange 必须在 becomeFirstResponder 之后再设, 否则首次切 first responder
        // 时 UITextView 会把 cursor 重置到末尾(用户报"第一次点击光标在末尾, 第二次才正确")。
        // dispatch_async 到下一轮 runloop, 让 first responder 与文本变更引发的内部
        // selection 重置先稳定下来, 我们再覆盖最终位置。
        [self.topicTextView becomeFirstResponder];
        __weak typeof(self) ws = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            ws.topicTextView.selectedRange = NSMakeRange(caret, 0);
        });
    } else {
        self.topicTextView.text = pattern;
        self.topicTextView.selectedRange = NSMakeRange(pattern.length, 0);
        self.topicPlaceholder.hidden = (pattern.length > 0);
    }
    [self updateSubmitState];
}

#pragma mark - TextView

- (void)textViewDidChange:(UITextView *)textView {
    self.topicPlaceholder.hidden = (textView.text.length > 0);
    [self updateSubmitState];
}

- (void)updateSubmitState {
    BOOL ok = self.topicTextView.text.length > 0 && self.selectedSources.count > 0;
    self.submitBtn.alpha = ok ? 1.0 : 0.5;
    self.submitBtn.enabled = ok;
}

#pragma mark - Source pick (复用 WKForwardSelectVC, 默认即多选; 携带预选)

- (void)onPickSource {
    Class fwdCls = NSClassFromString(@"WKForwardSelectVC");
    if (!fwdCls) return;
    UIViewController *vc = [fwdCls new];
    vc.title = LLang(@"选择聊天");

    // 把当前已选 sources 反向转成 WKChannel 数组传进去, 进入页面默认勾选, 用户做"二次编辑"。
    NSMutableArray<WKChannel *> *preselected = [NSMutableArray array];
    for (OctoSourceItem *s in self.selectedSources) {
        NSInteger ct;
        switch (s.sourceType) {
            case OctoSourceDirectMessage: ct = WK_PERSON; break;
            case OctoSourceThread:        ct = WK_COMMUNITY_TOPIC; break;
            default:                      ct = WK_GROUP; break;
        }
        WKChannel *ch = [WKChannel channelID:s.sourceId channelType:ct];
        if (ch) [preselected addObject:ch];
    }
    [vc setValue:preselected forKey:@"preselectedChannels"];

    void (^onConfirm)(NSArray *) = ^(NSArray *channels) {
        [self acceptPickedChannels:channels];
    };
    [vc setValue:onConfirm forKey:@"onConfirmChannels"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)acceptPickedChannels:(NSArray *)channels {
    [self.selectedSources removeAllObjects];
    for (id c in channels) {
        if (![c isKindOfClass:WKChannel.class]) continue;
        WKChannel *ch = (WKChannel *)c;
        OctoSourceItem *s = [OctoSourceItem new];
        s.sourceId = ch.channelId;
        if (ch.channelType == WK_PERSON) {
            s.sourceType = OctoSourceDirectMessage;
        } else if (ch.channelType == WK_COMMUNITY_TOPIC) {
            s.sourceType = OctoSourceThread;
        } else {
            s.sourceType = OctoSourceGroupChat;
        }
        WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:ch];
        NSString *name = info.name.length > 0 ? info.name : nil;
        // 子区的 ChannelInfo.name 经常为空 (WKSDK channelManager 不缓存 thread 名),
        // 直接退到 channelId (groupNo____shortId) 看起来像 16 进制串。改用 WKThreadService
        // 异步查 thread 名回填; 之前先用 LLang(@"子区") 占位, 不让用户看到 hex。
        if (s.sourceType == OctoSourceThread && name.length == 0) {
            s.sourceName = LLang(@"子区");
            [self resolveThreadName:s forChannel:ch];
        } else {
            s.sourceName = name.length > 0 ? name : ch.channelId;
        }
        [self.selectedSources addObject:s];
    }
    self.sourcesPills.items = self.selectedSources;
    [self updateSubmitState];
    [self.view setNeedsLayout];
}

/// 子区名异步回填: 解析 channelId 为 (groupNo, shortId), 从 WKThreadService 拉到
/// 子区详情后把 sourceName 替换成真实名字, 同时刷一遍 pill 视图。promise reject 静默,
/// 占位 "子区" 仍然比 hex channelId 友好。
- (void)resolveThreadName:(OctoSourceItem *)source forChannel:(WKChannel *)ch {
    NSArray *parts = [ch.channelId componentsSeparatedByString:@"____"];
    if (parts.count < 2) return;
    NSString *groupNo = parts[0];
    NSString *shortId = parts[1];
    if (groupNo.length == 0 || shortId.length == 0) return;
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] getThread:groupNo shortId:shortId].then(^(WKThreadModel *t) {
        __strong typeof(weakSelf) ws = weakSelf;
        if (!ws || t.name.length == 0) return;
        // 选源数组在用户编辑时可能已变, 用 channelId+sourceType 反查避免改错对象。
        NSInteger idx = [ws.selectedSources indexOfObjectPassingTest:^BOOL(OctoSourceItem *it, NSUInteger i, BOOL *stop) {
            return it.sourceType == OctoSourceThread && [it.sourceId isEqualToString:source.sourceId];
        }];
        if (idx == NSNotFound) return;
        ws.selectedSources[idx].sourceName = t.name;
        ws.sourcesPills.items = ws.selectedSources;
    }).catch(^(NSError *e) {});
}

- (void)removeSource:(OctoSourceItem *)src {
    NSInteger i = [self.selectedSources indexOfObjectPassingTest:^BOOL(OctoSourceItem *o, NSUInteger idx, BOOL *stop) {
        return o.sourceType == src.sourceType && [o.sourceId isEqualToString:src.sourceId];
    }];
    if (i == NSNotFound) return;
    [self.selectedSources removeObjectAtIndex:i];
    self.sourcesPills.items = self.selectedSources;
    [self updateSubmitState];
    [self.view setNeedsLayout];
}

#pragma mark - Submit

- (void)onSubmit {
    self.submitBtn.enabled = NO;
    NSMutableArray *sourcesArr = [NSMutableArray array];
    for (OctoSourceItem *s in self.selectedSources) [sourcesArr addObject:[s toDict]];
    NSDictionary *params = @{
        @"topic": self.topicTextView.text ?: @"",
        @"summary_mode": @(OctoSummaryModeByGroup),
        @"sources": sourcesArr,
        @"origin_channel_id": self.originChannelId ?: @"",
        @"origin_channel_type": @(self.originChannelType),
    };
    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] createSummaryWithParams:params callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) {
            weakSelf.submitBtn.enabled = YES;
            [weakSelf.view showHUDWithHide:error.localizedDescription ?: LLang(@"创建失败")];
            return;
        }
        NSString *successText = weakSelf.submitSuccessHUDText.length > 0
            ? weakSelf.submitSuccessHUDText
            : LLang(@"已创建总结任务");
        // 通知列表页刷新, 让新任务立刻出现在列表顶部 (用户报"返回到列表后看不到新建的总结")。
        [[NSNotificationCenter defaultCenter] postNotificationName:@"OctoSummaryDidCreateNotification" object:nil];
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
        // HUD 必须放在 pop 之后, 且挂在 pop 后的 topViewController.view (列表页 / 聊天详情页)
        // 上 —— 之前挂在 weakSelf.view, pop 把 createVC 的视图层级即刻拆掉, HUD 还没动画
        // 完就跟着销毁, 用户什么也看不到。dispatch_async 一格让 nav stack 切完再取 top,
        // 避免拿到尚未切换的旧 top。
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *top = [WKNavigationManager shared].topViewController;
            UIView *target = top.view ?: UIApplication.sharedApplication.keyWindow;
            [target showHUDWithHide:successText];
        });
    }];
}

@end
