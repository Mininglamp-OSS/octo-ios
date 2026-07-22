//
//  WKGlobalSearchV2VC.m
//  WuKongBase
//

#import "WKGlobalSearchV2VC.h"
#import "WKGlobalMsgGroupsVM.h"
#import "WKGlobalContactsVM.h"
#import "WKGlobalFilesVM.h"
#import "WKGlobalMsgDetailVC.h"
#import "WKGlobalSearchGroupBucketCell.h"
#import "WKGlobalSearchError.h"

#import "WKChannelHistoryFileCell.h"
#import "WKChannelHistorySearchEmptyView.h"
#import "WKChannelHistoryFilterChipBar.h"
#import "WKChannelHistoryFilterVC.h"
#import "WKChannelHistoryFilePreviewVC.h"
#import "WKChannelHistoryFileDownloader.h"
#import "WKChannelHistorySearchKeywordUtil.h"
#import "WKSearchContactsCell.h"

#import "WKGlobalSearchResultController.h"

#import "WKTabbar.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "UIView+WKCommon.h"
#import "WKConversationRouter.h"
#import "WKNetworkListener.h"
#import "WKNavigationManager.h"
#import <MJRefresh/MJRefresh.h>

#define kV2SearchDebounceMs 300
#define kV2SearchBarHeight 36.0f
#define kV2TabBarHeight 36.0f
#define kV2ChipBarHeight 36.0f
#define kV2OfflineBarHeight 28.0f

@interface WKGlobalSearchV2VC () <
    UITextFieldDelegate,
    UITableViewDataSource,
    UITableViewDelegate,
    WKGlobalMsgGroupsVMDelegate,
    WKGlobalContactsVMDelegate,
    WKGlobalFilesVMDelegate,
    WKChannelHistoryFilterVCDelegate,
    WKNetworkListenerDelegate
>

@property (nonatomic, assign) WKGlobalSearchV2Tab currentTab;
@property (nonatomic, copy) NSString *currentKeyword;

@property (nonatomic, strong) WKGlobalMsgGroupsVM *groupsVM;
@property (nonatomic, strong) WKGlobalContactsVM *contactsVM;
@property (nonatomic, strong) WKGlobalFilesVM *filesVM;

@property (nonatomic, strong) UIView *searchBarContainer;
@property (nonatomic, strong) UIView *searchInputBg;
@property (nonatomic, strong) UITextField *searchInput;
@property (nonatomic, strong) UIButton *clearBtn;
@property (nonatomic, strong) UIButton *filterBtn;

@property (nonatomic, strong) WKTabbar *tabbar;
@property (nonatomic, strong) WKChannelHistoryFilterChipBar *chipBar;
@property (nonatomic, strong) UIView *offlineBar;
@property (nonatomic, strong) UILabel *offlineLbl;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) WKChannelHistorySearchEmptyView *emptyView;

@property (nonatomic, assign) BOOL hasShownKeywordLimitToast;
@property (nonatomic, assign) BOOL didFallback;
@end

@implementation WKGlobalSearchV2VC

#pragma mark - lifecycle

- (NSString *)langTitle { return LLang(@"搜索"); }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.title = self.langTitle;

    self.currentTab = self.initialTab;
    self.currentKeyword = self.initialKeyword ?: @"";

    self.groupsVM = [WKGlobalMsgGroupsVM new];
    self.groupsVM.delegate = self;
    self.contactsVM = [WKGlobalContactsVM new];
    self.contactsVM.delegate = self;
    self.filesVM = [WKGlobalFilesVM new];
    self.filesVM.delegate = self;

    [self setupNav];
    [self setupBars];
    [self setupContent];

    [self.tabbar selectItemAtIndex:self.currentTab]; // 触发 onClick → switchTabIndex:
    if (self.currentKeyword.length > 0) {
        self.searchInput.text = self.currentKeyword;
        self.clearBtn.hidden = NO;
    }

    [self refreshOfflineBarVisibility];
    [self syncActiveVM];             // 预填 keyword 时立即搜
    [self updateAllTransientUI];

    [[WKNetworkListener shared] addDelegate:self];
    [self.searchInput becomeFirstResponder];
}

- (void)dealloc {
    [[WKNetworkListener shared] removeDelegate:self];
    [self.groupsVM cancelInFlight];
    [self.contactsVM cancelInFlight];
    [self.filesVM cancelInFlight];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.searchInput resignFirstResponder];
}

