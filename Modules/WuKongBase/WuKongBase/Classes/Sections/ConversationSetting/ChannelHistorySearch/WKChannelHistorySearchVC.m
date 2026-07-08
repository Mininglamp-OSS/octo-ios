//
//  WKChannelHistorySearchVC.m
//

#import "WKChannelHistorySearchVC.h"
#import "WKChannelHistorySearchVM.h"
#import "WKChannelHistorySearchAPI.h"
#import "WKChannelHistorySearchKeywordUtil.h"
#import "WKChannelHistoryMessageCell.h"
#import "WKChannelHistoryFileCell.h"
#import "WKChannelHistoryMediaRowCell.h"
#import "WKChannelHistoryMediaGridCell.h"
#import "WKChannelHistorySearchEmptyView.h"
#import "WKChannelHistoryFilterChipBar.h"
#import "WKChannelHistoryFilterVC.h"
#import "WKChannelHistoryMediaBrowser.h"
#import "WKChannelHistoryFilePreviewVC.h"
#import "WKChannelHistoryFileDownloader.h"
#import "WKTabbar.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "UIView+WKCommon.h"
#import "WKConversationRouter.h"
#import "WKNetworkListener.h"
#import "WKNavigationManager.h"
#import "WKTimeTool.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <MJRefresh/MJRefresh.h>

#define kSearchDebounceMs 300
#define kSearchBarHeight 36.0f
#define kTabBarHeight 36.0f
#define kChipBarHeight 36.0f
#define kHintBarHeight 32.0f
#define kOfflineBarHeight 28.0f

@interface WKChannelHistorySearchVC () <
    UITextFieldDelegate,
    UITableViewDataSource,
    UITableViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout,
    WKChannelHistorySearchVMDelegate,
    WKNetworkListenerDelegate,
    WKChannelHistoryFilterVCDelegate
>

@property (nonatomic, strong) WKChannelHistorySearchVM *vm;

@property (nonatomic, strong) UIView *searchBarContainer;
@property (nonatomic, strong) UIView *searchInputBg;
@property (nonatomic, strong) UITextField *searchInput;
@property (nonatomic, strong) UIButton *clearBtn;
@property (nonatomic, strong) UIButton *filterBtn;

@property (nonatomic, strong) WKTabbar *tabbar;
@property (nonatomic, strong) WKChannelHistoryFilterChipBar *chipBar;
@property (nonatomic, strong) UIView *keywordHintBar;
@property (nonatomic, strong) UILabel *keywordHintLbl;
@property (nonatomic, strong) UIView *offlineBar;
@property (nonatomic, strong) UILabel *offlineLbl;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) WKChannelHistorySearchEmptyView *emptyView;

@property (nonatomic, assign) BOOL hasShownKeywordLimitToast;
@property (nonatomic, assign) BOOL didFirstFilterShow;

@end

@implementation WKChannelHistorySearchVC

#pragma mark - lifecycle

- (NSString *)langTitle {
    return LLang(@"查找聊天内容");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.title = self.langTitle;

    NSAssert(self.channel != nil, @"WKChannelHistorySearchVC.channel must be set before push");
    self.vm = [[WKChannelHistorySearchVM alloc] initWithChannel:self.channel];
    self.vm.delegate = self;

    [self setupNavSearch];
    [self setupBars];
    [self setupContent];

    [self refreshOfflineBarVisibility];
    [self updateBarsForCurrentState];

    [[WKNetworkListener shared] addDelegate:self];

    // 进入页面时光标聚焦搜索框 — 与其它搜索入口一致
    [self.searchInput becomeFirstResponder];
}

- (void)dealloc {
    [[WKNetworkListener shared] removeDelegate:self];
    [self.vm cancelInFlight];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.searchInput resignFirstResponder];
}

#pragma mark - setup

