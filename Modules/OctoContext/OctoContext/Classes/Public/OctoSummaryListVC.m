//
//  OctoSummaryListVC.m
//  OctoContext
//

#import "OctoSummaryListVC.h"
#import "OctoSummaryAPI.h"
#import "OctoSummaryCardCell.h"
#import "OctoSummaryCreateVC.h"
#import "OctoSummaryActionSheet.h"
#import "OctoSummaryFilterTabsView.h"
#import "OctoSummaryStatusPoller.h"
#import "OctoSummaryDateFormat.h"
#import <MJRefresh/MJRefresh.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface OctoSummaryListVC () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) OctoSummaryFilterTabsView *filterBar;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSMutableArray<OctoSummaryListItem *> *items;
@property(nonatomic, strong) OctoSummaryStatusPoller *poller;
@property(nonatomic, assign) NSInteger page;
@property(nonatomic, assign) BOOL loading;
@property(nonatomic, assign) BOOL hasMore;
@property(nonatomic, strong) UILabel *emptyLabel;

// 底部悬浮 FAB —— 黑色胶囊 + sparkle + "发起总结",随滚动方向显隐。
// 直接用 UIControl + UIImageView + UILabel 手工布局,避免 UIButton image+title
// 的 contentEdgeInsets / titleEdgeInsets / imageEdgeInsets 三件套互相影响导致
// sizeToFit 算不准,文字被截断的老坑。
@property(nonatomic, strong) UIControl *createFAB;
@property(nonatomic, strong) UIImageView *createFABIcon;
@property(nonatomic, strong) UILabel *createFABLabel;
@property(nonatomic, assign) CGFloat lastContentOffsetY;
@property(nonatomic, assign) BOOL fabVisible;

// 列表 API 不返回总结正文(对齐 web SummaryCard.tsx 的字段集),已完成卡片
// 想要 2 行预览只能客户端按 task_id 懒拉一次详情后回填到 item.summaryPreview。
// 后续若后端 SummaryListItem 加 summary_preview 字段, 把这两个集合 + hydrate
// 调用整段删掉即可。
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *previewCache;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *previewInFlight;

// 当前登录用户名快照,用于 "creator_name == 我 → 你发起" 比对。viewDidLoad 拿一次,
// 不在每个 cell 里重复查 ChannelInfo。
@property(nonatomic, copy, nullable) NSString *currentUserName;
@end

@implementation OctoSummaryListVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationBar.title = LLang(@"智能总结");
    self.view.backgroundColor = [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF7/255.0 alpha:1.0];

    // 右上仅保留搜索 (PR8 实装)。"发起总结" 入口移到底部悬浮 FAB,见 self.createFAB。
    UIButton *searchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [searchBtn setImage:[UIImage systemImageNamed:@"magnifyingglass"] forState:UIControlStateNormal];
    searchBtn.tintColor = [UIColor.labelColor colorWithAlphaComponent:0.4];
    searchBtn.frame = CGRectMake(0, 0, 32, 32);
    self.navigationBar.rightView = searchBtn;

    self.items = [NSMutableArray array];
    self.page = 1;
    self.hasMore = YES;
    self.previewCache = [NSMutableDictionary dictionary];
    self.previewInFlight = [NSMutableSet set];
    [self resolveCurrentUserName];

    self.filterBar = [[OctoSummaryFilterTabsView alloc] initWithFrame:CGRectZero];
    __weak typeof(self) weakSelf = self;
    self.filterBar.onSelect = ^(OctoSummaryFilterIndex idx) {
        [weakSelf reload];
    };
    [self.view addSubview:self.filterBar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 120;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    [self.tableView registerClass:OctoSummaryCardCell.class forCellReuseIdentifier:@"OctoSummaryCardCell"];

    self.tableView.mj_header = [self buildRefreshHeader];
    self.tableView.mj_footer = [self buildRefreshFooter];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [UILabel new];
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.text = LLang(@"暂无总结");
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    [self setupCreateFAB];

    self.poller = [OctoSummaryStatusPoller new];
    self.poller.onUpdate = ^(NSDictionary<NSNumber *,OctoBatchStatusItem *> * changes) {
        [weakSelf applyStatusChanges:changes];
    };

    // CreateVC 提交成功后会发这个通知, 列表收到立刻 reload, 让新任务马上出现在顶部。
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onExternalRefresh)
                                                 name:@"OctoSummaryDidCreateNotification"
                                               object:nil];

    [self reload];
}