#pragma mark - setup

- (void)setupNav {
    self.navigationBar.title = self.langTitle;

    self.filterBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.filterBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
    [self.filterBtn setTitle:LLang(@"筛选") forState:UIControlStateNormal];
    [self.filterBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    self.filterBtn.frame = CGRectMake(0, 0, 44.0f, 32.0f);
    [self.filterBtn addTarget:self action:@selector(onFilterTap) forControlEvents:UIControlEventTouchUpInside];
    self.navigationBar.rightView = self.filterBtn;
}

- (void)setupBars {
    self.searchBarContainer = [UIView new];
    self.searchBarContainer.backgroundColor = [WKApp shared].config.backgroundColor;
    [self.view addSubview:self.searchBarContainer];

    UIView *inputBg = [UIView new];
    inputBg.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.10];
    inputBg.layer.cornerRadius = kV2SearchBarHeight / 2.0f;
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
    self.searchInput.placeholder = LLang(@"搜索");
    self.searchInput.clearButtonMode = UITextFieldViewModeNever;
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

    NSMutableArray<WKTabbarItem *> *items = [NSMutableArray array];
    __weak typeof(self) ws = self;
    [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"聊天记录") onClick:^{ [ws switchTabIndex:WKGlobalSearchV2TabMessages]; }]];
    [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"联系人") onClick:^{ [ws switchTabIndex:WKGlobalSearchV2TabContacts]; }]];
    [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"群组") onClick:^{ [ws switchTabIndex:WKGlobalSearchV2TabGroups]; }]];
    [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"文件") onClick:^{ [ws switchTabIndex:WKGlobalSearchV2TabFiles]; }]];
    CGFloat space = 16.0f;
    self.tabbar = [[WKTabbar alloc] initWithItems:items width:WKScreenWidth - space * 2];
    self.tabbar.lim_left = space;
    [self.view addSubview:self.tabbar];

    self.chipBar = [[WKChannelHistoryFilterChipBar alloc] init];
    self.chipBar.hidden = YES;
    [self.view addSubview:self.chipBar];

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
}

- (void)setupContent {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.tableView registerClass:WKGlobalSearchGroupBucketCell.class forCellReuseIdentifier:[WKGlobalSearchGroupBucketCell reuseIdentifier]];
    [self.tableView registerClass:WKChannelHistoryFileCell.class forCellReuseIdentifier:[WKChannelHistoryFileCell reuseIdentifier]];
    [self.tableView registerClass:WKSearchContactsCell.class forCellReuseIdentifier:@"WKGlobalContactsCell"];
    __weak typeof(self) ws = self;
    self.tableView.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{ [ws onLoadMore]; }];
    self.tableView.mj_footer.hidden = YES;
    [self.view addSubview:self.tableView];

    self.emptyView = [WKChannelHistorySearchEmptyView new];
    self.emptyView.hidden = YES;
    self.emptyView.onRetry = ^{ [ws syncActiveVM]; };
    [self.view addSubview:self.emptyView];
}

#pragma mark - layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat navBottom = [self getNavBottom];
    CGFloat w = self.view.lim_width;

    self.searchBarContainer.frame = CGRectMake(0, navBottom, w, kV2SearchBarHeight + 12.0f);
    UIView *inputBg = self.searchInputBg;
    inputBg.frame = CGRectMake(12, 6, w - 24, kV2SearchBarHeight);
    UILabel *icon = [inputBg viewWithTag:101];
    icon.frame = CGRectMake(8, 0, 24, kV2SearchBarHeight);
    self.clearBtn.frame = CGRectMake(inputBg.lim_width - 32, 0, 28, kV2SearchBarHeight);
    self.searchInput.frame = CGRectMake(CGRectGetMaxX(icon.frame), 0,
                                        self.clearBtn.lim_left - CGRectGetMaxX(icon.frame) - 4, kV2SearchBarHeight);

    self.tabbar.frame = CGRectMake(16, self.searchBarContainer.lim_bottom, w - 32, kV2TabBarHeight);

    CGFloat y = self.tabbar.lim_bottom + 4.0f;
    if (!self.chipBar.hidden) {
        self.chipBar.frame = CGRectMake(0, y, w, kV2ChipBarHeight);
        y += kV2ChipBarHeight;
    }
    if (!self.offlineBar.hidden) {
        self.offlineBar.frame = CGRectMake(0, y, w, kV2OfflineBarHeight);
        self.offlineLbl.frame = CGRectMake(16, 0, w - 32, kV2OfflineBarHeight);
        y += kV2OfflineBarHeight;
    }

    CGRect contentRect = CGRectMake(0, y, w, self.view.lim_height - y);
    self.tableView.frame = contentRect;
    self.emptyView.frame = contentRect;
}