- (void)setupNavSearch {
    self.navigationBar.title = self.langTitle;

    // 右上角筛选按钮
    self.filterBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.filterBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
    [self.filterBtn setTitle:LLang(@"筛选") forState:UIControlStateNormal];
    [self.filterBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    self.filterBtn.frame = CGRectMake(0, 0, 44.0f, 32.0f);
    [self.filterBtn addTarget:self action:@selector(onFilterTap) forControlEvents:UIControlEventTouchUpInside];
    self.navigationBar.rightView = self.filterBtn;
}

- (void)setupBars {
    // 搜索框：放在导航栏下方 — 不与系统大标题冲突
    self.searchBarContainer = [UIView new];
    self.searchBarContainer.backgroundColor = [WKApp shared].config.backgroundColor;
    [self.view addSubview:self.searchBarContainer];

    UIView *inputBg = [UIView new];
    inputBg.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.10];
    inputBg.layer.cornerRadius = kSearchBarHeight / 2.0f;
    inputBg.layer.masksToBounds = YES;
    [self.searchBarContainer addSubview:inputBg];
    self.searchInputBg = inputBg;

    UILabel *iconLbl = [UILabel new];
    iconLbl.text = @"🔍";
    iconLbl.font = [UIFont systemFontOfSize:14.0f];
    iconLbl.textAlignment = NSTextAlignmentCenter;
    iconLbl.tag = 101;
    [inputBg addSubview:iconLbl];

    self.searchInput = [UITextField new];
    self.searchInput.font = [[WKApp shared].config appFontOfSize:15.0f];
    self.searchInput.textColor = [WKApp shared].config.defaultTextColor;
    self.searchInput.placeholder = LLang(@"搜索聊天记录");
    self.searchInput.clearButtonMode = UITextFieldViewModeNever; // 自己画
    self.searchInput.returnKeyType = UIReturnKeySearch;
    self.searchInput.delegate = self;
    self.searchInput.enablesReturnKeyAutomatically = NO;
    [self.searchInput addTarget:self action:@selector(onSearchInputChanged) forControlEvents:UIControlEventEditingChanged];
    [inputBg addSubview:self.searchInput];

    self.clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearBtn setTitle:@"✕" forState:UIControlStateNormal];
    [self.clearBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    self.clearBtn.titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightMedium];
    self.clearBtn.hidden = YES;
    [self.clearBtn addTarget:self action:@selector(onClearTap) forControlEvents:UIControlEventTouchUpInside];
    [inputBg addSubview:self.clearBtn];

    // Tabbar
    NSMutableArray<WKTabbarItem *> *items = [NSMutableArray array];
    [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"全部") onClick:^{ [self switchTabIndex:0]; }]];
    [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"聊天记录") onClick:^{ [self switchTabIndex:1]; }]];
    [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"图片视频") onClick:^{ [self switchTabIndex:2]; }]];
    [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"文件") onClick:^{ [self switchTabIndex:3]; }]];
    CGFloat space = 16.0f;
    self.tabbar = [[WKTabbar alloc] initWithItems:items width:WKScreenWidth - space * 2];
    self.tabbar.lim_left = space;
    [self.view addSubview:self.tabbar];

    // chip bar
    self.chipBar = [[WKChannelHistoryFilterChipBar alloc] init];
    self.chipBar.hidden = YES;
    [self.view addSubview:self.chipBar];

    // keyword hint bar (media tab)
    self.keywordHintBar = [UIView new];
    self.keywordHintBar.backgroundColor = [[UIColor systemYellowColor] colorWithAlphaComponent:0.18];
    self.keywordHintBar.hidden = YES;
    self.keywordHintLbl = [UILabel new];
    self.keywordHintLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    self.keywordHintLbl.textColor = [UIColor darkGrayColor];
    self.keywordHintLbl.textAlignment = NSTextAlignmentCenter;
    self.keywordHintLbl.numberOfLines = 1;
    self.keywordHintLbl.text = LLang(@"图片和视频暂不支持按关键词搜索，可按发送人或日期查找");
    [self.keywordHintBar addSubview:self.keywordHintLbl];
    [self.view addSubview:self.keywordHintBar];

    // offline bar
    self.offlineBar = [UIView new];
    self.offlineBar.backgroundColor = [[UIColor systemYellowColor] colorWithAlphaComponent:0.25];
    self.offlineBar.hidden = YES;
    self.offlineLbl = [UILabel new];
    self.offlineLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    self.offlineLbl.textColor = [UIColor darkGrayColor];
    self.offlineLbl.textAlignment = NSTextAlignmentCenter;
    self.offlineLbl.text = LLang(@"当前网络不可用，请检查网络设置");
    [self.offlineBar addSubview:self.offlineLbl];
    [self.view addSubview:self.offlineBar];

    [self.tabbar selectItemAtIndex:0];
}

