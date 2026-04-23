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

@interface WKThreadListVC () <UITableViewDataSource, UITableViewDelegate, WKConversationManagerDelegate, WKReminderManagerDelegate>

@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *createBtn;
@property (nonatomic, strong) UILabel *emptyLbl;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@property (nonatomic, strong) NSArray<WKThreadModel *> *threads;
@property (nonatomic, assign) BOOL loading;

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
    [self loadThreads];

    // 监听会话更新和@提醒变化，实时刷新红点和预览
    [[WKSDK shared].conversationManager addDelegate:self];
    [[WKReminderManager shared] addDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 从子区聊天/设置页返回时刷新列表
    [self loadThreads];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat navBottom = [self getNavBottom];
    CGFloat padding = 16.0f;

    self.segmentControl.frame = CGRectMake(padding, navBottom + 12, self.view.lim_width - padding * 2, 32);

    CGFloat tableTop = self.segmentControl.lim_bottom + 10;
    CGFloat tableBottom = 80; // 为创建按钮留空间
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
    self.loading = YES;
    __weak typeof(self) weakSelf = self;
    [[WKThreadService shared] listThreads:self.groupNo].then(^(NSArray<WKThreadModel *> *threads) {
        weakSelf.loading = NO;
        [weakSelf.refreshControl endRefreshing];
        [weakSelf filterAndReload:threads];
    }).catch(^(NSError *error) {
        weakSelf.loading = NO;
        [weakSelf.refreshControl endRefreshing];
        [weakSelf.view showMsg:error.domain];
    });
}

- (void)filterAndReload:(NSArray<WKThreadModel *> *)allThreads {
    NSInteger selectedStatus = (self.segmentControl.selectedSegmentIndex == 0)
        ? WKThreadStatusActive
        : WKThreadStatusArchived;

    NSMutableArray *filtered = [NSMutableArray array];
    for (WKThreadModel *t in allThreads) {
        if (t.status == selectedStatus) {
            [filtered addObject:t];
        }
    }
    self.threads = [filtered copy];
    [self.tableView reloadData];
    self.emptyLbl.hidden = (self.threads.count > 0);
}

#pragma mark - Actions

- (void)onSegmentChanged:(UISegmentedControl *)sender {
    [self loadThreads];
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
        // 自动加入并打开子区会话
        [[WKThreadService shared] joinThread:thread.shortId].then(^(id result) {
            [weakSelf openThread:thread];
        }).catch(^(NSError *error) {
            // 即使 join 失败也打开会话
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
    // 判断是否会显示 previewLbl（需要与 cell 的显示逻辑一致）
    BOOL hasPreview = NO;
    WKChannel *threadChannel = [WKChannel channelID:thread.channelId channelType:WK_COMMUNITY_TOPIC];
    // 检查@提醒
    NSArray<WKReminder *> *reminders = [[WKReminderDB shared] getWaitDoneReminder:threadChannel];
    for (WKReminder *r in reminders) {
        if (r.type == WKReminderTypeMentionMe) { hasPreview = YES; break; }
    }
    // 检查 SDK 会话的最后消息（如 [图片]、[语音] 等）
    if (!hasPreview) {
        WKConversation *threadConv = [[WKSDK shared].conversationManager getConversation:threadChannel];
        if (threadConv && threadConv.lastMessage && threadConv.lastMessage.content) {
            NSString *digest = [threadConv.lastMessage.content conversationDigest];
            if (digest.length > 0) hasPreview = YES;
        }
    }
    // 检查服务端返回的最后消息
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
        // 自动加入再打开
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
        // 删除
        UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                                  title:LLang(@"删除")
                                                                                handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [self confirmDeleteThread:thread];
            completionHandler(YES);
        }];
        [actions addObject:deleteAction];

        // 归档/取消归档
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
        // 非创建者但已加入：退出子区
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
    // 检查是否有本群的子区会话更新
    NSString *prefix = [NSString stringWithFormat:@"%@____", self.groupNo];
    for (WKConversation *conv in conversations) {
        if (conv.channel.channelType == WK_COMMUNITY_TOPIC && [conv.channel.channelId hasPrefix:prefix]) {
            // 子区有新消息，刷新列表
            [self.tableView reloadData];
            return;
        }
    }
}

#pragma mark - WKReminderManagerDelegate

- (void)reminderManager:(WKReminderManager *)manager didChange:(WKChannel *)channel reminders:(NSArray<WKReminder *> *)reminders {
    // 子区@提醒变化，刷新列表
    NSString *prefix = [NSString stringWithFormat:@"%@____", self.groupNo];
    if (channel.channelType == WK_COMMUNITY_TOPIC && [channel.channelId hasPrefix:prefix]) {
        [self.tableView reloadData];
    }
}

@end