#pragma mark - tab switching

- (void)switchTabIndex:(WKGlobalSearchV2Tab)tab {
    self.currentTab = tab;
    [self updateFilterButtonVisibility];
    [self syncActiveVM];
    [self.tableView reloadData];
    [self updateAllTransientUI];
    [self.tableView setContentOffset:CGPointZero animated:NO];
}

/// 把当前 keyword 同步给激活 tab 的 VM（applyKeyword 内部去重，已搜过相同 keyword 则 no-op）。
- (void)syncActiveVM {
    switch (self.currentTab) {
        case WKGlobalSearchV2TabMessages:
            [self.groupsVM applyKeyword:self.currentKeyword];
            break;
        case WKGlobalSearchV2TabContacts:
        case WKGlobalSearchV2TabGroups:
            [self.contactsVM applyKeyword:self.currentKeyword];
            break;
        case WKGlobalSearchV2TabFiles:
            [self.filesVM applyKeyword:self.currentKeyword];
            break;
    }
}

- (void)updateFilterButtonVisibility {
    // 联系人/群组走 /search/global，无筛选参数 → 隐藏筛选入口。
    BOOL canFilter = (self.currentTab == WKGlobalSearchV2TabMessages || self.currentTab == WKGlobalSearchV2TabFiles);
    self.filterBtn.hidden = !canFilter;
}

#pragma mark - input

- (void)onSearchInputChanged {
    UITextField *tf = self.searchInput;
    self.clearBtn.hidden = (tf.text.length == 0);
    if (tf.markedTextRange != nil) return; // IME 组合中
    [self scheduleDebouncedSearch];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applyKeywordNow) object:nil];
    [self applyKeywordNow];
    return YES;
}

- (void)scheduleDebouncedSearch {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(applyKeywordNow) object:nil];
    [self performSelector:@selector(applyKeywordNow) withObject:nil afterDelay:kV2SearchDebounceMs / 1000.0];
}

- (void)applyKeywordNow {
    self.currentKeyword = self.searchInput.text ?: @"";
    [self syncActiveVM];
}

- (void)onClearTap {
    self.searchInput.text = @"";
    self.clearBtn.hidden = YES;
    self.currentKeyword = @"";
    [self syncActiveVM];
}

#pragma mark - filter

- (WKChannelHistorySearchFilter *)activeFilter {
    if (self.currentTab == WKGlobalSearchV2TabMessages) return self.groupsVM.filter;
    if (self.currentTab == WKGlobalSearchV2TabFiles) return self.filesVM.filter;
    return nil;
}

- (void)onFilterTap {
    WKChannelHistorySearchFilter *active = [self activeFilter];
    if (!active) return;
    WKChannelHistoryFilterVC *vc = [WKChannelHistoryFilterVC new];
    vc.channel = nil; // 全局无单一频道 → 发送者走好友候选（WKChannelHistoryFilterVC globalMode 处理）
    vc.globalMode = YES;
    vc.showContentTypes = (self.currentTab == WKGlobalSearchV2TabMessages);
    vc.showFileTypes = (self.currentTab == WKGlobalSearchV2TabFiles);
    vc.draft = [active copy];
    vc.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)channelHistoryFilterVC:(WKChannelHistoryFilterVC *)vc didApplyFilter:(WKChannelHistorySearchFilter *)filter {
    [vc dismissViewControllerAnimated:YES completion:nil];
    if (self.currentTab == WKGlobalSearchV2TabMessages) {
        [self.groupsVM applyFilter:filter];
    } else if (self.currentTab == WKGlobalSearchV2TabFiles) {
        [self.filesVM applyFilter:filter];
    }
}

#pragma mark - VM delegates

