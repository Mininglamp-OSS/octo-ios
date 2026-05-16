//
//  WKThreadListVC.m
//  WuKongBase
//

#import "WKThreadListVC.h"
#import "WKThreadListCell.h"
#import "WKThreadModel.h"
#import "WKThreadService.h"
#import "WKNavigationManager.h"
#import "WKConversationVC.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import "WKApp.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

static NSString *const kCellIdentifier = @"WKThreadListCell";
static const NSInteger kPageSize = 15;

@interface WKThreadListVC () <UITableViewDataSource, UITableViewDelegate, WKConversationManagerDelegate, WKReminderManagerDelegate>

@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *createBtn;
@property (nonatomic, strong) UILabel *emptyLbl;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIView *tableFooterView;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;

// 当前展示的线程（按当前 tab 过滤后）
@property (nonatomic, strong) NSArray<WKThreadModel *> *threads;
// 所有已加载的原始线程（跨页累积）
@property (nonatomic, strong) NSMutableArray<WKThreadModel *> *allLoadedThreads;

@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL isLoadingMore;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger totalCount;

@end

@implementation WKThreadListVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = LLang(@"子区列表");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    [self.view addSubview:self.segmentControl];
    [self.view addSubview:self.tableView];
    [self.view addSubview:self.createBtn];
    [self.view addSubview:self.emptyLbl];

    self.threads = @[];
    self.allLoadedThreads = [NSMutableArray array];
    [self loadThreads];

    [[WKSDK shared].conversationManager addDelegate:self];
    [[WKReminderManager shared] addDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadThreads];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat navBottom = [self getNavBottom];
    CGFloat padding = 16.0f;

    self.segmentControl.frame = CGRectMake(padding, navBottom + 12, self.view.lim_width - padding * 2, 32);

    CGFloat tableTop = self.segmentControl.lim_bottom + 10;
    CGFloat tableBottom = 60 + self.view.safeAreaInsets.bottom + 12;
    self.tableView.frame = CGRectMake(0, tableTop, self.view.lim_width, self.view.lim_height - tableTop - tableBottom);

    CGFloat btnWidth = self.view.lim_width - padding * 2;
    self.createBtn.frame = CGRectMake(padding,
                                       self.view.lim_height - 60 - self.view.safeAreaInsets.bottom,
                                       btnWidth,
                                       44);

    self.emptyLbl.frame = CGRectMake(0, tableTop + 80, self.view.lim_width, 60);
}

#pragma mark - Data

- (void)loadThreads {
    if (self.loading) return;
    self.loading = YES;
    self.currentPage = 1;
    [self.allLoadedThreads removeAllObjects];

    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] listThreads:self.groupNo pageIndex:1 pageSize:kPageSize].then(^(NSDictionary *result) {
        weakSelf.loading = NO;
        [weakSelf.refreshControl endRefreshing];
        weakSelf.totalCount = [result[@"count"] integerValue];
        NSArray<WKThreadModel *> *list = result[@"list"] ?: @[];
        [weakSelf.allLoadedThreads addObjectsFromArray:list];
        [weakSelf filterAndReload];
        [weakSelf updateFooterVisibility];
    }).catch(^(NSError *error) {
        weakSelf.loading = NO;
        [weakSelf.refreshControl endRefreshing];
        [weakSelf.view showMsg:error.domain];
    });
}

- (void)loadMoreThreads {
    if (self.isLoadingMore || self.loading) return;
    // 只对活跃 tab 分页（服务端只返回活跃子区）
    if (self.segmentControl.selectedSegmentIndex != 0) return;
    // 已加载全部
    if (self.allLoadedThreads.count >= (NSUInteger)self.totalCount) return;

    self.isLoadingMore = YES;
    [self.footerSpinner startAnimating];
    NSInteger nextPage = self.currentPage + 1;

    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] listThreads:self.groupNo pageIndex:nextPage pageSize:kPageSize].then(^(NSDictionary *result) {
        weakSelf.isLoadingMore = NO;
        [weakSelf.footerSpinner stopAnimating];
        weakSelf.totalCount = [result[@"count"] integerValue];
        NSArray<WKThreadModel *> *newItems = result[@"list"] ?: @[];
        if (newItems.count == 0) return;
        weakSelf.currentPage = nextPage;
        [weakSelf.allLoadedThreads addObjectsFromArray:newItems];
        [weakSelf filterAndReload];
        [weakSelf updateFooterVisibility];
    }).catch(^(NSError *error) {
        weakSelf.isLoadingMore = NO;
        [weakSelf.footerSpinner stopAnimating];
    });
}

- (void)filterAndReload {
    NSInteger selectedStatus = (self.segmentControl.selectedSegmentIndex == 0)
        ? WKThreadStatusActive
        : WKThreadStatusArchived;

    NSMutableArray *filtered = [NSMutableArray array];
    for (WKThreadModel *t in self.allLoadedThreads) {
        if (t.status == selectedStatus) {
            [filtered addObject:t];
        }
    }
    self.threads = [filtered copy];
    [self.tableView reloadData];
    self.emptyLbl.hidden = (self.threads.count > 0);
}