- (void)onExternalRefresh {
    [self reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.poller resume];
    [self.poller start];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.poller pause];
}

- (void)dealloc {
    [self.poller stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/// 取当前登录用户的显示名:走 SDK 的 self channel 信息,没拿到时再 fetch 一次,
/// 拿到后 reload 可见 cell 的发起人栏。SDK 缓存过名字时通常一次同步即得。
- (void)resolveCurrentUserName {
    NSString *uid = [WKApp shared].loginInfo.uid;
    if (uid.length == 0) return;
    WKChannel *me = [WKChannel channelID:uid channelType:WK_PERSON];
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:me];
    if (info.name.length > 0) {
        self.currentUserName = info.name;
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[WKSDK shared].channelManager fetchChannelInfo:me completion:^(WKChannelInfo * _Nonnull channelInfo) {
        if (channelInfo.name.length == 0) return;
        weakSelf.currentUserName = channelInfo.name;
        // 名字解析晚于首屏时, 重画当前可见 cell 让 "你发起" 即时纠正
        [weakSelf.tableView reloadData];
    }];
}

#pragma mark - MJRefresh customization

/// 自定义下拉刷新头: 隐藏 "上次更新时间" + 简化状态文案 + 减小 height,
/// 视觉上只保留 spinner / 紫色 sparkle 一抹动画感,避免默认的 "上次更新时间 ..." 廉价感。
- (MJRefreshHeader *)buildRefreshHeader {
    __weak typeof(self) weakSelf = self;
    MJRefreshNormalHeader *header = [MJRefreshNormalHeader headerWithRefreshingBlock:^{
        [weakSelf reload];
    }];
    header.lastUpdatedTimeLabel.hidden = YES;
    header.stateLabel.font = [UIFont systemFontOfSize:12];
    header.stateLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.45];
    [header setTitle:@""              forState:MJRefreshStateIdle];
    [header setTitle:LLang(@"松开刷新") forState:MJRefreshStatePulling];
    [header setTitle:LLang(@"刷新中")   forState:MJRefreshStateRefreshing];
    return header;
}

/// 自定义上拉加载尾: 默认 "已全部加载完毕" 文案撑出大段空白且观感粗糙,
/// 这里所有 state title 全部清空 + 隐藏 stateLabel,只保留触发更多页时短暂的
/// loading 指示。无更多数据时整个 footer 视觉上"消失"。
- (MJRefreshFooter *)buildRefreshFooter {
    __weak typeof(self) weakSelf = self;
    MJRefreshAutoNormalFooter *footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{
        [weakSelf loadMore];
    }];
    [footer setTitle:@"" forState:MJRefreshStateIdle];
    [footer setTitle:@"" forState:MJRefreshStatePulling];
    [footer setTitle:LLang(@"加载中") forState:MJRefreshStateRefreshing];
    [footer setTitle:@"" forState:MJRefreshStateNoMoreData];
    footer.stateLabel.font = [UIFont systemFontOfSize:11];
    footer.stateLabel.textColor = [UIColor.labelColor colorWithAlphaComponent:0.35];
    footer.automaticallyHidden = YES;     // 内容不足以触发加载更多时整体隐藏
    return footer;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = CGRectGetMaxY(self.navigationBar.frame);
    self.filterBar.frame = CGRectMake(0, top, self.view.bounds.size.width, 44);
    // 列表与筛选 tab 之间留 12pt 视觉间距 —— 用 contentInset.top, 这样
    // 第一行卡片不被筛选条压住,同时下拉刷新触发位置仍保持自然。
    CGFloat ty = CGRectGetMaxY(self.filterBar.frame);
    self.tableView.frame = CGRectMake(0, ty,
                                      self.view.bounds.size.width,
                                      self.view.bounds.size.height - ty);
    self.tableView.contentInset = UIEdgeInsetsMake(12, 0, 0, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(12, 0, 0, 0);
    self.emptyLabel.frame = CGRectMake(0, ty + 100, self.view.bounds.size.width, 24);
    [self layoutCreateFAB];
}