- (void)setupContent {
    // TableView (全部 / 聊天记录 / 文件)
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.tableView registerClass:WKChannelHistoryMessageCell.class
           forCellReuseIdentifier:[WKChannelHistoryMessageCell reuseIdentifier]];
    [self.tableView registerClass:WKChannelHistoryFileCell.class
           forCellReuseIdentifier:[WKChannelHistoryFileCell reuseIdentifier]];
    [self.tableView registerClass:WKChannelHistoryMediaRowCell.class
           forCellReuseIdentifier:[WKChannelHistoryMediaRowCell reuseIdentifier]];
    [self attachLoadMoreFooter:self.tableView];
    [self.view addSubview:self.tableView];

    // CollectionView (图片视频)
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.minimumInteritemSpacing = 2.0f;
    layout.minimumLineSpacing = 2.0f;
    layout.sectionInset = UIEdgeInsetsMake(2, 2, 2, 2);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.backgroundColor = [WKApp shared].config.backgroundColor;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.collectionView registerClass:WKChannelHistoryMediaGridCell.class
            forCellWithReuseIdentifier:[WKChannelHistoryMediaGridCell reuseIdentifier]];
    [self attachLoadMoreFooter:self.collectionView];
    self.collectionView.hidden = YES;
    [self.view addSubview:self.collectionView];

    // Empty state
    self.emptyView = [WKChannelHistorySearchEmptyView new];
    self.emptyView.hidden = YES;
    __weak typeof(self) ws = self;
    self.emptyView.onRetry = ^{ [ws.vm refresh]; };
    [self.view addSubview:self.emptyView];
}

- (void)attachLoadMoreFooter:(UIScrollView *)sv {
    __weak typeof(self) ws = self;
    sv.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{ [ws.vm loadMore]; }];
    sv.mj_footer.hidden = YES;
}

#pragma mark - layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat navBottom = [self getNavBottom];
    CGFloat w = self.view.lim_width;

    // search bar
    self.searchBarContainer.frame = CGRectMake(0, navBottom, w, kSearchBarHeight + 12.0f);
    UIView *inputBg = self.searchInputBg;
    inputBg.frame = CGRectMake(12, 6, w - 24, kSearchBarHeight);
    UILabel *icon = [inputBg viewWithTag:101];
    icon.frame = CGRectMake(8, 0, 24, kSearchBarHeight);
    self.clearBtn.frame = CGRectMake(inputBg.lim_width - 32, 0, 28, kSearchBarHeight);
    self.searchInput.frame = CGRectMake(CGRectGetMaxX(icon.frame),
                                        0,
                                        self.clearBtn.lim_left - CGRectGetMaxX(icon.frame) - 4,
                                        kSearchBarHeight);

    // tabbar
    self.tabbar.frame = CGRectMake(16, self.searchBarContainer.lim_bottom, w - 32, kTabBarHeight);

    // chip bar
    CGFloat y = self.tabbar.lim_bottom + 4.0f;
    if (!self.chipBar.hidden) {
        self.chipBar.frame = CGRectMake(0, y, w, kChipBarHeight);
        y += kChipBarHeight;
    }

    // keyword hint
    if (!self.keywordHintBar.hidden) {
        self.keywordHintBar.frame = CGRectMake(0, y, w, kHintBarHeight);
        self.keywordHintLbl.frame = CGRectMake(16, 0, w - 32, kHintBarHeight);
        y += kHintBarHeight;
    }

    // offline bar
    if (!self.offlineBar.hidden) {
        self.offlineBar.frame = CGRectMake(0, y, w, kOfflineBarHeight);
        self.offlineLbl.frame = CGRectMake(16, 0, w - 32, kOfflineBarHeight);
        y += kOfflineBarHeight;
    }

    CGRect contentRect = CGRectMake(0, y, w, self.view.lim_height - y);
    self.tableView.frame = contentRect;
    self.collectionView.frame = contentRect;
    [self updateCollectionItemSize];
    self.emptyView.frame = contentRect;
}

