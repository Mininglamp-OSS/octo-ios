//
//  WKGlobalMsgDetailVC.m
//  WuKongBase
//

#import "WKGlobalMsgDetailVC.h"
#import "WKGlobalMsgDetailVM.h"
#import "WKChannelHistoryMessageCell.h"
#import "WKChannelHistoryFileCell.h"
#import "WKChannelHistorySearchEmptyView.h"
#import "WKChannelHistoryFilePreviewVC.h"
#import "WKChannelHistoryFileDownloader.h"
#import "WKConversationRouter.h"
#import "WKNavigationManager.h"
#import "WKNetworkListener.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "UIView+WKCommon.h"
#import <MJRefresh/MJRefresh.h>

@interface WKGlobalMsgDetailVC () <
    UITableViewDataSource,
    UITableViewDelegate,
    WKGlobalMsgDetailVMDelegate,
    WKNetworkListenerDelegate
>
@property (nonatomic, strong) WKGlobalMsgDetailVM *vm;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) WKChannelHistorySearchEmptyView *emptyView;
@end

@implementation WKGlobalMsgDetailVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    NSAssert(self.bucket != nil, @"WKGlobalMsgDetailVC.bucket must be set before push");
    NSString *title = self.bucket.displayTitle.length > 0 ? self.bucket.displayTitle : LLang(@"聊天记录");
    self.title = title;
    self.navigationBar.title = title;

    self.vm = [[WKGlobalMsgDetailVM alloc] initWithBucket:self.bucket keyword:self.keyword filter:self.filter];
    self.vm.delegate = self;

    [self setupContent];
    [[WKNetworkListener shared] addDelegate:self];

    [self.vm refresh];
}

- (void)dealloc {
    [[WKNetworkListener shared] removeDelegate:self];
    [self.vm cancelInFlight];
}

- (void)setupContent {
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
    __weak typeof(self) ws = self;
    self.tableView.mj_footer = [MJRefreshAutoNormalFooter footerWithRefreshingBlock:^{ [ws.vm loadMore]; }];
    self.tableView.mj_footer.hidden = YES;
    [self.view addSubview:self.tableView];

    self.emptyView = [WKChannelHistorySearchEmptyView new];
    self.emptyView.hidden = YES;
    self.emptyView.onRetry = ^{ [ws.vm refresh]; };
    [self.view addSubview:self.emptyView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = [self getNavBottom];
    CGRect rect = CGRectMake(0, top, self.view.lim_width, self.view.lim_height - top);
    self.tableView.frame = rect;
    self.emptyView.frame = rect;
}

#pragma mark - VM delegate

- (void)globalMsgDetailVMDidChangeState:(WKGlobalMsgDetailVM *)vm {
    [self.tableView reloadData];
    [self updateEmptyState];
    [self updateLoadMoreFooter];
}

- (void)updateLoadMoreFooter {
    BOOL hasContent = self.vm.items.count > 0;
    self.tableView.mj_footer.hidden = !hasContent;
    if (self.vm.nextPageError) {
        [self.tableView.mj_footer endRefreshing];
        [self.view showMsg:LLang(@"加载更多失败，请重试")];
    } else if (self.vm.isLoadingNextPage) {
        // MJRefresh footer 自动转
    } else if (!self.vm.hasMore && hasContent) {
        [self.tableView.mj_footer endRefreshingWithNoMoreData];
    } else {
        [self.tableView.mj_footer endRefreshing];
        [self.tableView.mj_footer resetNoMoreData];
    }
}

- (void)updateEmptyState {
    if (self.vm.items.count > 0) { self.emptyView.hidden = YES; return; }
    self.emptyView.hidden = NO;
    if ([WKNetworkListener shared].hasNetwork == NO) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeOffline primary:nil secondary:nil];
    } else if (self.vm.firstPageError) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeError primary:nil secondary:nil];
    } else if (self.vm.isLoadingFirstPage) {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeLoading primary:nil secondary:nil];
    } else {
        [self.emptyView applyMode:WKChannelHistorySearchEmptyModeNoResults primary:nil secondary:nil];
    }
}

#pragma mark - network listener

- (void)networkListenerStatusChange:(WKNetworkListener *)listener {
    BOOL recovered = listener.hasNetwork && self.vm.items.count == 0;
    [self updateEmptyState];
    if (recovered) [self.vm refresh];
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.vm.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKChannelHistorySearchItem *item = self.vm.items[indexPath.row];
    NSString *kw = self.vm.keyword;
    if (item.kind == WKChannelHistorySearchItemKindFile) {
        WKChannelHistoryFileCell *c = [tableView dequeueReusableCellWithIdentifier:[WKChannelHistoryFileCell reuseIdentifier] forIndexPath:indexPath];
        [c applyItem:item keyword:kw];
        return c;
    }
    WKChannelHistoryMessageCell *c = [tableView dequeueReusableCellWithIdentifier:[WKChannelHistoryMessageCell reuseIdentifier] forIndexPath:indexPath];
    [c applyItem:item keyword:kw];
    return c;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKChannelHistorySearchItem *item = self.vm.items[indexPath.row];
    if (item.kind == WKChannelHistorySearchItemKindFile) return [WKChannelHistoryFileCell cellHeight];
    return [WKChannelHistoryMessageCell heightForItem:item width:tableView.lim_width];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.vm.items.count) return;
    [self openItem:self.vm.items[indexPath.row]];
}

#pragma mark - tap

- (void)openItem:(WKChannelHistorySearchItem *)item {
    if (item.kind == WKChannelHistorySearchItemKindFile) {
        [self openFileItem:item];
        return;
    }
    [self locateMessageItem:item];
}

- (void)locateMessageItem:(WKChannelHistorySearchItem *)item {
    if (!item.canLocate) { [self.view showMsg:LLang(@"无法定位到该消息")]; return; }
    NSString *cid = item.channelId.length > 0 ? item.channelId : self.bucket.channelId;
    NSInteger ct = item.channelType > 0 ? item.channelType : self.bucket.channelType;
    [WKConversationRouter openChannelId:cid channelType:ct messageSeq:(uint32_t)item.messageSeq];
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
        if (error || !localURL) {
            [ss.view showMsg:error.localizedDescription ?: LLang(@"文件下载失败")];
            return;
        }
        WKChannelHistoryFilePreviewVC *vc = [[WKChannelHistoryFilePreviewVC alloc] initWithFileURL:localURL title:captured.fileName];
        vc.historyItem = captured;
        vc.onLocate = ^(WKChannelHistorySearchItem *it) { [ss locateMessageItem:it]; };
        [[WKNavigationManager shared] pushViewController:vc animated:YES];
    }];
}

@end