#pragma mark - Create FAB

- (void)setupCreateFAB {
    UIControl *fab = [UIControl new];
    fab.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:0.95 alpha:1.0]
            : [UIColor blackColor];
    }];
    fab.layer.shadowColor = [UIColor blackColor].CGColor;
    fab.layer.shadowOpacity = 0.18;
    fab.layer.shadowRadius = 12;
    fab.layer.shadowOffset = CGSizeMake(0, 4);
    [fab addTarget:self action:@selector(onCreate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:fab];

    UIColor *fgColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor blackColor]
            : [UIColor whiteColor];
    }];

    UIImageView *icon = [UIImageView new];
    // FAB 图标改用项目内的 octo-summary-spark (与上下文入口图标统一), template 渲染让 tintColor 接管色相
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSURL *imgBundleURL = [bundle URLForResource:@"OctoContext_images" withExtension:@"bundle"];
    NSBundle *imgBundle = imgBundleURL ? [NSBundle bundleWithURL:imgBundleURL] : bundle;
    UIImage *sparkImg = [UIImage imageNamed:@"octo-summary-spark" inBundle:imgBundle compatibleWithTraitCollection:nil];
    if (!sparkImg) sparkImg = [UIImage imageNamed:@"octo-summary-spark"];
    icon.image = [sparkImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    icon.tintColor = fgColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [fab addSubview:icon];

    UILabel *label = [UILabel new];
    label.text = LLang(@"发起总结");
    label.textColor = fgColor;
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [fab addSubview:label];

    self.createFAB = fab;
    self.createFABIcon = icon;
    self.createFABLabel = label;
    self.fabVisible = YES;
}

- (void)layoutCreateFAB {
    UILabel *label = self.createFABLabel;
    UIImageView *icon = self.createFABIcon;
    [label sizeToFit];
    CGFloat iconSize = 18;
    CGFloat gap = 6;
    CGFloat hPad = 20;
    CGFloat vPad = 12;
    CGFloat fabH = MAX(iconSize, label.frame.size.height) + vPad * 2;   // 视觉 ~44
    CGFloat fabW = hPad + iconSize + gap + ceilf(label.frame.size.width) + hPad;

    CGFloat bottomSafe = self.view.safeAreaInsets.bottom;
    // 浮岛 tabbar 占用 ~76 + bottomGap 8;FAB 居于 tabbar 上方留 16 视觉间距,避免遮挡。
    CGFloat fabBottom = self.view.bounds.size.height - bottomSafe - 16;
    self.createFAB.frame = CGRectMake((self.view.bounds.size.width - fabW) / 2.0,
                                       fabBottom - fabH, fabW, fabH);
    self.createFAB.layer.cornerRadius = fabH / 2.0;

    icon.frame  = CGRectMake(hPad, (fabH - iconSize) / 2.0, iconSize, iconSize);
    label.frame = CGRectMake(hPad + iconSize + gap,
                             (fabH - label.frame.size.height) / 2.0,
                             label.frame.size.width, label.frame.size.height);
}