- (void)updateCollectionItemSize {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    CGFloat w = self.collectionView.lim_width;
    if (w <= 0) return;
    CGFloat cols = 3.0f;
    CGFloat gap = layout.minimumInteritemSpacing;
    CGFloat side = layout.sectionInset.left + layout.sectionInset.right + gap * (cols - 1);
    CGFloat itemW = floor((w - side) / cols);
    layout.itemSize = CGSizeMake(itemW, itemW);
}

#pragma mark - tab switching

- (void)switchTabIndex:(NSInteger)idx {
    WKChannelHistorySearchTab tab = (WKChannelHistorySearchTab)idx;
    [self.vm setTab:tab];
    BOOL isMedia = (tab == WKChannelHistorySearchTabMedia);
    self.tableView.hidden = isMedia;
    self.collectionView.hidden = !isMedia;
    [self updateBarsForCurrentState];
    [self reloadCurrentList];
    [self updateEmptyState];
}

#pragma mark - input

- (void)onSearchInputChanged {
    UITextField *tf = self.searchInput;
    self.clearBtn.hidden = (tf.text.length == 0);
    // IME 中文拼音组合期间不发请求：等 marked text 为 nil 再触发
    if (tf.markedTextRange != nil) return;
    [self scheduleDebouncedSearch];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // 提交时立即触发一次（不等 debounce）
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applyKeywordNow) object:nil];
    [self applyKeywordNow];
    return YES;
}

- (void)scheduleDebouncedSearch {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applyKeywordNow) object:nil];
    [self performSelector:@selector(applyKeywordNow) withObject:nil afterDelay:kSearchDebounceMs / 1000.0];
}

- (void)applyKeywordNow {
    [self.vm applyKeyword:self.searchInput.text];
}

- (void)onClearTap {
    self.searchInput.text = @"";
    self.clearBtn.hidden = YES;
    [self.vm applyKeyword:@""];
}

#pragma mark - filter

- (void)onFilterTap {
    WKChannelHistoryFilterVC *vc = [WKChannelHistoryFilterVC new];
    vc.channel = self.channel;
    vc.draft = [self.vm.filter copy];
    vc.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)channelHistoryFilterVC:(WKChannelHistoryFilterVC *)vc didApplyFilter:(WKChannelHistorySearchFilter *)filter {
    [vc dismissViewControllerAnimated:YES completion:nil];
    [self.vm applyFilter:filter];
}

#pragma mark - VM delegate

- (void)channelHistorySearchVMDidChangeState:(WKChannelHistorySearchVM *)vm {
    [self reloadCurrentList];
    [self updateEmptyState];
    [self updateLoadMoreFooter];
    [self updateChipBar];
    [self updateKeywordHintBar];
    [self.view setNeedsLayout];
}

- (void)channelHistorySearchVMKeywordExceedLimit:(WKChannelHistorySearchVM *)vm {
    if (self.hasShownKeywordLimitToast) return;
    self.hasShownKeywordLimitToast = YES;
    [self.view showMsg:[NSString stringWithFormat:LLang(@"关键词最多 %ld 个字"),
                          (long)WKChannelHistorySearchKeywordMaxRunes]];
}