- (void)updateFooterVisibility {
    BOOL hasMore = (self.allLoadedThreads.count < (NSUInteger)self.totalCount)
                   && (self.segmentControl.selectedSegmentIndex == 0);
    self.tableView.tableFooterView = hasMore ? self.tableFooterView : [[UIView alloc] init];
}

#pragma mark - UIScrollViewDelegate (load more on scroll)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.frame.size.height;
    if (contentHeight > frameHeight && offsetY > contentHeight - frameHeight - 80) {
        [self loadMoreThreads];
    }
}

#pragma mark - Actions

- (void)onSegmentChanged:(UISegmentedControl *)sender {
    // 切换 tab 时先用已加载数据过滤展示，不重新请求
    [self filterAndReload];
    [self updateFooterVisibility];
}

- (void)onRefresh {
    [self loadThreads];
}

- (void)onCreateThread {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"创建子区")
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = LLang(@"子区名称 (最多50字)");
    }];

    __weak typeof(self) weakSelf = self;
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:LLang(@"创建") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length == 0) return;
        if (name.length > 50) {
            name = [name substringToIndex:50];
        }
        [weakSelf doCreateThread:name sourceMessageId:nil];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:cancelAction];
    [alert addAction:createAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doCreateThread:(NSString *)name sourceMessageId:(NSString *)sourceMessageId {
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] createThread:self.groupNo name:name sourceMessageId:sourceMessageId sourceMessagePayload:nil].then(^(WKThreadModel *thread) {
        [[WKThreadService shared] joinThread:thread.shortId].then(^(id result) {
            [weakSelf openThread:thread];
        }).catch(^(NSError *error) {
            [weakSelf openThread:thread];
        });
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

- (void)openThread:(WKThreadModel *)thread {
    WKChannel *channel = [thread toChannel];
    [[WKApp shared] invoke:WKPOINT_CONVERSATION_SHOW param:channel];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.threads.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKThreadListCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
    WKThreadModel *thread = self.threads[indexPath.row];
    [cell refreshWithModel:thread];
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKThreadModel *thread = self.threads[indexPath.row];
    BOOL hasPreview = NO;
    WKChannel *threadChannel = [WKChannel channelID:thread.channelId channelType:WK_COMMUNITY_TOPIC];
    NSArray<WKReminder *> *reminders = [[WKReminderDB shared] getWaitDoneReminder:threadChannel];
    for (WKReminder *r in reminders) {
        if (r.type == WKReminderTypeMentionMe) { hasPreview = YES; break; }
    }
    if (!hasPreview) {
        WKConversation *threadConv = [[WKSDK shared].conversationManager getConversation:threadChannel];
        if (threadConv && threadConv.lastMessage && threadConv.lastMessage.content) {
            NSString *digest = [threadConv.lastMessage.content conversationDigest];
            if (digest.length > 0) hasPreview = YES;
        }
    }
    if (!hasPreview && thread.lastMessageContent.length > 0) {
        hasPreview = YES;
    }
    return hasPreview ? 80.0f : 62.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WKThreadModel *thread = self.threads[indexPath.row];

    __weak typeof(self) weakSelf = self;
    if (!thread.isMember) {
        [[WKThreadService shared] joinThread:thread.shortId].then(^(id result) {
            [weakSelf openThread:thread];
        }).catch(^(NSError *error) {
            [weakSelf openThread:thread];
        });
    } else {
        [self openThread:thread];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKThreadModel *thread = self.threads[indexPath.row];
    NSString *currentUid = [WKSDK shared].options.connectInfo.uid;
    BOOL isCreator = [thread.creatorUid isEqualToString:currentUid];

    NSMutableArray *actions = [NSMutableArray array];

    if (isCreator) {
        UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                  title:LLang(@"删除")
                                                                                handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [self confirmDeleteThread:thread];
            completionHandler(YES);
        }];
        [actions addObject:deleteAction];

        if (thread.status == WKThreadStatusActive) {
            UIContextualAction *archiveAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                       title:LLang(@"归档")
                                                                                     handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
                [self archiveThread:thread];
                completionHandler(YES);
            }];
            archiveAction.backgroundColor = [UIColor orangeColor];
            [actions addObject:archiveAction];
        } else if (thread.status == WKThreadStatusArchived) {
            UIContextualAction *unarchiveAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                         title:LLang(@"取消归档")
                                                                                       handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
                [self unarchiveThread:thread];
                completionHandler(YES);
            }];
            unarchiveAction.backgroundColor = [UIColor systemGreenColor];
            [actions addObject:unarchiveAction];
        }
    } else if (thread.isMember) {
        UIContextualAction *leaveAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                                  title:LLang(@"退出")
                                                                                handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [self leaveThread:thread];
            completionHandler(YES);
        }];
        leaveAction.backgroundColor = [UIColor grayColor];
        [actions addObject:leaveAction];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