#pragma mark - UIScrollViewDelegate (FAB scroll-aware)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat dy = scrollView.contentOffset.y - self.lastContentOffsetY;
    self.lastContentOffsetY = scrollView.contentOffset.y;
    // 只在用户主动拖动时响应,避免 contentInset 调整 / setContentOffset 引起误判
    if (!scrollView.isDragging && !scrollView.isDecelerating) return;
    if (dy > 4) [self setFabVisible:NO];           // 向下滑(内容上移): 隐藏
    else if (dy < -4) [self setFabVisible:YES];    // 向上滑: 立即显
}

- (void)setFabVisible:(BOOL)visible {
    if (visible == _fabVisible) return;
    _fabVisible = visible;       // 直接写 ivar, 否则 self.fabVisible = ... 会递归调本 setter, 栈溢出。
    [UIView animateWithDuration:0.22
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.createFAB.alpha = visible ? 1.0 : 0.0;
        self.createFAB.transform = visible ? CGAffineTransformIdentity
                                            : CGAffineTransformMakeTranslation(0, 24);
    } completion:nil];
}

#pragma mark - Loading

- (NSDictionary *)buildParams {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    p[@"page"] = @(self.page);
    p[@"page_size"] = @(20);
    NSInteger st = [OctoSummaryFilterTabsView taskStatusForFilter:self.filterBar.selectedIndex];
    if (st >= 0) p[@"status"] = @(st);
    return p;
}

- (void)reload {
    if (self.loading) return;
    self.loading = YES;
    self.page = 1;
    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] listSummariesWithParams:[self buildParams] callback:^(id _Nullable result, NSError * _Nullable error) {
        weakSelf.loading = NO;
        [weakSelf.tableView.mj_header endRefreshing];
        if (error) {
            [weakSelf.view showHUDWithHide:LLang(@"网络异常")];
            return;
        }
        NSDictionary *r = result;
        NSArray *items = r[@"items"] ?: @[];
        weakSelf.items = [items mutableCopy];
        [weakSelf hydratePreview];
        weakSelf.hasMore = (items.count >= 20);
        [weakSelf.tableView reloadData];
        weakSelf.emptyLabel.hidden = (weakSelf.items.count > 0);
        [weakSelf refreshPoller];
        // 没有更多数据时直接 endRefreshing(回到 idle 状态), 而不是切到 NoMoreData
        // 触发 "已全部加载完毕" 文案. automaticallyHidden + title 全空时, idle
        // 态视觉上完全不可见。
        if (weakSelf.hasMore) [weakSelf.tableView.mj_footer resetNoMoreData];
        else                  [weakSelf.tableView.mj_footer endRefreshing];
    }];
}

- (void)loadMore {
    if (self.loading || !self.hasMore) {
        [self.tableView.mj_footer endRefreshing];
        return;
    }
    self.loading = YES;
    self.page++;
    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] listSummariesWithParams:[self buildParams] callback:^(id _Nullable result, NSError * _Nullable error) {
        weakSelf.loading = NO;
        [weakSelf.tableView.mj_footer endRefreshing];
        if (error) {
            weakSelf.page--;
            [weakSelf.view showHUDWithHide:LLang(@"网络异常")];
            return;
        }
        NSArray *items = ((NSDictionary *)result)[@"items"] ?: @[];
        [weakSelf.items addObjectsFromArray:items];
        [weakSelf hydratePreview];
        weakSelf.hasMore = (items.count >= 20);
        [weakSelf.tableView reloadData];
        [weakSelf refreshPoller];
        if (!weakSelf.hasMore) [weakSelf.tableView.mj_footer endRefreshing];   // 同 reload, 不切 NoMoreData 状态
    }];
}