- (void)reloadCurrentList {
    if (self.collectionView.hidden == NO) {
        [self.collectionView reloadData];
    } else {
        [self.tableView reloadData];
    }
}

- (void)updateLoadMoreFooter {
    UIScrollView *sv = self.collectionView.hidden ? self.tableView : self.collectionView;
    BOOL hasContent = self.vm.items.count > 0;
    sv.mj_footer.hidden = !hasContent;
    if (self.vm.nextPageError) {
        [sv.mj_footer endRefreshing];
        [self.view showMsg:LLang(@"加载更多失败，请重试")];
    } else if (self.vm.isLoadingNextPage) {
        // MJRefresh footer 在 loadMore 时自动转 — 不主动调
    } else if (!self.vm.hasMore && hasContent) {
        [sv.mj_footer endRefreshingWithNoMoreData];
    } else {
        [sv.mj_footer endRefreshing];
        [sv.mj_footer resetNoMoreData];
    }
}

- (void)updateEmptyState {
    BOOL hasItems = self.vm.items.count > 0;
    if (hasItems) {
        self.emptyView.hidden = YES;
        return;
    }
    self.emptyView.hidden = NO;
    if ([WKNetworkListener shared].hasNetwork == NO) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeOffline primary:nil secondary:nil];
        return;
    }
    if (self.vm.firstPageError) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeError primary:nil secondary:nil];
        return;
    }
    if (self.vm.isLoadingFirstPage) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeLoading primary:nil secondary:nil];
        return;
    }
    if (!self.vm.queryStarted) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeWaitingInput primary:nil secondary:nil];
        return;
    }
    [self.emptyView applyMode:WKChannelHistorySearchEmptyModeNoResults primary:nil secondary:nil];
}

#pragma mark - chip bar

- (void)updateChipBar {
    NSMutableArray<WKChannelHistoryFilterChipDescriptor *> *chips = [NSMutableArray array];
    WKChannelHistorySearchFilter *f = self.vm.filter;
    __weak typeof(self) ws = self;
    if (f.senderUids.count > 0) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"sender";
        c.title = [NSString stringWithFormat:LLang(@"发送人: %ld"), (long)f.senderUids.count];
        c.onClear = ^{
            WKChannelHistorySearchFilter *nf = [ws.vm.filter copy];
            nf.senderUids = nil;
            [ws.vm applyFilter:nf];
        };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.startDate || f.endDate) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"date";
        c.title = [self dateRangeLabelFromStart:f.startDate end:f.endDate];
        c.onClear = ^{
            WKChannelHistorySearchFilter *nf = [ws.vm.filter copy];
            nf.startDate = nil;
            nf.endDate = nil;
            [ws.vm applyFilter:nf];
        };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.sort == WKChannelHistorySearchSortTimeAsc) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"sort";
        c.title = LLang(@"时间正序");
        c.onClear = ^{
            WKChannelHistorySearchFilter *nf = [ws.vm.filter copy];
            nf.sort = WKChannelHistorySearchSortTimeDesc;
            [ws.vm applyFilter:nf];
        };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    self.chipBar.chips = chips;
    self.chipBar.hidden = chips.count == 0;
}

- (NSString *)dateRangeLabelFromStart:(NSDate *)start end:(NSDate *)end {
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [NSDateFormatter new];
        // 与 toApiDict 里的 formatter 对齐, 用 en_US_POSIX locale, 避免设备设佛历
        // / 伊斯兰历时年份被按当地日历渲染 (PR #64 review Octo-Q P2)。
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.dateFormat = @"yyyy/MM/dd";
    });
    NSString *s = start ? [fmt stringFromDate:start] : LLang(@"最早");
    NSString *e = end ? [fmt stringFromDate:end] : LLang(@"至今");
    return [NSString stringWithFormat:@"%@ ~ %@", s, e];
}

