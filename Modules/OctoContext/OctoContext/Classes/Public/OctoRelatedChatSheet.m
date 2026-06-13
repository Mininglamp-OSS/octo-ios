//
//  OctoRelatedChatSheet.m
//  OctoContext
//

#import "OctoRelatedChatSheet.h"
#import "OctoSummaryDateFormat.h"
#import <WuKongBase/WuKongBase.h>

typedef NS_ENUM(NSInteger, OctoChatRowKind) {
    OctoChatRowKindContextBefore = 0,
    OctoChatRowKindHit           = 1,
    OctoChatRowKindContextAfter  = 2,
};

@interface OctoChatRow : NSObject
@property(nonatomic, assign) OctoChatRowKind kind;
@property(nonatomic, copy) NSString *sender;
@property(nonatomic, copy) NSString *content;
@property(nonatomic, copy) NSString *sentAt;
@property(nonatomic, copy, nullable) NSString *channelId;
@property(nonatomic, assign) NSInteger channelType;
@property(nonatomic, assign) uint32_t messageSeq;
@end
@implementation OctoChatRow @end

@interface OctoRelatedChatSheet () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) NSArray<OctoCitationItem *> *citations;       // 原始全集 (透传)
@property(nonatomic, strong) NSArray<OctoCitationItem *> *relevantCitations; // 命中 activeIndices 后过滤的子集
@property(nonatomic, strong, nullable) NSArray<OctoSourceItem *> *sources;   // detail 的 source 列表, 提供本地名兜底
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *displayNameCache; // channelId → 解析后显示名, viewDidLoad 一次性算完
@property(nonatomic, copy, nullable) NSString *activeChannelId;            // 多 channel 时当前展示的 channel
@property(nonatomic, strong) UIView *handle;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *closeBtn;
@property(nonatomic, strong) UILabel *sourceLabel;
@property(nonatomic, strong) UIScrollView *channelChips;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSArray<NSString *> *channelIdsInUse;
@property(nonatomic, strong) NSMutableArray<OctoChatRow *> *rows;
@end

@implementation OctoRelatedChatSheet

+ (void)presentInVC:(UIViewController *)host
          citations:(NSArray<OctoCitationItem *> *)citations
            sources:(NSArray<OctoSourceItem *> *)sources
      activeIndices:(NSArray<NSNumber *> *)activeIndices {
    OctoRelatedChatSheet *vc = [OctoRelatedChatSheet new];
    vc.citations = citations ?: @[];
    vc.sources = sources;
    // scope: 只保留 activeIndices 命中的 citations, 顶部 channel 切换器与下方 rows 都
    // 基于这个子集计算 —— 用户点 [1-3] 的徽章, 只看到 1/2/3 这三条引用相关的内容,
    // 不再被总结里其它 channel 的无关 citations 干扰。
    NSSet *idxSet = [NSSet setWithArray:activeIndices ?: @[]];
    NSMutableArray<OctoCitationItem *> *relevant = [NSMutableArray array];
    for (OctoCitationItem *c in vc.citations) {
        if ([idxSet containsObject:@(c.index)]) [relevant addObject:c];
    }
    vc.relevantCitations = relevant;
    vc.activeChannelId = relevant.firstObject.channelId;

    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = vc.sheetPresentationController;
        sheet.detents = @[ UISheetPresentationControllerDetent.mediumDetent,
                           UISheetPresentationControllerDetent.largeDetent ];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 16;
    }
    [host presentViewController:vc animated:YES completion:nil];
}

+ (void)presentInVC:(UIViewController *)host
          citations:(NSArray<OctoCitationItem *> *)citations
      activeIndices:(NSArray<NSNumber *> *)activeIndices {
    [self presentInVC:host citations:citations sources:nil activeIndices:activeIndices];
}