/// 懒加载已完成卡片的总结正文 preview。后端 SummaryListItem 不带 result.content,
/// 这里对所有 completed 且无 preview 的 item 并发拉详情, 截前 120 字回填后只 reload 那一行。
/// 后端若加了 summary_preview 字段, 整个方法可删。
- (void)hydratePreview {
    NSMutableArray<OctoSummaryListItem *> *needFetch = [NSMutableArray array];
    for (OctoSummaryListItem *it in self.items) {
        if (it.status != OctoTaskStatusCompleted) continue;
        if (it.summaryPreview.length > 0) continue;
        NSNumber *key = @(it.taskId);
        NSString *cached = self.previewCache[key];
        if (cached.length > 0) {
            it.summaryPreview = cached;
            continue;
        }
        if ([self.previewInFlight containsObject:key]) continue;
        [self.previewInFlight addObject:key];
        [needFetch addObject:it];
    }

    __weak typeof(self) weakSelf = self;
    for (OctoSummaryListItem *it in needFetch) {
        int64_t tid = it.taskId;
        [[OctoSummaryAPI shared] getSummaryDetail:tid callback:^(id _Nullable result, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf.previewInFlight removeObject:@(tid)];
            if (error || ![result isKindOfClass:OctoSummaryDetail.class]) return;
            OctoSummaryDetail *d = result;
            NSString *content = d.result.content ?: @"";
            // 去掉 markdown 头标记 / 多余空白, 截 120 字。Cell 自身按 boundingRect
            // 测高再截 2 行, 这里给得宽点防止短行。
            NSString *clean = [strongSelf cleanPreviewFromContent:content];
            if (clean.length == 0) return;
            strongSelf.previewCache[@(tid)] = clean;
            // 回填到对应 item 并 reload 那一行
            for (NSInteger i = 0; i < (NSInteger)strongSelf.items.count; i++) {
                OctoSummaryListItem *cur = strongSelf.items[i];
                if (cur.taskId == tid) {
                    cur.summaryPreview = clean;
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:0];
                    [strongSelf.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
                    break;
                }
            }
        }];
    }
}

/// 把 markdown 内容压平成可放卡片预览的纯文本: 去标题/列表标记/多余换行,前 120 字。
- (NSString *)cleanPreviewFromContent:(NSString *)content {
    if (content.length == 0) return @"";
    NSMutableString *s = [content mutableCopy];
    // 去 ###/##/# 与行首 -/* 标记
    [s replaceOccurrencesOfString:@"###" withString:@"" options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"##"  withString:@"" options:0 range:NSMakeRange(0, s.length)];
    // 把多个空白(含换行)归一为单空格
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:nil];
    NSString *flat = [re stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@" "];
    flat = [flat stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // 去掉残留的 markdown bullet/列表前缀
    NSRegularExpression *bullets = [NSRegularExpression regularExpressionWithPattern:@"^[-*•]\\s+" options:0 error:nil];
    flat = [bullets stringByReplacingMatchesInString:flat options:0 range:NSMakeRange(0, flat.length) withTemplate:@""];
    if (flat.length > 200) flat = [flat substringToIndex:200];
    return flat;
}

- (void)refreshPoller {
    NSMutableArray<NSNumber *> *active = [NSMutableArray array];
    for (OctoSummaryListItem *it in self.items) {
        if (it.status == OctoTaskStatusPending
            || it.status == OctoTaskStatusWaitingConfirm
            || it.status == OctoTaskStatusProcessing) {
            [active addObject:@(it.taskId)];
        }
    }
    [self.poller setTaskIds:active];
}