- (void)globalMsgGroupsVMDidChangeState:(WKGlobalMsgGroupsVM *)vm {
    if (self.currentTab == WKGlobalSearchV2TabMessages) { [self.tableView reloadData]; [self updateAllTransientUI]; }
}
- (void)globalMsgGroupsVMKeywordExceedLimit:(WKGlobalMsgGroupsVM *)vm { [self showKeywordLimitToast]; }
- (void)globalMsgGroupsVM:(WKGlobalMsgGroupsVM *)vm shouldFallbackToLocalWithError:(NSError *)error { [self fallbackToLocal]; }

- (void)globalContactsVMDidChangeState:(WKGlobalContactsVM *)vm {
    if (self.currentTab == WKGlobalSearchV2TabContacts || self.currentTab == WKGlobalSearchV2TabGroups) {
        [self.tableView reloadData]; [self updateAllTransientUI];
    }
}
- (void)globalContactsVMKeywordExceedLimit:(WKGlobalContactsVM *)vm { [self showKeywordLimitToast]; }

- (void)globalFilesVMDidChangeState:(WKGlobalFilesVM *)vm {
    if (self.currentTab == WKGlobalSearchV2TabFiles) { [self.tableView reloadData]; [self updateAllTransientUI]; }
}
- (void)globalFilesVMKeywordExceedLimit:(WKGlobalFilesVM *)vm { [self showKeywordLimitToast]; }
- (void)globalFilesVM:(WKGlobalFilesVM *)vm shouldFallbackToLocalWithError:(NSError *)error { [self fallbackToLocal]; }

- (void)showKeywordLimitToast {
    if (self.hasShownKeywordLimitToast) return;
    self.hasShownKeywordLimitToast = YES;
    [self.view showMsg:[NSString stringWithFormat:LLang(@"关键词最多 %ld 个字"), (long)WKChannelHistorySearchKeywordMaxRunes]];
}

/// SEARCH_DISABLED：运行时回落到旧本地搜索栈（带上当前 keyword/searchType）。
- (void)fallbackToLocal {
    if (self.didFallback) return;
    self.didFallback = YES;
    WKGlobalSearchResultController *vc = [WKGlobalSearchResultController new];
    vc.keyword = self.currentKeyword;
    vc.searchType = [self legacySearchType];
    UINavigationController *nav = self.navigationController;
    if (nav) {
        NSMutableArray *stack = [nav.viewControllers mutableCopy];
        [stack removeObject:self];
        [stack addObject:vc];
        [nav setViewControllers:stack animated:NO];
    } else {
        [[WKNavigationManager shared] pushViewController:vc animated:NO];
    }
}

- (WKHistoryMessageSearchType)legacySearchType {
    switch (self.currentTab) {
        case WKGlobalSearchV2TabContacts: return WKHistoryMessageSearchTypeContacts;
        case WKGlobalSearchV2TabMessages: return WKHistoryMessageSearchTypeMessages;
        default: return WKHistoryMessageSearchTypeAll;
    }
}

#pragma mark - transient UI (empty / footer / chip / banner)

- (void)updateAllTransientUI {
    [self updateEmptyState];
    [self updateLoadMoreFooter];
    [self updateChipBar];
    [self updateMoreBanner];
    [self.view setNeedsLayout];
}

- (NSInteger)activeRowCount {
    switch (self.currentTab) {
        case WKGlobalSearchV2TabMessages: return self.groupsVM.buckets.count;
        case WKGlobalSearchV2TabContacts: return self.contactsVM.friendModels.count;
        case WKGlobalSearchV2TabGroups:   return self.contactsVM.groupModels.count;
        case WKGlobalSearchV2TabFiles:    return self.filesVM.items.count;
    }
    return 0;
}

- (BOOL)activeIsLoadingFirstPage {
    switch (self.currentTab) {
        case WKGlobalSearchV2TabMessages: return self.groupsVM.isLoading;
        case WKGlobalSearchV2TabContacts:
        case WKGlobalSearchV2TabGroups:   return self.contactsVM.isLoading;
        case WKGlobalSearchV2TabFiles:    return self.filesVM.isLoadingFirstPage;
    }
    return NO;
}

- (BOOL)activeQueryStarted {
    switch (self.currentTab) {
        case WKGlobalSearchV2TabMessages: return self.groupsVM.queryStarted;
        case WKGlobalSearchV2TabContacts:
        case WKGlobalSearchV2TabGroups:   return self.contactsVM.queryStarted;
        case WKGlobalSearchV2TabFiles:    return self.filesVM.queryStarted;
    }
    return NO;
}