/// 兼容入口: 单 citation 包成单元素数组转发。
+ (void)presentInVC:(UIViewController *)host
          citations:(NSArray<OctoCitationItem *> *)citations
        activeIndex:(NSInteger)activeCitationIndex {
    [self presentInVC:host citations:citations sources:nil activeIndices:@[@(activeCitationIndex)]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.handle = [UIView new];
    self.handle.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.15];
    self.handle.layer.cornerRadius = 2;
    [self.view addSubview:self.handle];

    self.closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeBtn setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    self.closeBtn.tintColor = [UIColor.labelColor colorWithAlphaComponent:0.6];
    [self.closeBtn addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeBtn];

    self.titleLabel = [UILabel new];
    self.titleLabel.text = LLang(@"关联聊天记录");
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = [UIColor labelColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.titleLabel];

    self.sourceLabel = [UILabel new];
    self.sourceLabel.font = [UIFont systemFontOfSize:13];
    self.sourceLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.6];
    [self.view addSubview:self.sourceLabel];

    self.channelChips = [UIScrollView new];
    self.channelChips.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:self.channelChips];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 80;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"row"];
    [self.view addSubview:self.tableView];

    [self buildDisplayNameCache];
    [self computeChannelChips];
    [self rebuildRows];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    self.handle.frame = CGRectMake((w - 36) / 2.0, 8, 36, 4);
    self.closeBtn.frame = CGRectMake(16, 16, 28, 28);
    self.titleLabel.frame = CGRectMake(60, 18, w - 120, 24);
    self.sourceLabel.frame = CGRectMake(16, 56, w - 32, 20);
    self.channelChips.frame = CGRectMake(0, 84, w, 36);
    [self layoutChannelChips];
    self.tableView.frame = CGRectMake(0, CGRectGetMaxY(self.channelChips.frame),
                                      w,
                                      self.view.bounds.size.height - CGRectGetMaxY(self.channelChips.frame));
}

#pragma mark - Channels chips (基于 relevantCitations 计算, 不再扫全 citations)

- (void)computeChannelChips {
    NSMutableOrderedSet *uniq = [NSMutableOrderedSet orderedSet];
    for (OctoCitationItem *c in self.relevantCitations) {
        if (c.channelId.length > 0) [uniq addObject:c.channelId];
    }
    self.channelIdsInUse = uniq.array;
}

- (void)layoutChannelChips {
    for (UIView *v in self.channelChips.subviews) [v removeFromSuperview];
    if (self.channelIdsInUse.count <= 1) {
        // 单 channel: 整组 citation 都在同一聊天里, 切换器无意义, 整段隐藏。
        self.channelChips.hidden = YES;
        self.channelChips.frame = CGRectMake(0, 84, self.view.bounds.size.width, 0);
        return;
    }
    self.channelChips.hidden = NO;
    CGFloat x = 16;
    for (NSInteger i = 0; i < self.channelIdsInUse.count; i++) {
        NSString *cid = self.channelIdsInUse[i];
        BOOL active = [cid isEqualToString:self.activeChannelId];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        [b setTitle:[self channelDisplayNameFor:cid] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:13];
        [b setTitleColor:active ? [UIColor whiteColor] : [UIColor labelColor] forState:UIControlStateNormal];
        b.backgroundColor = active
            ? [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0]
            : [UIColor secondarySystemBackgroundColor];
        b.layer.cornerRadius = 14;
        b.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        b.tag = i;
        [b addTarget:self action:@selector(onChannelChip:) forControlEvents:UIControlEventTouchUpInside];
        [b sizeToFit];
        b.frame = CGRectMake(x, 4, b.frame.size.width + 4, 28);
        x += b.frame.size.width + 8;
        [self.channelChips addSubview:b];
    }
    self.channelChips.contentSize = CGSizeMake(x + 16, 36);
}

- (NSString *)channelDisplayNameFor:(NSString *)channelId {
    if (channelId.length == 0) return LLang(@"未知聊天");
    NSString *cached = self.displayNameCache[channelId];
    if (cached.length > 0) return cached;
    return channelId;
}

/// 一次性把所有相关 channelId 的显示名解析好缓存起来。displayNameForCitation: 是
/// 个 ~10 行 NSLog + 多轮 SDK 查找的重活, 之前每次 layoutChannelChips / sourceLabel
/// 重置都会重跑, dismiss 动画期间 viewDidLayoutSubviews 反复触发就把主线程刷死了。
- (void)buildDisplayNameCache {
    self.displayNameCache = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *visited = [NSMutableSet set];
    for (OctoCitationItem *c in self.relevantCitations) {
        if (c.channelId.length == 0) continue;
        if ([visited containsObject:c.channelId]) continue;
        [visited addObject:c.channelId];
        self.displayNameCache[c.channelId] = [self resolveDisplayNameForCitation:c];
    }
    NSLog(@"[OctoRelatedChatSheet] displayNameCache built: %@", self.displayNameCache);
}