#pragma mark - bars visibility

- (void)updateBarsForCurrentState {
    BOOL isMedia = (self.vm.tab == WKChannelHistorySearchTabMedia);
    BOOL hasKw = self.vm.keyword.length > 0;
    self.keywordHintBar.hidden = !(isMedia && hasKw);
    [self.view setNeedsLayout];
}

- (void)updateKeywordHintBar {
    [self updateBarsForCurrentState];
}

#pragma mark - network listener

- (void)networkListenerStatusChange:(WKNetworkListener *)listener {
    BOOL wasOffline = !self.offlineBar.hidden;
    [self refreshOfflineBarVisibility];
    [self updateEmptyState];
    if (wasOffline && listener.hasNetwork) {
        // 恢复联网后自动重试当前查询
        [self.vm refresh];
    }
}

- (void)refreshOfflineBarVisibility {
    BOOL hasNet = [WKNetworkListener shared].hasNetwork;
    self.offlineBar.hidden = hasNet;
    [self.view setNeedsLayout];
}

#pragma mark - UITableViewDataSource / Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.vm.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKChannelHistorySearchItem *item = self.vm.items[indexPath.row];
    NSString *kw = self.vm.keyword;
    switch (item.kind) {
        case WKChannelHistorySearchItemKindMessage: {
            WKChannelHistoryMessageCell *c = [tableView dequeueReusableCellWithIdentifier:[WKChannelHistoryMessageCell reuseIdentifier]
                                                                              forIndexPath:indexPath];
            [c applyItem:item keyword:kw];
            return c;
        }
        case WKChannelHistorySearchItemKindFile: {
            WKChannelHistoryFileCell *c = [tableView dequeueReusableCellWithIdentifier:[WKChannelHistoryFileCell reuseIdentifier]
                                                                           forIndexPath:indexPath];
            [c applyItem:item keyword:kw];
            return c;
        }
        case WKChannelHistorySearchItemKindMedia: {
            WKChannelHistoryMediaRowCell *c = [tableView dequeueReusableCellWithIdentifier:[WKChannelHistoryMediaRowCell reuseIdentifier]
                                                                              forIndexPath:indexPath];
            [c applyItem:item keyword:kw];
            return c;
        }
    }
    return [UITableViewCell new];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKChannelHistorySearchItem *item = self.vm.items[indexPath.row];
    switch (item.kind) {
        case WKChannelHistorySearchItemKindMessage:
            return [WKChannelHistoryMessageCell heightForItem:item width:tableView.lim_width];
        case WKChannelHistorySearchItemKindFile:
            return [WKChannelHistoryFileCell cellHeight];
        case WKChannelHistorySearchItemKindMedia:
            return [WKChannelHistoryMediaRowCell cellHeight];
    }
    return 64.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.vm.items.count) return;
    [self openItem:self.vm.items[indexPath.row]];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.vm.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    WKChannelHistoryMediaGridCell *c = [collectionView dequeueReusableCellWithReuseIdentifier:[WKChannelHistoryMediaGridCell reuseIdentifier]
                                                                                forIndexPath:indexPath];
    WKChannelHistorySearchItem *item = self.vm.items[indexPath.item];
    [c applyItem:item];
    return c;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= (NSInteger)self.vm.items.count) return;
    [self openItem:self.vm.items[indexPath.item]];
}

#pragma mark - tap dispatch

/// 三种 kind 的点击行为各异，整体与气泡内交互对齐:
///   - 消息 → 跳转到聊天页并定位该消息
///   - 媒体 → 全屏大图浏览器, 左右滑切换图片/视频, 右上角 "..." 菜单
///   - 文件 → 下载到本地后用 WKSafeFilePreviewVC 子类预览, 右上角 "..." 菜单
- (void)openItem:(WKChannelHistorySearchItem *)item {
    switch (item.kind) {
        case WKChannelHistorySearchItemKindMessage:
            [self locateMessageItem:item];
            return;
        case WKChannelHistorySearchItemKindMedia:
            [self openMediaItem:item];
            return;
        case WKChannelHistorySearchItemKindFile:
            [self openFileItem:item];
            return;
    }
}