- (NSError *)activeFirstPageError {
    switch (self.currentTab) {
        case WKGlobalSearchV2TabMessages: return self.groupsVM.error;
        case WKGlobalSearchV2TabContacts:
        case WKGlobalSearchV2TabGroups:   return self.contactsVM.error;
        case WKGlobalSearchV2TabFiles:    return self.filesVM.firstPageError;
    }
    return nil;
}

- (void)updateEmptyState {
    if ([self activeRowCount] > 0) { self.emptyView.hidden = YES; return; }
    self.emptyView.hidden = NO;
    if ([WKNetworkListener shared].hasNetwork == NO) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeOffline primary:nil secondary:nil];
    } else if ([self activeFirstPageError]) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeError primary:nil secondary:nil];
    } else if ([self activeIsLoadingFirstPage]) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeLoading primary:nil secondary:nil];
    } else if (![self activeQueryStarted]) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeWaitingInput primary:nil secondary:nil];
    } else {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeNoResults primary:nil secondary:nil];
    }
}

- (void)updateLoadMoreFooter {
    // 仅文件 tab 有 cursor 翻页；Messages(L1 无翻页) / 联系人 / 群组 不挂 footer。
    if (self.currentTab != WKGlobalSearchV2TabFiles) {
        self.tableView.mj_footer.hidden = YES;
        [self.tableView.mj_footer endRefreshing];
        return;
    }
    BOOL hasContent = self.filesVM.items.count > 0;
    self.tableView.mj_footer.hidden = !hasContent;
    if (self.filesVM.nextPageError) {
        [self.tableView.mj_footer endRefreshing];
        [self.view showMsg:LLang(@"加载更多失败，请重试")];
    } else if (self.filesVM.isLoadingNextPage) {
        // 自动转
    } else if (!self.filesVM.hasMore && hasContent) {
        [self.tableView.mj_footer endRefreshingWithNoMoreData];
    } else {
        [self.tableView.mj_footer endRefreshing];
        [self.tableView.mj_footer resetNoMoreData];
    }
}

- (void)onLoadMore {
    if (self.currentTab == WKGlobalSearchV2TabFiles) [self.filesVM loadMore];
}

- (void)updateChipBar {
    WKChannelHistorySearchFilter *f = [self activeFilter];
    if (!f) { self.chipBar.chips = @[]; self.chipBar.hidden = YES; return; }
    NSMutableArray<WKChannelHistoryFilterChipDescriptor *> *chips = [NSMutableArray array];
    __weak typeof(self) ws = self;
    if (f.senderUids.count > 0) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"sender";
        c.title = [NSString stringWithFormat:LLang(@"发送者: %ld"), (long)f.senderUids.count];
        c.onClear = ^{ WKChannelHistorySearchFilter *nf = [[ws activeFilter] copy]; nf.senderUids = nil; [ws applyActiveFilter:nf]; };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.channels.count > 0) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"channels";
        c.title = [NSString stringWithFormat:LLang(@"群聊或子区: %ld"), (long)f.channels.count];
        c.onClear = ^{ WKChannelHistorySearchFilter *nf = [[ws activeFilter] copy]; nf.channels = nil; [ws applyActiveFilter:nf]; };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.memberUids.count > 0) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"members";
        c.title = [NSString stringWithFormat:LLang(@"包含成员: %ld"), (long)f.memberUids.count];
        c.onClear = ^{ WKChannelHistorySearchFilter *nf = [[ws activeFilter] copy]; nf.memberUids = nil; [ws applyActiveFilter:nf]; };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.channelTypes.count > 0) {
        BOOL dm = [f.channelTypes containsObject:@1];
        BOOL grp = [f.channelTypes containsObject:@2] || [f.channelTypes containsObject:@5];
        NSString *label = (dm && grp) ? LLang(@"单聊+群聊") : (dm ? LLang(@"单聊") : LLang(@"群聊"));
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"chatType";
        c.title = [NSString stringWithFormat:LLang(@"聊天类型: %@"), label];
        c.onClear = ^{ WKChannelHistorySearchFilter *nf = [[ws activeFilter] copy]; nf.channelTypes = nil; [ws applyActiveFilter:nf]; };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.startDate || f.endDate) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"date";
        c.title = [self dateRangeLabelFromStart:f.startDate end:f.endDate];
        c.onClear = ^{ WKChannelHistorySearchFilter *nf = [[ws activeFilter] copy]; nf.startDate = nil; nf.endDate = nil; [ws applyActiveFilter:nf]; };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.sort == WKChannelHistorySearchSortTimeAsc) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"sort";
        c.title = LLang(@"时间正序");
        c.onClear = ^{ WKChannelHistorySearchFilter *nf = [[ws activeFilter] copy]; nf.sort = WKChannelHistorySearchSortTimeDesc; [ws applyActiveFilter:nf]; };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.contentTypes.count > 0) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"contentTypes";
        c.title = [NSString stringWithFormat:LLang(@"消息类型: %ld"), (long)f.contentTypes.count];
        c.onClear = ^{ WKChannelHistorySearchFilter *nf = [[ws activeFilter] copy]; nf.contentTypes = nil; [ws applyActiveFilter:nf]; };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    if (f.fileExts.count > 0) {
        WKChannelHistoryFilterChipDescriptor *c = [WKChannelHistoryFilterChipDescriptor new];
        c.key = @"fileExts";
        c.title = LLang(@"文件类型");
        c.onClear = ^{ WKChannelHistorySearchFilter *nf = [[ws activeFilter] copy]; nf.fileExts = nil; [ws applyActiveFilter:nf]; };
        c.onTap = ^{ [ws onFilterTap]; };
        [chips addObject:c];
    }
    self.chipBar.chips = chips;
    self.chipBar.hidden = chips.count == 0;
}