/// citation 顶部标题 / channel chip 显示名解析。viewDidLoad 跑一次, 结果缓存。
/// 层级 (从最可信到最兜底):
///   1. src.sourceName  —— 创建总结时本地写入, DM 已带 "(私聊)"; 最稳定
///   2. SDK channelInfo.displayName/name —— remark 优先
///   3. citation.source —— 服务端字段, 过滤掉 "私聊-<hex>" 这种 hex 串
///   4. channelId / "未知聊天"
/// 取到 base 名后, 按 sourceType (src 缺失时按 SDK channelType 反推) 追加
/// 类型后缀 "(群聊)" / "(子区)" / "(私聊)"。
- (NSString *)resolveDisplayNameForCitation:(OctoCitationItem *)c {
    OctoSourceItem *src = [self matchingSourceFor:c.channelId];
    NSInteger preferred = [self sdkChannelTypeFromSource:src];

    NSString *base = nil;
    if (src.sourceName.length > 0) {
        base = src.sourceName;
    }
    if (base.length == 0) {
        // 候选 channelId: DM 场景 c.channelId 是复合 <myUid>@<peerUid>, SDK channelInfo
        // 按 peer uid 缓存, 直接用复合必 miss。把 src.sourceId 和 "@"-拆开两段都补进候选。
        NSArray<NSString *> *cidCandidates = [self channelIdCandidatesForCitation:c source:src];
        base = [self resolveSDKNameForCandidates:cidCandidates
                                   preferredType:preferred
                                      serverType:c.channelType];
    }
    if (base.length == 0 && c.source.length > 0 && ![self looksLikeServerFallbackName:c.source]) {
        base = c.source;
    }
    if (base.length == 0) {
        base = c.channelId.length > 0 ? c.channelId : LLang(@"未知聊天");
    }

    NSString *suffix = [self typeSuffixFor:src serverType:c.channelType];
    if (suffix.length > 0 && ![self name:base alreadyHasTypeSuffix:suffix]) {
        return [base stringByAppendingString:suffix];
    }
    return base;
}

- (OctoSourceItem *)matchingSourceFor:(NSString *)channelId {
    if (channelId.length == 0) return nil;
    // 第一遍: 精确匹配 (groups / threads 走这条)
    for (OctoSourceItem *s in self.sources) {
        if ([s.sourceId isEqualToString:channelId]) return s;
    }
    // 第二遍: 复合 channelId 包含 sourceId 作为 "@" 切分的某一段 (DM 场景:
    // citation.channelId = "<myUid>@<peerUid>", source.sourceId = "<peerUid>")
    NSArray<NSString *> *parts = [channelId componentsSeparatedByString:@"@"];
    if (parts.count > 1) {
        for (OctoSourceItem *s in self.sources) {
            if (s.sourceId.length > 0 && [parts containsObject:s.sourceId]) return s;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)channelIdCandidatesForCitation:(OctoCitationItem *)c
                                                 source:(OctoSourceItem *)src {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    void (^add)(NSString *) = ^(NSString *s) {
        if (s.length > 0 && ![out containsObject:s]) [out addObject:s];
    };
    add(c.channelId);
    add(src.sourceId);
    NSArray<NSString *> *parts = [c.channelId componentsSeparatedByString:@"@"];
    if (parts.count > 1) {
        for (NSString *p in parts) add(p);
    }
    return out;
}

- (NSString *)typeSuffixFor:(OctoSourceItem *)src serverType:(NSInteger)serverType {
    OctoSourceType t = src ? src.sourceType : 0;
    if (t == 0) {
        if (serverType == WK_PERSON)               t = OctoSourceDirectMessage;
        else if (serverType == WK_COMMUNITY_TOPIC) t = OctoSourceThread;
        else if (serverType == WK_GROUP)           t = OctoSourceGroupChat;
    }
    switch (t) {
        case OctoSourceDirectMessage: return LLang(@"(私聊)");
        case OctoSourceThread:        return LLang(@"(子区)");
        case OctoSourceGroupChat:     return LLang(@"(群聊)");
        default:                      return @"";
    }
}

/// 检测 base 是否已经带了类型后缀 —— 中英文所有变体都查一遍, 避免英文 locale 下
/// 把中文 "张乾(私聊)" 又拼出 " (DM)" 的双后缀。注意 trim 末尾空白, 以兼容
/// "张乾(私聊) " 或 "张乾 (DM)" 这种拼写差异。
- (BOOL)name:(NSString *)base alreadyHasTypeSuffix:(NSString *)expectedSuffix {
    if (base.length == 0) return NO;
    NSString *trimmed = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    static NSArray<NSString *> *known;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        known = @[ @"(私聊)", @"(群聊)", @"(子区)",
                   @"(DM)", @"(Group)", @"(Thread)" ];
    });
    for (NSString *s in known) {
        if ([trimmed hasSuffix:s]) return YES;
    }
    if ([trimmed hasSuffix:expectedSuffix]) return YES;
    return NO;
}