- (void)locateMessageItem:(WKChannelHistorySearchItem *)item {
    if (!item.canLocate) {
        [self.view showMsg:LLang(@"无法定位到该消息")];
        return;
    }
    NSString *cid = item.channelId.length > 0 ? item.channelId : self.channel.channelId;
    NSInteger ct = item.channelType > 0 ? item.channelType : self.channel.channelType;
    [self.searchInput resignFirstResponder];
    [WKConversationRouter openChannelId:cid channelType:ct messageSeq:(uint32_t)item.messageSeq];
}

- (void)openMediaItem:(WKChannelHistorySearchItem *)tapped {
    // 视频无可播 URL (服务端字段缺失 + 本地 WKMessageDB 也没同步过): 直接跳会话页
    // 定位到该消息, 让聊天气泡的 SDK 下载 + 播放链路接管。
    // 服务端未来补齐 messages/_search_media 视频响应的 URL 字段后, 此分支自然不再命中,
    // 用户会直接看到大图浏览器里播放视频, 无需改任何代码。
    if (tapped.mediaKind == WKChannelHistorySearchMediaKindVideo
        && ![WKChannelHistoryMediaBrowser isVideoItemPlayable:tapped]
        && tapped.canLocate) {
        [self locateMessageItem:tapped];
        return;
    }

    // 浏览器内部按 dataSource 真实位置定位初始页, 这里只需把所有 media 项原样传过去。
    NSMutableArray<WKChannelHistorySearchItem *> *mediaList = [NSMutableArray array];
    for (WKChannelHistorySearchItem *it in self.vm.items) {
        if (it.kind != WKChannelHistorySearchItemKindMedia) continue;
        [mediaList addObject:it];
    }
    if (mediaList.count == 0) return;
    [self.searchInput resignFirstResponder];
    __weak typeof(self) ws = self;
    [WKChannelHistoryMediaBrowser presentFromItems:mediaList
                                         tappedItem:tapped
                                           onLocate:^(WKChannelHistorySearchItem *item) {
        [ws locateMessageItem:item];
    }];
}

- (void)openFileItem:(WKChannelHistorySearchItem *)item {
    NSString *url = item.fileDownloadUrl.length > 0 ? item.fileDownloadUrl : item.filePreviewUrl;
    if (url.length == 0) {
        [self.view showMsg:LLang(@"文件链接不可用")];
        return;
    }
    [self.searchInput resignFirstResponder];
    UIView *hudView = self.view;
    [hudView showHUD:LLang(@"下载中…")];
    __weak typeof(self) ws = self;
    NSString *fileName = item.fileName;
    WKChannelHistorySearchItem *capturedItem = item;
    [WKChannelHistoryFileDownloader downloadRemoteUrl:url
                                              fileName:fileName
                                               onProgress:^(double progress) {
        // 进度只在内部记录, HUD 保持 spinner 模式 — 与项目其它下载场景一致 (短文件
        // 进度不显示, 大文件留待后续如果有需要再换 annular determinate 模式)。
    }
                                            onComplete:^(NSURL *localURL, NSError *error) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        [hudView hideHud];
        if (error || !localURL) {
            [ss.view showMsg:error.localizedDescription ?: LLang(@"文件下载失败")];
            return;
        }
        WKChannelHistoryFilePreviewVC *vc = [[WKChannelHistoryFilePreviewVC alloc] initWithFileURL:localURL
                                                                                              title:capturedItem.fileName];
        vc.historyItem = capturedItem;
        vc.onLocate = ^(WKChannelHistorySearchItem *it) {
            [ss locateMessageItem:it];
        };
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    }];
}

@end