#pragma mark - Thread Operations

- (void)confirmDeleteThread:(WKThreadModel *)thread {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LLang(@"删除子区")
                                                                  message:[NSString stringWithFormat:@"%@「%@」?", LLang(@"确定删除子区"), thread.name]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[WKThreadService shared] deleteThread:weakSelf.groupNo shortId:thread.shortId].then(^(id result) {
            [weakSelf loadThreads];
        }).catch(^(NSError *error) {
            [weakSelf.view showMsg:error.domain];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)leaveThread:(WKThreadModel *)thread {
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] leaveThread:thread.shortId].then(^(id result) {
        [weakSelf loadThreads];
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

- (void)archiveThread:(WKThreadModel *)thread {
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] archiveThread:self.groupNo shortId:thread.shortId].then(^(id result) {
        [weakSelf loadThreads];
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

- (void)unarchiveThread:(WKThreadModel *)thread {
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] unarchiveThread:self.groupNo shortId:thread.shortId].then(^(id result) {
        [weakSelf loadThreads];
    }).catch(^(NSError *error) {
        [weakSelf.view showMsg:error.domain];
    });
}

#pragma mark - Lazy Init

- (UISegmentedControl *)segmentControl {
    if (!_segmentControl) {
        _segmentControl = [[UISegmentedControl alloc] initWithItems:@[LLang(@"活跃"), LLang(@"已归档")]];
        _segmentControl.selectedSegmentIndex = 0;
        [_segmentControl addTarget:self action:@selector(onSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    }
    return _segmentControl;
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.separatorInset = UIEdgeInsetsMake(0, 58, 0, 0);
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.tableFooterView = [[UIView alloc] init];
        [_tableView registerClass:[WKThreadListCell class] forCellReuseIdentifier:kCellIdentifier];
        _tableView.refreshControl = self.refreshControl;
    }
    return _tableView;
}

- (UIRefreshControl *)refreshControl {
    if (!_refreshControl) {
        _refreshControl = [[UIRefreshControl alloc] init];
        [_refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    }
    return _refreshControl;
}

- (UIView *)tableFooterView {
    if (!_tableFooterView) {
        _tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 52)];
        _footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _footerSpinner.center = CGPointMake(UIScreen.mainScreen.bounds.size.width / 2, 26);
        [_tableFooterView addSubview:_footerSpinner];
    }
    return _tableFooterView;
}

- (UIButton *)createBtn {
    if (!_createBtn) {
        _createBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_createBtn setTitle:[NSString stringWithFormat:@"+ %@", LLang(@"创建子区")] forState:UIControlStateNormal];
        [_createBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _createBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        _createBtn.backgroundColor = [WKApp shared].config.themeColor;
        _createBtn.layer.cornerRadius = 22;
        _createBtn.layer.masksToBounds = YES;
        [_createBtn addTarget:self action:@selector(onCreateThread) forControlEvents:UIControlEventTouchUpInside];
    }
    return _createBtn;
}

- (UILabel *)emptyLbl {
    if (!_emptyLbl) {
        _emptyLbl = [[UILabel alloc] init];
        _emptyLbl.text = LLang(@"暂无子区\n创建一个来讨论特定话题");
        _emptyLbl.numberOfLines = 2;
        _emptyLbl.textAlignment = NSTextAlignmentCenter;
        _emptyLbl.font = [UIFont systemFontOfSize:14];
        _emptyLbl.textColor = [UIColor lightGrayColor];
        _emptyLbl.hidden = YES;
    }
    return _emptyLbl;
}

- (void)dealloc {
    [[WKSDK shared].conversationManager removeDelegate:self];
    [[WKReminderManager shared] removeDelegate:self];
}

#pragma mark - WKConversationManagerDelegate

- (void)onConversationUpdate:(NSArray<WKConversation *> *)conversations {
    NSString *prefix = [NSString stringWithFormat:@"%@____", self.groupNo];
    for (WKConversation *conv in conversations) {
        if (conv.channel.channelType == WK_COMMUNITY_TOPIC && [conv.channel.channelId hasPrefix:prefix]) {
            [self.tableView reloadData];
            return;
        }
    }
}

#pragma mark - WKReminderManagerDelegate

- (void)reminderManager:(WKReminderManager *)manager didChange:(WKChannel *)channel reminders:(NSArray<WKReminder *> *)reminders {
    NSString *prefix = [NSString stringWithFormat:@"%@____", self.groupNo];
    if (channel.channelType == WK_COMMUNITY_TOPIC && [channel.channelId hasPrefix:prefix]) {
        [self.tableView reloadData];
    }
}

@end