- (NSString *)resolveSDKNameForCandidates:(NSArray<NSString *> *)cids
                            preferredType:(NSInteger)preferredType
                               serverType:(NSInteger)serverType {
    NSMutableArray<NSNumber *> *types = [NSMutableArray array];
    if (preferredType > 0) [types addObject:@(preferredType)];
    if (serverType > 0) {
        NSNumber *st = @(serverType);
        if (![types containsObject:st]) [types addObject:st];
    }
    for (NSNumber *t in @[ @(WK_PERSON), @(WK_GROUP), @(WK_COMMUNITY_TOPIC) ]) {
        if (![types containsObject:t]) [types addObject:t];
    }
    for (NSString *cid in cids) {
        for (NSNumber *t in types) {
            WKChannel *ch = [WKChannel channelID:cid channelType:(uint8_t)t.integerValue];
            WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:ch];
            if (info.displayName.length > 0) return info.displayName;
            if (info.name.length > 0) return info.name;
        }
    }
    return nil;
}

- (NSInteger)sdkChannelTypeFromSource:(OctoSourceItem *)s {
    if (!s) return 0;
    switch (s.sourceType) {
        case OctoSourceDirectMessage: return WK_PERSON;          // 1
        case OctoSourceThread:        return WK_COMMUNITY_TOPIC; // 5
        default:                      return WK_GROUP;           // 2
    }
}

/// 服务端在拿不到本地用户/频道名时的兜底字串:
///   "私聊-<hex>" (中文 zh) / "Direct Message-<hex>" (英文 en) 之类。
/// 不能直接显示给用户, 当作"无值"处理走更后面的兜底。
- (BOOL)looksLikeServerFallbackName:(NSString *)s {
    if (s.length == 0) return NO;
    return [s hasPrefix:@"私聊-"]            || [s hasPrefix:@"私聊 -"]
        || [s hasPrefix:@"DirectMessage-"]   || [s hasPrefix:@"Direct Message-"]
        || [s hasPrefix:@"DM-"];
}

- (void)onChannelChip:(UIButton *)b {
    self.activeChannelId = self.channelIdsInUse[b.tag];
    [self rebuildRows];
    [self layoutChannelChips];
    [self.tableView reloadData];
}

#pragma mark - Rows