- (void)applyActiveFilter:(WKChannelHistorySearchFilter *)filter {
    if (self.currentTab == WKGlobalSearchV2TabMessages) [self.groupsVM applyFilter:filter];
    else if (self.currentTab == WKGlobalSearchV2TabFiles) [self.filesVM applyFilter:filter];
}

- (NSString *)dateRangeLabelFromStart:(NSDate *)start end:(NSDate *)end {
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [NSDateFormatter new];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.dateFormat = @"yyyy/MM/dd";
    });
    NSString *s = start ? [fmt stringFromDate:start] : LLang(@"最早");
    NSString *e = end ? [fmt stringFromDate:end] : LLang(@"至今");
    return [NSString stringWithFormat:@"%@ ~ %@", s, e];
}

- (void)updateMoreBanner {
    BOOL show = (self.currentTab == WKGlobalSearchV2TabMessages) && self.groupsVM.hasMore && self.groupsVM.buckets.count > 0;
    if (!show) {
        self.tableView.tableFooterView = nil;
        return;
    }
    NSString *text;
    if (self.groupsVM.totalGroups > 0) {
        text = [NSString stringWithFormat:LLang(@"已显示最活跃 %ld 个会话，另有约 %ld 个，请缩小搜索范围"),
                (long)self.groupsVM.buckets.count, (long)self.groupsVM.totalGroups];
    } else {
        text = LLang(@"已显示最活跃会话，还有更多结果，请缩小搜索范围");
    }
    CGFloat w = self.tableView.lim_width;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 44.0f)];
    footer.backgroundColor = [[UIColor systemYellowColor] colorWithAlphaComponent:0.12];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 32, 44.0f)];
    lbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    lbl.textColor = [UIColor darkGrayColor];
    lbl.numberOfLines = 2;
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.text = text;
    [footer addSubview:lbl];
    self.tableView.tableFooterView = footer;
}

#pragma mark - network listener

- (void)networkListenerStatusChange:(WKNetworkListener *)listener {
    BOOL wasOffline = !self.offlineBar.hidden;
    [self refreshOfflineBarVisibility];
    [self updateEmptyState];
    if (wasOffline && listener.hasNetwork) [self syncActiveVM];
}

- (void)refreshOfflineBarVisibility {
    self.offlineBar.hidden = [WKNetworkListener shared].hasNetwork;
    [self.view setNeedsLayout];
}