- (void)applyStatusChanges:(NSDictionary<NSNumber *, OctoBatchStatusItem *> *)changes {
    if (changes.count == 0) return;
    BOOL anyTerminal = NO;
    BOOL anyNewlyCompleted = NO;
    for (NSInteger i = 0; i < self.items.count; i++) {
        OctoSummaryListItem *it = self.items[i];
        OctoBatchStatusItem *upd = changes[@(it.taskId)];
        if (!upd) continue;
        OctoTaskStatus prev = it.status;
        it.status = upd.status;
        BOOL terminal = (upd.status == OctoTaskStatusCompleted
                         || upd.status == OctoTaskStatusFailed
                         || upd.status == OctoTaskStatusCancelled);
        anyTerminal = anyTerminal || terminal;
        if (upd.status == OctoTaskStatusCompleted && prev != OctoTaskStatusCompleted) {
            anyNewlyCompleted = YES;
        }
    }
    [self.tableView reloadData];
    if (anyTerminal) [self refreshPoller];
    // processing → completed 的 cell 此时 summaryPreview 还是空, 走一次 hydrate 立刻拉详情
    // 回填 preview, 不必等用户手动下拉刷新 (用户报"完成后总结内容不显示, 必须刷新"的根因)。
    if (anyNewlyCompleted) [self hydratePreview];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    OctoSummaryListItem *it = self.items[indexPath.row];
    return [OctoSummaryCardCell heightForItem:it width:self.view.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OctoSummaryCardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OctoSummaryCardCell" forIndexPath:indexPath];
    OctoSummaryListItem *it = self.items[indexPath.row];
    cell.currentUserName = self.currentUserName;
    [cell bindItem:it];
    __weak typeof(self) weakSelf = self;
    cell.onAction = ^(NSInteger actionType, OctoSummaryListItem *item) {
        [weakSelf handleCellAction:(OctoSummaryActionType)actionType forItem:item];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    OctoSummaryListItem *it = self.items[indexPath.row];
    [self openDetail:it];
}

- (void)showActionsForItem:(OctoSummaryListItem *)item {
    // UIMenu 已挂在 cell 的 ⋯ 按钮上, 不再走这条 sheet 路径。保留方法体作为兜底:
    // 万一 iOS 13 兼容路径需要时直接 alert action sheet。
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"查看详情") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self openDetail:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self confirmDelete:item];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Cell action handler (UIMenu 回调统一入口)

- (void)handleCellAction:(OctoSummaryActionType)action forItem:(OctoSummaryListItem *)item {
    switch (action) {
        case OctoSummaryActionDelete:
            [self confirmDelete:item];
            break;
        case OctoSummaryActionCancel:
            [self performCancel:item];
            break;
        case OctoSummaryActionRegenerate:
        case OctoSummaryActionRetry:
            [self performRegenerate:item topic:nil];
            break;
        case OctoSummaryActionEditTopic:
            [self promptEditTopicForItem:item];
            break;
        default: break;
    }
}

- (void)performCancel:(OctoSummaryListItem *)item {
    // 乐观更新: 立刻把 cell 切到 cancelled, ⋯ 菜单立即映射新状态。API 失败回滚。
    OctoTaskStatus original = item.status;
    item.status = OctoTaskStatusCancelled;
    [self reloadRowForTaskId:item.taskId];
    [self refreshPoller];
    __weak typeof(self) ws = self;
    [[OctoSummaryAPI shared] cancelSummary:item.taskId callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) {
            item.status = original;
            [ws reloadRowForTaskId:item.taskId];
            [ws.view showHUDWithHide:LLang(@"取消失败")];
            return;
        }
        [ws.view showHUDWithHide:LLang(@"已取消")];
    }];
}

- (void)performRegenerate:(OctoSummaryListItem *)item topic:(nullable NSString *)topic {
    // 乐观更新: 立刻切到 processing, ⋯ 菜单也跟着切到 "取消任务/删除"。
    // 不再调全量 reload —— poller 会按新 task_id 拉状态; API 失败时回滚。
    OctoTaskStatus original = item.status;
    int64_t origTaskId = item.taskId;
    item.status = OctoTaskStatusProcessing;
    item.completedAt = nil;
    [self reloadRowForTaskId:origTaskId];
    [self refreshPoller];

    __weak typeof(self) ws = self;
    [[OctoSummaryAPI shared] regenerateSummary:origTaskId topic:topic callback:^(id _Nullable result, NSError * _Nullable error) {
        if (error) {
            item.status = original;
            [ws reloadRowForTaskId:origTaskId];
            [ws.view showHUDWithHide:LLang(@"重新生成失败")];
            return;
        }
        // 后端返回新 task_id, 切到新 id 让后续 poller / detail 走新任务
        if ([result isKindOfClass:NSDictionary.class]) {
            int64_t newId = [((NSDictionary *)result)[@"task_id"] longLongValue];
            if (newId > 0 && newId != origTaskId) {
                item.taskId = newId;
                [ws refreshPoller];
            }
        }
        [ws.view showHUDWithHide:LLang(@"已开始重新生成")];
    }];
}