/// 把 activeChannelId 范围内 (单 channel 时即整个 relevantCitations) 的所有命中 citation
/// 平铺成行: 每条 citation = contextBefore[] + 命中 hit + contextAfter[]。
- (void)rebuildRows {
    self.rows = [NSMutableArray array];
    NSArray<OctoCitationItem *> *list = self.relevantCitations;
    if (list.count == 0) return;

    NSMutableArray<OctoCitationItem *> *forActive = [NSMutableArray array];
    if (self.channelIdsInUse.count > 1 && self.activeChannelId.length > 0) {
        for (OctoCitationItem *c in list) {
            if ([c.channelId isEqualToString:self.activeChannelId]) [forActive addObject:c];
        }
    } else {
        [forActive addObjectsFromArray:list];
    }

    OctoCitationItem *first = forActive.firstObject ?: list.firstObject;
    self.sourceLabel.text = first ? [self channelDisplayNameFor:first.channelId] : @"";

    for (OctoCitationItem *c in forActive) {
        for (OctoCitationContextMessage *m in c.contextBefore) {
            OctoChatRow *r = [OctoChatRow new];
            r.kind = OctoChatRowKindContextBefore;
            r.sender = m.sender; r.content = m.content; r.sentAt = m.sentAt; r.messageSeq = m.messageSeq;
            r.channelId = c.channelId; r.channelType = c.channelType;
            [self.rows addObject:r];
        }
        OctoChatRow *hit = [OctoChatRow new];
        hit.kind = OctoChatRowKindHit;
        hit.sender = c.sender; hit.content = c.content; hit.sentAt = c.sentAt;
        hit.messageSeq = c.messageSeq;
        hit.channelId = c.channelId; hit.channelType = c.channelType;
        [self.rows addObject:hit];
        for (OctoCitationContextMessage *m in c.contextAfter) {
            OctoChatRow *r = [OctoChatRow new];
            r.kind = OctoChatRowKindContextAfter;
            r.sender = m.sender; r.content = m.content; r.sentAt = m.sentAt; r.messageSeq = m.messageSeq;
            r.channelId = c.channelId; r.channelType = c.channelType;
            [self.rows addObject:r];
        }
    }
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    for (UIView *sub in cell.contentView.subviews) [sub removeFromSuperview];

    OctoChatRow *r = self.rows[indexPath.row];
    BOOL hit = (r.kind == OctoChatRowKindHit);

    UIView *bubble = [UIView new];
    bubble.layer.cornerRadius = 10;
    // hit 命中气泡: 浅色态保留淡紫近白底; 深色态用紫色低 alpha 透 (rgba(127,59,245,0.18))
    // —— 之前硬编 #F7F1FF 在深色底上是亮白, 与 labelColor 出来的白文字重叠不可见。
    UIColor *hitBg = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:0.20];
        }
        return [UIColor colorWithRed:0xF7/255.0 green:0xF1/255.0 blue:0xFF/255.0 alpha:1.0];
    }];
    bubble.backgroundColor = hit ? hitBg : [UIColor secondarySystemBackgroundColor];
    if (hit) {
        bubble.layer.borderWidth = 0;
        // 紫色左边框: 用 CALayer
        CALayer *bar = [CALayer layer];
        bar.frame = CGRectMake(0, 0, 3, 0);
        bar.backgroundColor = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0].CGColor;
        bar.name = @"hit-bar";
        [bubble.layer addSublayer:bar];
    }
    [cell.contentView addSubview:bubble];

    UILabel *name = [UILabel new];
    name.font = [UIFont systemFontOfSize:13 weight:hit ? UIFontWeightSemibold : UIFontWeightRegular];
    name.textColor = hit ? [UIColor labelColor] : [UIColor.labelColor colorWithAlphaComponent:0.7];
    name.text = r.sender ?: @"";
    [bubble addSubview:name];

    UILabel *time = [UILabel new];
    time.font = [UIFont systemFontOfSize:11];
    time.textColor = [UIColor.labelColor colorWithAlphaComponent:0.4];
    time.text = [OctoSummaryDateFormat localFromISO:r.sentAt];
    [bubble addSubview:time];

    UILabel *body = [UILabel new];
    body.font = [UIFont systemFontOfSize:14];
    body.textColor = hit ? [UIColor labelColor] : [UIColor.labelColor colorWithAlphaComponent:0.85];
    body.numberOfLines = 0;
    body.text = r.content ?: @"";
    [bubble addSubview:body];

    UIButton *jumpBtn = nil;
    if (hit && r.channelId.length > 0 && r.messageSeq > 0) {
        jumpBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [jumpBtn setTitle:LLang(@"原消息 →") forState:UIControlStateNormal];
        jumpBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        [jumpBtn setTitleColor:[UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0] forState:UIControlStateNormal];
        [jumpBtn addTarget:self action:@selector(onJump:) forControlEvents:UIControlEventTouchUpInside];
        jumpBtn.tag = (NSInteger)indexPath.row;
        [bubble addSubview:jumpBtn];
    }

    // 布局: 顶行 [name (sizeToFit) · time (right of name)] [jumpBtn 仅命中时, 顶右]
    // 之前 time 占右侧 35% 宽度 + jumpBtn 也定位在右上, 两者直接重叠 (用户报"原消息按钮
    // 和时间重叠")。改为: name + time 都左对齐成一行, jumpBtn 独占右上, 互不干涉。
    CGFloat w = self.view.bounds.size.width - 32;
    CGFloat innerW = w - 24;

    // 先量 jumpBtn 宽度, 才能算 name + time 的可用宽度上限
    CGFloat jumpW = 0;
    if (jumpBtn) {
        [jumpBtn sizeToFit];
        jumpW = jumpBtn.frame.size.width + 8;     // 与左侧 name/time 留 8pt 间距
    }

    CGSize bodySize = [body sizeThatFits:CGSizeMake(innerW, CGFLOAT_MAX)];
    CGFloat bubbleH = 12 + 18 + 4 + bodySize.height + 12;
    bubble.frame = CGRectMake(16, 6, w, bubbleH);

    [name sizeToFit];
    CGFloat nameMaxW = (innerW - jumpW) * 0.7;    // name 最多吃 70% 留空间给 time
    CGFloat nameW = MIN(name.frame.size.width, MAX(40, nameMaxW));
    name.frame = CGRectMake(12, 12, nameW, 18);

    [time sizeToFit];
    CGFloat timeX = 12 + nameW + 6;                // 紧跟 name 右侧 6pt
    CGFloat timeMaxW = innerW - jumpW - nameW - 6;
    CGFloat timeW = MIN(time.frame.size.width, MAX(40, timeMaxW));
    time.frame = CGRectMake(timeX, 12, timeW, 18);

    body.frame = CGRectMake(12, 34, innerW, bodySize.height);

    if (jumpBtn) {
        jumpBtn.frame = CGRectMake(w - jumpBtn.frame.size.width - 12, 8,
                                   jumpBtn.frame.size.width, 22);
    }
    if (hit) {
        for (CALayer *l in bubble.layer.sublayers) {
            if ([l.name isEqualToString:@"hit-bar"]) {
                l.frame = CGRectMake(0, 0, 3, bubbleH);
            }
        }
    }

    cell.contentView.frame = CGRectMake(0, 0, self.view.bounds.size.width, bubbleH + 12);
    cell.frame = CGRectMake(0, 0, self.view.bounds.size.width, bubbleH + 12);
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    OctoChatRow *r = self.rows[indexPath.row];
    UIFont *f = [UIFont systemFontOfSize:14];
    NSAttributedString *att = [[NSAttributedString alloc] initWithString:r.content ?: @"" attributes:@{NSFontAttributeName: f}];
    CGRect b = [att boundingRectWithSize:CGSizeMake(self.view.bounds.size.width - 32 - 24, CGFLOAT_MAX)
                                 options:NSStringDrawingUsesLineFragmentOrigin context:nil];
    return ceilf(b.size.height) + 12 + 18 + 4 + 12 + 12;
}

- (void)onJump:(UIButton *)btn {
    NSInteger row = btn.tag;
    if (row < 0 || row >= (NSInteger)self.rows.count) return;
    OctoChatRow *r = self.rows[row];
    if (r.channelId.length == 0) return;
    Class router = NSClassFromString(@"WKConversationRouter");
    if (!router) return;
    SEL sel = @selector(openChannelId:channelType:messageSeq:);
    if (![router respondsToSelector:sel]) return;
    NSMethodSignature *sig = [router methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = router;
    inv.selector = sel;
    NSString *cid = r.channelId; NSInteger ctype = r.channelType; uint32_t seq = r.messageSeq;
    [inv setArgument:&cid atIndex:2];
    [inv setArgument:&ctype atIndex:3];
    [inv setArgument:&seq atIndex:4];
    [inv invoke];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onClose { [self dismissViewControllerAnimated:YES completion:nil]; }

@end