#pragma mark - table datasource / delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self activeRowCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (self.currentTab) {
        case WKGlobalSearchV2TabMessages: {
            WKGlobalSearchGroupBucketCell *c = [tableView dequeueReusableCellWithIdentifier:[WKGlobalSearchGroupBucketCell reuseIdentifier] forIndexPath:indexPath];
            [c applyBucket:self.groupsVM.buckets[indexPath.row] keyword:self.currentKeyword];
            return c;
        }
        case WKGlobalSearchV2TabContacts:
        case WKGlobalSearchV2TabGroups: {
            WKSearchContactsCell *c = [tableView dequeueReusableCellWithIdentifier:@"WKGlobalContactsCell" forIndexPath:indexPath];
            [c refresh:[self contactModelAtIndex:indexPath.row]];
            return c;
        }
        case WKGlobalSearchV2TabFiles: {
            WKChannelHistoryFileCell *c = [tableView dequeueReusableCellWithIdentifier:[WKChannelHistoryFileCell reuseIdentifier] forIndexPath:indexPath];
            [c applyItem:self.filesVM.items[indexPath.row] keyword:self.currentKeyword];
            return c;
        }
    }
    return [UITableViewCell new];
}

- (WKSearchContactsModel *)contactModelAtIndex:(NSInteger)idx {
    NSArray<WKSearchContactsModel *> *list = (self.currentTab == WKGlobalSearchV2TabGroups) ? self.contactsVM.groupModels : self.contactsVM.friendModels;
    return (idx < (NSInteger)list.count) ? list[idx] : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (self.currentTab) {
        case WKGlobalSearchV2TabMessages: return [WKGlobalSearchGroupBucketCell cellHeight];
        case WKGlobalSearchV2TabContacts:
        case WKGlobalSearchV2TabGroups: {
            WKSearchContactsModel *m = [self contactModelAtIndex:indexPath.row];
            CGFloat h = m ? [WKSearchContactsCell sizeForModel:m].height : 0;
            return h > 0 ? h : 60.0f;
        }
        case WKGlobalSearchV2TabFiles: return [WKChannelHistoryFileCell cellHeight];
    }
    return 60.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.searchInput resignFirstResponder];
    switch (self.currentTab) {
        case WKGlobalSearchV2TabMessages: {
            if (indexPath.row >= (NSInteger)self.groupsVM.buckets.count) return;
            [self openBucket:self.groupsVM.buckets[indexPath.row]];
            break;
        }
        case WKGlobalSearchV2TabContacts:
        case WKGlobalSearchV2TabGroups: {
            WKSearchContactsModel *m = [self contactModelAtIndex:indexPath.row];
            if (m.onClick) m.onClick(m, indexPath);
            break;
        }
        case WKGlobalSearchV2TabFiles: {
            if (indexPath.row >= (NSInteger)self.filesVM.items.count) return;
            [self openFileItem:self.filesVM.items[indexPath.row]];
            break;
        }
    }
}

#pragma mark - open

- (void)openBucket:(WKGlobalSearchGroupBucket *)bucket {
    WKGlobalMsgDetailVC *vc = [WKGlobalMsgDetailVC new];
    vc.bucket = bucket;
    vc.keyword = self.currentKeyword;
    vc.filter = [self.groupsVM.filter copy];
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)openFileItem:(WKChannelHistorySearchItem *)item {
    NSString *url = item.fileDownloadUrl.length > 0 ? item.fileDownloadUrl : item.filePreviewUrl;
    if (url.length == 0) { [self.view showMsg:LLang(@"文件链接不可用")]; return; }
    UIView *hudView = self.view;
    [hudView showHUD:LLang(@"下载中…")];
    __weak typeof(self) ws = self;
    WKChannelHistorySearchItem *captured = item;
    [WKChannelHistoryFileDownloader downloadRemoteUrl:url
                                             fileName:item.fileName
                                           onProgress:^(double progress) {}
                                           onComplete:^(NSURL *localURL, NSError *error) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        [hudView hideHud];
        if (error || !localURL) { [ss.view showMsg:error.localizedDescription ?: LLang(@"文件下载失败")]; return; }
        WKChannelHistoryFilePreviewVC *vc = [[WKChannelHistoryFilePreviewVC alloc] initWithFileURL:localURL title:captured.fileName];
        vc.historyItem = captured;
        vc.onLocate = ^(WKChannelHistorySearchItem *it) {
            NSString *cid = it.channelId; NSInteger ct = it.channelType;
            if (cid.length > 0 && it.messageSeq > 0) [WKConversationRouter openChannelId:cid channelType:ct messageSeq:(uint32_t)it.messageSeq];
        };
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    }];
}

@end