/// 根据 taskId 找对应行并 reloadRowsAtIndexPaths: —— 乐观更新链路通用工具。
- (void)reloadRowForTaskId:(int64_t)tid {
    for (NSInteger i = 0; i < (NSInteger)self.items.count; i++) {
        if (self.items[i].taskId == tid) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:0];
            [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
            return;
        }
    }
}

/// 失败/已取消的卡 → "编辑": 打开 CreateVC 并预填上次的主题 + sources, 用户改完
/// 后点开始总结即起一条新任务 (createSummary, 产生新 task_id)。
/// 之前用 UIAlertController 单文本框只让改主题, 体验受限; 现在直接复用创建页, 主题 / 聊天
/// 来源都能改, 与"重新发起"语义一致。
- (void)promptEditTopicForItem:(OctoSummaryListItem *)item {
    Class createCls = NSClassFromString(@"OctoSummaryCreateVC");
    if (!createCls) return;
    OctoSummaryCreateVC *vc = [createCls new];
    // 列表 item 没有原始 topic 字段, 用 title 兜底 (后端 title 多数情况就是 topic)
    vc.prefilledTopic = item.title.length > 0 ? item.title : @"";
    vc.prefilledSources = [item.sources copy] ?: @[];
    vc.hidesBottomBarWhenPushed = YES;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)confirmDelete:(OctoSummaryListItem *)item {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"确认删除") message:LLang(@"删除后将无法恢复") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[OctoSummaryAPI shared] deleteSummary:item.taskId callback:^(id _Nullable result, NSError * _Nullable error) {
            if (error) {
                [self.view showHUDWithHide:LLang(@"删除失败")];
                return;
            }
            [self.items removeObject:item];
            [self.tableView reloadData];
            [self refreshPoller];
            self.emptyLabel.hidden = (self.items.count > 0);
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openDetail:(OctoSummaryListItem *)item {
    Class detailCls = NSClassFromString(@"OctoSummaryDetailVC");
    if (!detailCls) return;
    UIViewController *vc = [detailCls new];
    [vc setValue:@(item.taskId) forKey:@"taskId"];
    if ([vc respondsToSelector:@selector(setListItem:)]) {
        [vc setValue:item forKey:@"listItem"];
    }
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onCreate {
    Class createCls = NSClassFromString(@"OctoSummaryCreateVC");
    if (!createCls) return;
    UIViewController *vc = [createCls new];
    // 关键: push 到根 nav (WKRootNavigationController), 不要 modal-present 单独的
    // UINavigationController。原因:
    //   WKForwardSelectVC.onConfirm 内部调
    //     [[WKNavigationManager shared] popViewControllerAnimated:YES]
    //   它走的是根 nav, 如果 CreateVC 是 modal 出来的, 根 nav 在 modal 后面,
    //   pop 之后视觉无变化 → 用户感觉 "确定无反应"。
    // 推到根 nav 后, CreateVC + WKForwardSelectVC 都在同一 nav 栈, 各种 pop 行为
    // 都正确。系统 nav bar 由 WKRootNavigationController 全局隐藏, 不会和
    // WKBaseVC 自带的 WKNavigationBar 打架。
    vc.hidesBottomBarWhenPushed = YES;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

@end
