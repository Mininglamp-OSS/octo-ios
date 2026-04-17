//
//  WKForwardSelectVC.m
//  WuKongBase
//
//  转发选择会话：群聊/私聊 Tab + 分组 + 子区折叠 + 多选 + 搜索
//

#import "WKForwardSelectVC.h"
#import <objc/runtime.h>
#import "WKConversationWrapModel.h"
#import "WKConversationGroupThreadCell.h"
#import "WKCategorySectionCell.h"
#import "WKCategoryEntity.h"
#import "WKCategoryService.h"
#import "WKConversationTabView.h"
#import "WKThreadModel.h"
#import "WKThreadService.h"
#import "WKSearchbarView.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <WuKongBase/WuKongBase.h>

#pragma mark - 展示项类型

typedef NS_ENUM(NSInteger, FWItemType) {
    FWItemConversation,   // 普通会话
    FWItemSectionHeader,  // 分组 header
    FWItemThread,         // 子区
    FWItemThreadToggle,   // 子区折叠/展开 toggle
};

@interface FWDisplayItem : NSObject
@property (nonatomic, assign) FWItemType type;
@property (nonatomic, strong, nullable) WKConversationWrapModel *conversation;
@property (nonatomic, copy, nullable) NSString *sectionId;
@property (nonatomic, copy, nullable) NSString *sectionTitle;
@property (nonatomic, copy, nullable) NSString *threadChannelId;
@property (nonatomic, copy, nullable) NSString *threadName;
@property (nonatomic, copy, nullable) NSString *parentGroupNo;
@property (nonatomic, assign) NSInteger threadCount;
@property (nonatomic, assign) BOOL threadExpanded;
@property (nonatomic, assign) BOOL isChecked;
@end

@implementation FWDisplayItem
- (NSString *)uniqueKey {
    if (self.type == FWItemConversation && self.conversation) {
        return [NSString stringWithFormat:@"%@_%d", self.conversation.channel.channelId, self.conversation.channel.channelType];
    }
    if (self.type == FWItemThread && self.threadChannelId) {
        return self.threadChannelId;
    }
    return nil;
}
@end

#pragma mark - 会话 Cell（勾选框 + 头像/# + 名称）

@interface WKForwardConvCell : UITableViewCell
@property (nonatomic, strong) UIImageView *checkView;
@property (nonatomic, strong) UILabel *hashTagLbl;
@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *nameLbl;
@end

@implementation WKForwardConvCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

        _checkView = [[UIImageView alloc] init];
        _checkView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_checkView];

        _hashTagLbl = [[UILabel alloc] init];
        _hashTagLbl.text = @"#";
        _hashTagLbl.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
        _hashTagLbl.textColor = [UIColor colorWithRed:148/255.0 green:152/255.0 blue:168/255.0 alpha:1.0];
        _hashTagLbl.textAlignment = NSTextAlignmentCenter;
        _hashTagLbl.hidden = YES;
        [self.contentView addSubview:_hashTagLbl];

        _avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        _avatarView.hidden = YES;
        [self.contentView addSubview:_avatarView];

        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        _nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_nameLbl];
    }
    return self;
}

- (void)configureWithModel:(WKConversationWrapModel *)model checked:(BOOL)checked checkOnImage:(UIImage *)onImg checkOffImage:(UIImage *)offImg hideCheck:(BOOL)hideCheck {
    _checkView.hidden = hideCheck;
    if (!hideCheck) _checkView.image = checked ? onImg : offImg;
    _nameLbl.text = model.channelInfo ? model.channelInfo.displayName : @"";

    BOOL isGroup = (model.channel.channelType == WK_GROUP);
    _hashTagLbl.hidden = !isGroup;
    _avatarView.hidden = isGroup;

    if (!isGroup && model.channelInfo) {
        NSString *avatarURL = [WKAvatarUtil getAvatar:model.channel.channelId cacheKey:model.channelInfo.avatarCacheKey];
        if (model.channelInfo.logo && model.channelInfo.logo.length > 0) {
            avatarURL = [WKAvatarUtil getFullAvatarWIthPath:model.channelInfo.logo];
        }
        [_avatarView.avatarImgView sd_setImageWithURL:[NSURL URLWithString:avatarURL]
                                     placeholderImage:[WKApp.shared loadImage:@"Common/Index/DefaultAvatar" moduleID:@"WuKongBase"]];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.lim_height;
    CGFloat w = self.contentView.lim_width;

    CGFloat left = 15;
    if (!_checkView.hidden) {
        _checkView.frame = CGRectMake(15, (h - 22) / 2, 22, 22);
        left = 42;
    }

    if (!_hashTagLbl.hidden) {
        _hashTagLbl.frame = CGRectMake(left, (h - 30) / 2, 30, 30);
        _nameLbl.frame = CGRectMake(left + 32, 0, w - left - 47, h);
    } else {
        _avatarView.frame = CGRectMake(left + 3, (h - 40) / 2, 40, 40);
        _nameLbl.frame = CGRectMake(left + 48, 0, w - left - 63, h);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _avatarView.avatarImgView.image = nil;
    _hashTagLbl.hidden = YES;
    _avatarView.hidden = YES;
}
@end

#pragma mark - 子区 Cell

@interface WKForwardThreadCell : UITableViewCell
@property (nonatomic, strong) UIImageView *hashIcon;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UIImageView *checkView;
@end

@implementation WKForwardThreadCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        _hashIcon = [[UIImageView alloc] init];
        _hashIcon.contentMode = UIViewContentModeScaleAspectFit;
        _hashIcon.image = [WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(14, 14)
                           color:[UIColor colorWithRed:148/255.0 green:152/255.0 blue:168/255.0 alpha:1.0]];
        [self.contentView addSubview:_hashIcon];
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        _nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_nameLbl];
        _checkView = [[UIImageView alloc] init];
        _checkView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_checkView];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.lim_height;
    CGFloat w = self.contentView.lim_width;
    _checkView.frame = CGRectMake(15, (h - 22) / 2, 22, 22);
    _hashIcon.frame = CGRectMake(45, (h - 14) / 2, 14, 14);
    _nameLbl.frame = CGRectMake(65, 0, w - 80, h);
}
@end

#pragma mark - 子区 Toggle Cell

@interface WKForwardThreadToggleCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UIImageView *arrowView;
@end

@implementation WKForwardThreadToggleCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [WKApp shared].config.backgroundColor;
        _arrowView = [[UIImageView alloc] init];
        _arrowView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_arrowView];
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [UIFont systemFontOfSize:12];
        _titleLbl.textColor = [WKApp shared].config.themeColor;
        [self.contentView addSubview:_titleLbl];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.lim_height;
    _arrowView.frame = CGRectMake(50, (h - 10) / 2, 10, 10);
    _titleLbl.frame = CGRectMake(64, 0, 200, h);
}
@end

#pragma mark - VC

@interface WKForwardSelectVC () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) WKConversationTabView *tabView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *confirmBtn;

@property (nonatomic, assign) NSInteger currentTab;
@property (nonatomic, strong) NSMutableArray<WKConversationWrapModel *> *allConversations;
@property (nonatomic, strong) NSArray<WKCategoryEntity *> *categoryList;
@property (nonatomic, strong) NSMutableSet<NSString *> *collapsedSections;

// 子区
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<WKThreadModel *> *> *threadCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *expandedThreadGroups;
@property (nonatomic, assign) BOOL threadsLoaded;

// 选中状态（用 channelId 持久化，重建 displayList 时恢复）
@property (nonatomic, strong) NSMutableSet<NSString *> *checkedIds;

// 展示列表
@property (nonatomic, strong) NSArray<FWDisplayItem *> *displayList;

@end

@implementation WKForwardSelectVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    _currentTab = 0;
    _collapsedSections = [NSMutableSet set];
    _categoryList = @[];
    _threadCache = [NSMutableDictionary dictionary];
    _expandedThreadGroups = [NSMutableSet set];
    _displayList = @[];
    _checkedIds = [NSMutableSet set];

    [self setupNavBar];
    [self setupSearchBar];
    [self setupTabView];
    [self setupTableView];
    [self loadData];
}

- (void)setupNavBar {
    _confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_confirmBtn setTitle:LLang(@"确定") forState:UIControlStateNormal];
    [_confirmBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    _confirmBtn.titleLabel.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
    [_confirmBtn sizeToFit];
    [_confirmBtn addTarget:self action:@selector(onConfirm) forControlEvents:UIControlEventTouchUpInside];
    _confirmBtn.hidden = YES;
    self.rightView = _confirmBtn;
}

- (void)setupSearchBar {
    CGFloat y = self.navigationBar.lim_bottom;
    CGFloat w = self.view.lim_width;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 48)];
    container.backgroundColor = [WKApp shared].config.backgroundColor;

    _searchField = [[UITextField alloc] initWithFrame:CGRectMake(15, 6, w - 30, 36)];
    _searchField.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    _searchField.layer.cornerRadius = 4;
    _searchField.layer.masksToBounds = YES;
    _searchField.font = [UIFont systemFontOfSize:14];
    _searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.delegate = self;
    _searchField.textAlignment = NSTextAlignmentCenter;

    // 居中的搜索图标 + placeholder
    NSTextAttachment *iconAttachment = [[NSTextAttachment alloc] init];
    iconAttachment.image = [WKApp.shared loadImage:@"Common/Index/IconSearch2" moduleID:@"WuKongBase"];
    iconAttachment.bounds = CGRectMake(0, -3, 16, 16);
    NSMutableAttributedString *placeholder = [[NSMutableAttributedString alloc] init];
    [placeholder appendAttributedString:[NSAttributedString attributedStringWithAttachment:iconAttachment]];
    [placeholder appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", LLang(@"搜索")] attributes:@{NSForegroundColorAttributeName: [UIColor grayColor], NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
    _searchField.attributedPlaceholder = placeholder;

    [_searchField addTarget:self action:@selector(searchTextChanged) forControlEvents:UIControlEventEditingChanged];
    [container addSubview:_searchField];
    [self.view addSubview:container];
    container.tag = 8801;
}

- (void)setupTabView {
    UIView *searchContainer = [self.view viewWithTag:8801];
    CGFloat y = searchContainer.lim_bottom;
    _tabView = [[WKConversationTabView alloc] initWithFrame:CGRectMake(0, y, self.view.lim_width, 40)];
    _tabView.selectedIndex = 0;
    __weak typeof(self) ws = self;
    _tabView.onTabChanged = ^(NSInteger index) {
        ws.currentTab = index;
        [ws filterAndDisplay];
    };
    [self.view addSubview:_tabView];
}

- (void)setupTableView {
    CGFloat y = _tabView.lim_bottom;
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, y, self.view.lim_width, self.view.lim_height - y) style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.tableFooterView = [[UIView alloc] init];
    _tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    // 点击空白收键盘
    UITapGestureRecognizer *tapDismiss = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapDismiss.cancelsTouchesInView = NO;
    [_tableView addGestureRecognizer:tapDismiss];
    [_tableView registerClass:[WKForwardConvCell class] forCellReuseIdentifier:@"conv"];
    [_tableView registerClass:[WKCategorySectionCell class] forCellReuseIdentifier:@"section"];
    [_tableView registerClass:[WKForwardThreadCell class] forCellReuseIdentifier:@"thread"];
    [_tableView registerClass:[WKForwardThreadToggleCell class] forCellReuseIdentifier:@"toggle"];
    [self.view addSubview:_tableView];
}

#pragma mark - Data

- (void)loadData {
    NSArray<WKConversation *> *conversations = [[WKSDK shared].conversationManager getConversationList];
    _allConversations = [NSMutableArray array];
    for (WKConversation *conv in conversations) {
        if (conv.channel.channelType == WK_COMMUNITY_TOPIC) continue;
        [_allConversations addObject:[[WKConversationWrapModel alloc] initWithConversation:conv]];
    }
    [self sortList:_allConversations];

    // 如果会话列表为空（App 冷启动、SDK 还未同步），显示加载中并延迟重试
    if (_allConversations.count == 0) {
        [self.view showHUD];
        [self retryLoadDataWithCount:0];
        return;
    }

    [self loadCategories];
}

- (void)retryLoadDataWithCount:(NSInteger)count {
    if (count > 15) { // 最多等 7.5 秒
        [self.view hideHud];
        [self loadCategories];
        return;
    }
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSArray<WKConversation *> *conversations = [[WKSDK shared].conversationManager getConversationList];
        [ws.allConversations removeAllObjects];
        for (WKConversation *conv in conversations) {
            if (conv.channel.channelType == WK_COMMUNITY_TOPIC) continue;
            [ws.allConversations addObject:[[WKConversationWrapModel alloc] initWithConversation:conv]];
        }
        [ws sortList:ws.allConversations];
        if (ws.allConversations.count > 0) {
            [ws.view hideHud];
            [ws loadCategories];
        } else {
            [ws retryLoadDataWithCount:count + 1];
        }
    });
}

- (void)loadCategories {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    __weak typeof(self) ws = self;
    if (spaceId.length > 0) {
        [[WKCategoryService shared] listCategories:spaceId].then(^(NSArray<WKCategoryEntity *> *list) {
            ws.categoryList = list ?: @[];
            [ws loadAllThreads];
        }).catch(^(NSError *e) {
            [ws loadAllThreads];
        });
    } else {
        [self loadAllThreads];
    }
}

- (void)loadAllThreads {
    // 收集所有群聊的子区
    NSMutableArray<WKConversationWrapModel *> *groups = [NSMutableArray array];
    for (WKConversationWrapModel *m in _allConversations) {
        if (m.channel.channelType == WK_GROUP) [groups addObject:m];
    }
    if (groups.count == 0 || ![WKApp shared].remoteConfig.threadOn) {
        _threadsLoaded = YES;
        [self filterAndDisplay];
        return;
    }

    __block NSInteger pending = groups.count;
    __weak typeof(self) ws = self;
    for (WKConversationWrapModel *gm in groups) {
        NSString *groupNo = gm.channel.channelId;
        [[WKThreadService shared] listThreads:groupNo].then(^(NSArray<WKThreadModel *> *threads) {
            NSMutableArray *active = [NSMutableArray array];
            for (WKThreadModel *t in threads) {
                if (t.status == WKThreadStatusActive) [active addObject:t];
            }
            [active sortUsingComparator:^NSComparisonResult(WKThreadModel *a, WKThreadModel *b) {
                return [b.updatedAt compare:a.updatedAt];
            }];
            ws.threadCache[groupNo] = active;
            pending--;
            if (pending <= 0) { ws.threadsLoaded = YES; [ws filterAndDisplay]; }
        }).catch(^(NSError *e) {
            pending--;
            if (pending <= 0) { ws.threadsLoaded = YES; [ws filterAndDisplay]; }
        });
    }
}

- (void)sortList:(NSMutableArray<WKConversationWrapModel *> *)list {
    [list sortUsingComparator:^NSComparisonResult(WKConversationWrapModel *a, WKConversationWrapModel *b) {
        if (a.stick && !b.stick) return NSOrderedAscending;
        if (!a.stick && b.stick) return NSOrderedDescending;
        if (a.lastMsgTimestamp > b.lastMsgTimestamp) return NSOrderedAscending;
        if (a.lastMsgTimestamp < b.lastMsgTimestamp) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

#pragma mark - Filter & Display

- (void)filterAndDisplay {
    NSString *search = _searchField.text ?: @"";
    if (search.length > 0) {
        [self searchWithKeyword:search];
        return;
    }

    NSMutableArray<FWDisplayItem *> *list = [NSMutableArray array];

    if (_currentTab == 0) {
        // 群聊 tab：按分组显示
        NSMutableDictionary<NSString *, WKConversationWrapModel *> *channelMap = [NSMutableDictionary dictionary];
        for (WKConversationWrapModel *m in _allConversations) {
            if (m.channel.channelType == WK_GROUP) channelMap[m.channel.channelId] = m;
        }
        NSMutableSet *grouped = [NSMutableSet set];
        for (WKCategoryEntity *cat in _categoryList) {
            if (!cat.category_id || cat.category_id.length == 0) continue;
            for (WKCategoryGroup *cg in cat.groups) [grouped addObject:cg.group_no];
        }

        // 用户分组
        for (WKCategoryEntity *cat in _categoryList) {
            if (!cat.category_id || cat.category_id.length == 0) continue;
            FWDisplayItem *header = [FWDisplayItem new];
            header.type = FWItemSectionHeader;
            header.sectionId = cat.category_id;
            header.sectionTitle = cat.name;
            [list addObject:header];

            if (![_collapsedSections containsObject:cat.category_id]) {
                NSMutableArray *items = [NSMutableArray array];
                for (WKCategoryGroup *cg in cat.groups) {
                    WKConversationWrapModel *m = channelMap[cg.group_no];
                    if (m) [items addObject:m];
                }
                [self sortList:items];
                for (WKConversationWrapModel *m in items) {
                    FWDisplayItem *ci = [FWDisplayItem new]; ci.type = FWItemConversation; ci.conversation = m;
                    [list addObject:ci];
                    [self appendThreads:list forGroupNo:m.channel.channelId];
                }
            }
        }

        // 未归组
        NSMutableArray *ungrouped = [NSMutableArray array];
        for (WKConversationWrapModel *m in _allConversations) {
            if (m.channel.channelType == WK_GROUP && ![grouped containsObject:m.channel.channelId]) {
                [ungrouped addObject:m];
            }
        }
        for (WKConversationWrapModel *m in ungrouped) {
            FWDisplayItem *ci = [FWDisplayItem new]; ci.type = FWItemConversation; ci.conversation = m;
            [list addObject:ci];
            [self appendThreads:list forGroupNo:m.channel.channelId];
        }
    } else {
        // 私聊 tab
        for (WKConversationWrapModel *m in _allConversations) {
            if (m.channel.channelType == WK_PERSON) {
                FWDisplayItem *ci = [FWDisplayItem new]; ci.type = FWItemConversation; ci.conversation = m;
                [list addObject:ci];
            }
        }
    }

    [self applyCheckedState:list];
    _displayList = list;
    [_tableView reloadData];
}

- (void)appendThreads:(NSMutableArray<FWDisplayItem *> *)list forGroupNo:(NSString *)groupNo {
    if (!_threadsLoaded) return;
    NSArray<WKThreadModel *> *threads = _threadCache[groupNo];
    if (!threads || threads.count == 0) return;

    BOOL expanded = [_expandedThreadGroups containsObject:groupNo];
    FWDisplayItem *toggle = [FWDisplayItem new];
    toggle.type = FWItemThreadToggle;
    toggle.parentGroupNo = groupNo;
    toggle.threadCount = threads.count;
    toggle.threadExpanded = expanded;
    [list addObject:toggle];

    if (expanded) {
        for (WKThreadModel *t in threads) {
            FWDisplayItem *ti = [FWDisplayItem new];
            ti.type = FWItemThread;
            ti.threadChannelId = t.channelId;
            ti.threadName = t.name;
            [list addObject:ti];
        }
    }
}

- (void)searchWithKeyword:(NSString *)keyword {
    NSString *lower = [keyword lowercaseString];
    NSMutableArray<FWDisplayItem *> *list = [NSMutableArray array];

    for (WKConversationWrapModel *m in _allConversations) {
        if (_currentTab == 0 && m.channel.channelType != WK_GROUP) continue;
        if (_currentTab == 1 && m.channel.channelType != WK_PERSON) continue;
        NSString *name = m.channelInfo ? m.channelInfo.displayName : @"";
        if ([name.lowercaseString containsString:lower]) {
            FWDisplayItem *ci = [FWDisplayItem new]; ci.type = FWItemConversation; ci.conversation = m;
            [list addObject:ci];
        }
    }

    // 搜索子区（仅群聊 tab）
    if (_currentTab == 0) {
        for (NSString *groupNo in _threadCache) {
            for (WKThreadModel *t in _threadCache[groupNo]) {
                if ([t.name.lowercaseString containsString:lower]) {
                    FWDisplayItem *ti = [FWDisplayItem new];
                    ti.type = FWItemThread;
                    ti.threadChannelId = t.channelId;
                    ti.threadName = t.name;
                    [list addObject:ti];
                }
            }
        }
    }

    [self applyCheckedState:list];
    _displayList = list;
    [_tableView reloadData];
}

/// 从 checkedIds 恢复选中状态
- (void)applyCheckedState:(NSArray<FWDisplayItem *> *)list {
    for (FWDisplayItem *item in list) {
        NSString *key = [item uniqueKey];
        if (key) item.isChecked = [_checkedIds containsObject:key];
    }
}

#pragma mark - Search

- (void)searchTextChanged {
    [self filterAndDisplay];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _displayList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)_displayList.count) return 0;
    FWDisplayItem *item = _displayList[indexPath.row];
    switch (item.type) {
        case FWItemSectionHeader: return 36;
        case FWItemThreadToggle: return 30;
        case FWItemThread: return 40;
        case FWItemConversation: {
            if (item.conversation && item.conversation.channel.channelType == WK_PERSON) return 56;
            return 48;
        }
    }
    return 48;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)_displayList.count) {
        return [tableView dequeueReusableCellWithIdentifier:@"conv" forIndexPath:indexPath];
    }
    FWDisplayItem *item = _displayList[indexPath.row];
    switch (item.type) {
        case FWItemSectionHeader:
            return [tableView dequeueReusableCellWithIdentifier:@"section" forIndexPath:indexPath];
        case FWItemThread:
            return [tableView dequeueReusableCellWithIdentifier:@"thread" forIndexPath:indexPath];
        case FWItemThreadToggle:
            return [tableView dequeueReusableCellWithIdentifier:@"toggle" forIndexPath:indexPath];
        default:
            return [tableView dequeueReusableCellWithIdentifier:@"conv" forIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)_displayList.count) return;
    FWDisplayItem *item = _displayList[indexPath.row];

    switch (item.type) {
        case FWItemSectionHeader: {
            WKCategorySectionCell *sc = (WKCategorySectionCell *)cell;
            sc.sectionId = item.sectionId;
            sc.sectionTitle = item.sectionTitle;
            sc.collapsed = [_collapsedSections containsObject:item.sectionId];
            sc.isDefault = NO;
            sc.showTopDivider = (indexPath.row > 0);
            __weak typeof(self) ws = self;
            sc.onToggle = ^(NSString *sid, BOOL collapsed) {
                if (collapsed) [ws.collapsedSections addObject:sid];
                else [ws.collapsedSections removeObject:sid];
                [ws filterAndDisplay];
            };
            sc.onLongPress = nil;
            break;
        }
        case FWItemThread: {
            WKForwardThreadCell *tc = (WKForwardThreadCell *)cell;
            tc.nameLbl.text = item.threadName;
            tc.checkView.hidden = self.singleSelectMode;
            if (!self.singleSelectMode) {
                tc.checkView.image = item.isChecked ? [self checkOnImage] : [self checkOffImage];
            }
            break;
        }
        case FWItemThreadToggle: {
            WKForwardThreadToggleCell *tg = (WKForwardThreadToggleCell *)cell;
            tg.titleLbl.text = [NSString stringWithFormat:@"%@%ld%@",
                                item.threadExpanded ? @"" : @"",
                                (long)item.threadCount, LLang(@"个子区")];
            tg.titleLbl.textColor = [WKApp shared].config.themeColor;
            // 箭头
            UIImage *arrow = [self chevronImage];
            tg.arrowView.image = arrow;
            tg.arrowView.transform = item.threadExpanded ? CGAffineTransformIdentity : CGAffineTransformMakeRotation(-M_PI_2);
            break;
        }
        default: {
            if ([cell isKindOfClass:[WKForwardConvCell class]] && item.conversation) {
                [(WKForwardConvCell *)cell configureWithModel:item.conversation
                                                     checked:item.isChecked
                                                checkOnImage:[self checkOnImage]
                                               checkOffImage:[self checkOffImage]
                                                   hideCheck:self.singleSelectMode];
            }
            break;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)_displayList.count) return;
    FWDisplayItem *item = _displayList[indexPath.row];

    if (item.type == FWItemSectionHeader) return;

    if (item.type == FWItemThreadToggle) {
        NSString *gno = item.parentGroupNo;
        if ([_expandedThreadGroups containsObject:gno]) {
            [_expandedThreadGroups removeObject:gno];
        } else {
            [_expandedThreadGroups addObject:gno];
        }
        [self filterAndDisplay];
        return;
    }

    // 单选模式：弹出确认面板
    if (self.singleSelectMode) {
        WKChannel *channel = nil;
        NSString *name = nil;
        BOOL isGroup = NO;
        BOOL isThread = NO;
        if (item.type == FWItemConversation && item.conversation) {
            channel = item.conversation.channel;
            name = item.conversation.channelInfo ? item.conversation.channelInfo.displayName : @"";
            isGroup = (channel.channelType == WK_GROUP);
        } else if (item.type == FWItemThread) {
            channel = [WKChannel channelID:item.threadChannelId channelType:WK_COMMUNITY_TOPIC];
            name = item.threadName;
            isThread = YES;
        }
        if (channel) {
            [self showShareConfirmPanel:channel name:name isGroup:isGroup isThread:isThread];
        }
        return;
    }

    // 多选 toggle
    item.isChecked = !item.isChecked;
    NSString *key = [item uniqueKey];
    if (key) {
        if (item.isChecked) [_checkedIds addObject:key];
        else [_checkedIds removeObject:key];
    }
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self updateConfirmBtn];
}

#pragma mark - Confirm

- (void)updateConfirmBtn {
    NSInteger count = _checkedIds.count;
    if (count > 0) {
        _confirmBtn.hidden = NO;
        [_confirmBtn setTitle:[NSString stringWithFormat:@"%@(%ld)", LLang(@"确定"), (long)count] forState:UIControlStateNormal];
        [_confirmBtn sizeToFit];
    } else {
        _confirmBtn.hidden = YES;
    }
}

- (void)onConfirm {
    NSMutableArray<WKChannel *> *channels = [NSMutableArray array];
    for (FWDisplayItem *item in _displayList) {
        if (!item.isChecked) continue;
        if (item.type == FWItemConversation && item.conversation) {
            [channels addObject:item.conversation.channel];
        } else if (item.type == FWItemThread && item.threadChannelId) {
            [channels addObject:[WKChannel channelID:item.threadChannelId channelType:WK_COMMUNITY_TOPIC]];
        }
    }

    if (channels.count > 0) {
        // 先发送消息
        if (self.onConfirmChannels) {
            self.onConfirmChannels(channels);
        } else if (self.onSelect) {
            for (WKChannel *ch in channels) {
                self.onSelect(ch);
            }
        }
    }

    // 延迟关闭，让 SDK 发送回调能被当前页面接收
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    });
}

#pragma mark - Share Confirm Panel

- (void)showShareConfirmPanel:(WKChannel *)channel name:(NSString *)name isGroup:(BOOL)isGroup isThread:(BOOL)isThread {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [UIApplication sharedApplication].windows.firstObject;
    CGFloat screenW = window.lim_width;
    CGFloat screenH = window.lim_height;

    // 半透明遮罩
    UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    overlay.alpha = 0;
    overlay.tag = 88800;
    [window addSubview:overlay];

    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissShareConfirmPanel)];
    [overlay addGestureRecognizer:bgTap];

    // 底部面板（高度稍后根据内容动态设置）
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeBottom = window.safeAreaInsets.bottom;
    }
    UIView *panel = [[UIView alloc] init];
    panel.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    panel.tag = 88801;
    [overlay addSubview:panel];

    CGFloat pad = 20;
    CGFloat y = pad;

    // "发送给" 标题
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, screenW - pad*2, 22)];
    titleLbl.text = LLang(@"发送给");
    titleLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    titleLbl.textColor = [UIColor colorWithWhite:0.4 alpha:1];
    [panel addSubview:titleLbl];
    y += 30;

    // 目标行：图标/头像 + 名称
    UIView *targetRow = [[UIView alloc] initWithFrame:CGRectMake(pad, y, screenW - pad*2, 44)];
    [panel addSubview:targetRow];

    CGFloat iconLeft = 0;
    if (isGroup) {
        UILabel *hashLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 7, 30, 30)];
        hashLbl.text = @"#";
        hashLbl.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
        hashLbl.textColor = [UIColor colorWithRed:148/255.0 green:152/255.0 blue:168/255.0 alpha:1.0];
        hashLbl.textAlignment = NSTextAlignmentCenter;
        [targetRow addSubview:hashLbl];
        iconLeft = 34;
    } else if (isThread) {
        UIImageView *threadIcon = [[UIImageView alloc] initWithImage:[WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(20, 20) color:[UIColor colorWithRed:148/255.0 green:152/255.0 blue:168/255.0 alpha:1.0]]];
        threadIcon.frame = CGRectMake(4, 12, 20, 20);
        [targetRow addSubview:threadIcon];
        iconLeft = 30;
    } else {
        // 私聊头像
        WKUserAvatar *avatar = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 2, 40, 40)];
        WKChannelInfo *chInfo = [[WKSDK shared].channelManager getChannelInfo:channel];
        if (chInfo) {
            NSString *avatarURL = [WKAvatarUtil getAvatar:channel.channelId cacheKey:chInfo.avatarCacheKey];
            if (chInfo.logo.length > 0) avatarURL = [WKAvatarUtil getFullAvatarWIthPath:chInfo.logo];
            [avatar.avatarImgView sd_setImageWithURL:[NSURL URLWithString:avatarURL]
                                    placeholderImage:[WKApp.shared loadImage:@"Common/Index/DefaultAvatar" moduleID:@"WuKongBase"]];
        }
        [targetRow addSubview:avatar];
        iconLeft = 48;
    }

    UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(iconLeft, 0, targetRow.lim_width - iconLeft, 44)];
    nameLbl.text = name;
    nameLbl.font = [[WKApp shared].config appFontOfSizeMedium:16];
    nameLbl.textColor = [WKApp shared].config.defaultTextColor;
    [targetRow addSubview:nameLbl];
    y += 52;

    // 文件/链接预览卡片
    if (self.shareFileInfos.count > 0) {
        NSDictionary *fileInfo = self.shareFileInfos.firstObject;
        NSString *type = fileInfo[@"type"];
        NSString *fileName = fileInfo[@"fileName"] ?: @"";
        NSString *filePath = fileInfo[@"path"];

        CGFloat cardW = screenW * 0.62;
        CGFloat cardH = 66;
        CGFloat cardX = (screenW - cardW) / 2.0;

        // 链接分享：显示网页标题 + favicon
        if ([type isEqualToString:@"link"]) {
            NSString *linkTitle = fileInfo[@"title"] ?: @"";
            NSString *linkURL = fileInfo[@"url"] ?: @"";
            CGFloat linkPad = pad + 10;
            cardW = screenW - linkPad * 2;
            cardX = linkPad;
            cardH = 70;

            UIView *fileCard = [[UIView alloc] initWithFrame:CGRectMake(cardX, y, cardW, cardH)];
            fileCard.backgroundColor = [WKApp shared].config.backgroundColor;
            fileCard.layer.cornerRadius = 10;
            fileCard.layer.borderColor = [[UIColor grayColor] colorWithAlphaComponent:0.1].CGColor;
            fileCard.layer.borderWidth = 0.5;
            [panel addSubview:fileCard];

            // favicon（右侧）
            CGFloat iconSize = 36;
            UIImageView *faviconView = [[UIImageView alloc] initWithFrame:CGRectMake(cardW - iconSize - 14, (cardH - iconSize) / 2, iconSize, iconSize)];
            faviconView.contentMode = UIViewContentModeScaleAspectFit;
            faviconView.layer.cornerRadius = 6;
            faviconView.layer.masksToBounds = YES;
            faviconView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.08];
            // 默认链接图标（地球）
            if (@available(iOS 13.0, *)) {
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIFontWeightRegular];
                faviconView.image = [[UIImage systemImageNamed:@"globe" withConfiguration:config] imageWithTintColor:[UIColor grayColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            }
            [fileCard addSubview:faviconView];
            // 异步加载网站 favicon（直接请求网站的 /favicon.ico）
            NSString *iconURL = fileInfo[@"icon"];
            NSURL *parsedURL = [NSURL URLWithString:linkURL];
            if (!iconURL && parsedURL.scheme && parsedURL.host) {
                iconURL = [NSString stringWithFormat:@"%@://%@/favicon.ico", parsedURL.scheme, parsedURL.host];
            }
            if (iconURL) {
                NSString *faviconURL = iconURL;
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:faviconURL]];
                    if (data) {
                        UIImage *icon = [UIImage imageWithData:data];
                        if (icon) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                faviconView.image = icon;
                                faviconView.backgroundColor = [UIColor clearColor];
                            });
                        }
                    }
                });
            }

            // 标题
            CGFloat textW = cardW - iconSize - 40;
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 12, textW, 22)];
            titleLabel.text = linkTitle.length > 0 ? linkTitle : linkURL;
            titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            titleLabel.textColor = [WKApp shared].config.defaultTextColor;
            titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            [fileCard addSubview:titleLabel];

            // URL
            UILabel *urlLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 36, textW, 16)];
            urlLabel.text = linkURL;
            urlLabel.font = [UIFont systemFontOfSize:11];
            urlLabel.textColor = [UIColor grayColor];
            urlLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            [fileCard addSubview:urlLabel];

            y += cardH + 12;
        } else {
            // 文件/图片预览卡片（居中，宽约60%）
            UIView *fileCard = [[UIView alloc] initWithFrame:CGRectMake(cardX, y, cardW, cardH)];
            fileCard.backgroundColor = [WKApp shared].config.backgroundColor;
            fileCard.layer.cornerRadius = 8;
            fileCard.layer.borderColor = [[UIColor grayColor] colorWithAlphaComponent:0.12].CGColor;
            fileCard.layer.borderWidth = 0.5;
            [panel addSubview:fileCard];

            // 文件图标（右侧）
            CGFloat iconSize = 38;
            UIImageView *fileIconView = [[UIImageView alloc] initWithFrame:CGRectMake(cardW - iconSize - 12, (cardH - iconSize) / 2, iconSize, iconSize)];
            fileIconView.contentMode = UIViewContentModeScaleAspectFit;

            if ([type isEqualToString:@"image"] && filePath) {
                fileIconView.image = [UIImage imageWithContentsOfFile:filePath];
                fileIconView.contentMode = UIViewContentModeScaleAspectFill;
                fileIconView.clipsToBounds = YES;
                fileIconView.layer.cornerRadius = 4;
            } else {
                NSString *ext = [fileName pathExtension];
                fileIconView.image = [self fileIconForExtension:ext];
            }
            [fileCard addSubview:fileIconView];

        // 文件名
        CGFloat textW = cardW - iconSize - 34;
        UILabel *fl = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, textW, 36)];
        fl.text = fileName;
        fl.font = [UIFont systemFontOfSize:14];
        fl.textColor = [WKApp shared].config.defaultTextColor;
        fl.lineBreakMode = NSLineBreakByTruncatingMiddle;
        fl.numberOfLines = 2;
        [fileCard addSubview:fl];

        // 文件大小
        if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            unsigned long long size = [attrs fileSize];
            NSString *sizeStr;
            if (size < 1024) sizeStr = [NSString stringWithFormat:@"%lluB", size];
            else if (size < 1024*1024) sizeStr = [NSString stringWithFormat:@"%.1fKB", size/1024.0];
            else sizeStr = [NSString stringWithFormat:@"%.1fMB", size/1024.0/1024.0];
            UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(12, cardH - 22, textW, 16)];
            sl.text = sizeStr;
            sl.font = [UIFont systemFontOfSize:11];
            sl.textColor = [UIColor grayColor];
            [fileCard addSubview:sl];
        }
            y += cardH + 12;
        } // end else (file/image)
    }

    // 输入框
    UITextField *msgField = [[UITextField alloc] initWithFrame:CGRectMake(pad, y, screenW - pad*2, 40)];
    msgField.backgroundColor = [WKApp shared].config.backgroundColor;
    msgField.layer.cornerRadius = 6;
    msgField.placeholder = LLang(@"发消息");
    msgField.font = [UIFont systemFontOfSize:14];
    msgField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
    msgField.leftViewMode = UITextFieldViewModeAlways;
    msgField.tag = 88802;
    [panel addSubview:msgField];
    y += 50;

    // 按钮行
    CGFloat btnW = (screenW - pad*2 - 12) / 2;
    CGFloat btnH = 44;

    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelBtn.frame = CGRectMake(pad, y, btnW, btnH);
    [cancelBtn setTitle:LLang(@"取消") forState:UIControlStateNormal];
    [cancelBtn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cancelBtn.backgroundColor = [WKApp shared].config.backgroundColor;
    cancelBtn.layer.cornerRadius = 8;
    [cancelBtn addTarget:self action:@selector(dismissShareConfirmPanel) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:cancelBtn];

    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sendBtn.frame = CGRectMake(pad + btnW + 12, y, btnW, btnH);
    [sendBtn setTitle:LLang(@"发送") forState:UIControlStateNormal];
    [sendBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sendBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    sendBtn.backgroundColor = [UIColor colorWithRed:7/255.0 green:193/255.0 blue:96/255.0 alpha:1.0];
    sendBtn.layer.cornerRadius = 8;
    sendBtn.tag = 88803;
    [sendBtn addTarget:self action:@selector(onShareConfirmSend) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:sendBtn];

    // 存储 channel
    objc_setAssociatedObject(overlay, "shareChannel", channel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 监听键盘
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shareConfirmKeyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shareConfirmKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    // 点击面板空白区域收键盘（按钮/输入框上不触发）
    UITapGestureRecognizer *panelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(shareConfirmDismissKeyboard)];
    panelTap.delegate = self;
    [overlay addGestureRecognizer:panelTap];

    // 动态计算面板高度
    y += btnH + safeBottom + 16;
    CGFloat panelH = y;
    panel.frame = CGRectMake(0, screenH, screenW, panelH);

    // 圆角蒙版
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, screenW, panelH) byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(16, 16)];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    panel.layer.mask = maskLayer;

    // 弹出动画
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        overlay.alpha = 1;
        panel.frame = CGRectMake(0, screenH - panelH, screenW, panelH);
    } completion:nil];
}

- (void)dismissShareConfirmPanel {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [self.view endEditing:YES];

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [window viewWithTag:88800];
    if (!overlay) return;
    UIView *panel = [overlay viewWithTag:88801];
    CGFloat screenH = window.lim_height;
    [UIView animateWithDuration:0.25 animations:^{
        overlay.alpha = 0;
        panel.frame = CGRectMake(0, screenH, panel.lim_width, panel.lim_height);
    } completion:^(BOOL finished) {
        [overlay removeFromSuperview];
    }];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // 点在按钮或输入框上时，不触发收键盘手势
    if ([touch.view isKindOfClass:[UIButton class]] || [touch.view isKindOfClass:[UITextField class]]) {
        return NO;
    }
    return YES;
}

- (void)shareConfirmDismissKeyboard {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [window viewWithTag:88800];
    [overlay endEditing:YES];
}

- (void)shareConfirmKeyboardWillShow:(NSNotification *)notification {
    CGRect kbFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *panel = [[window viewWithTag:88800] viewWithTag:88801];
    if (!panel) return;
    CGFloat screenH = window.lim_height;
    CGFloat panelBottom = screenH - kbFrame.size.height;
    [UIView animateWithDuration:duration animations:^{
        panel.frame = CGRectMake(0, panelBottom - panel.lim_height, panel.lim_width, panel.lim_height);
    }];
}

- (void)shareConfirmKeyboardWillHide:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *panel = [[window viewWithTag:88800] viewWithTag:88801];
    if (!panel) return;
    CGFloat screenH = window.lim_height;
    [UIView animateWithDuration:duration animations:^{
        panel.frame = CGRectMake(0, screenH - panel.lim_height, panel.lim_width, panel.lim_height);
    }];
}

- (void)onShareConfirmSend {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIView *overlay = [window viewWithTag:88800];
    WKChannel *channel = objc_getAssociatedObject(overlay, "shareChannel");
    UITextField *msgField = [overlay viewWithTag:88802];
    NSString *extraText = msgField.text;

    [self dismissShareConfirmPanel];

    if (channel) {
        if (self.onSingleConfirm) {
            self.onSingleConfirm(channel, extraText);
        } else if (self.onSelect) {
            self.onSelect(channel);
        }
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    });
}

- (UIImage *)fileIconForExtension:(NSString *)ext {
    NSString *lowExt = [[ext lowercaseString] stringByReplacingOccurrencesOfString:@"." withString:@""];
    NSString *imageName = nil;
    if ([@[@"doc", @"docx", @"docm", @"rtf", @"odt", @"wps"] containsObject:lowExt]) imageName = @"FileType/FileWord";
    else if ([@[@"xls", @"xlsx", @"xlsm", @"csv", @"ods", @"et"] containsObject:lowExt]) imageName = @"FileType/FileExcel";
    else if ([lowExt isEqualToString:@"pdf"]) imageName = @"FileType/FilePDF";
    else if ([@[@"ppt", @"pptx", @"pptm", @"pps", @"ppsx"] containsObject:lowExt]) imageName = @"FileType/FilePPT";
    else if ([@[@"mp4", @"mov", @"avi", @"mkv", @"wmv", @"flv", @"webm"] containsObject:lowExt]) imageName = @"FileType/FileVideo";
    else if ([@[@"md", @"markdown"] containsObject:lowExt]) imageName = @"FileType/FileMarkdown";
    if (imageName) {
        UIImage *img = [[WKApp shared] loadImage:imageName moduleID:@"WuKongBase"];
        if (img) return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular];
        UIImage *img = [UIImage systemImageNamed:@"doc.fill" withConfiguration:config];
        return [img imageWithTintColor:[UIColor systemBlueColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return nil;
}

#pragma mark - Helper Images

- (UIImage *)checkOnImage {
    CGSize s = CGSizeMake(22, 22);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    UIColor *color = [WKApp shared].config.themeColor;
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, 20, 20)];
    [color setFill];
    [circle fill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *check = [UIBezierPath bezierPath];
    check.lineWidth = 2;
    check.lineCapStyle = kCGLineCapRound;
    check.lineJoinStyle = kCGLineJoinRound;
    [check moveToPoint:CGPointMake(6, 11)];
    [check addLineToPoint:CGPointMake(9.5, 15)];
    [check addLineToPoint:CGPointMake(16, 7)];
    [check stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)checkOffImage {
    CGSize s = CGSizeMake(22, 22);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1, 1, 20, 20)];
    circle.lineWidth = 1.5;
    [[UIColor colorWithWhite:0.75 alpha:1] setStroke];
    [circle stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)chevronImage {
    CGSize s = CGSizeMake(10, 10);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[WKApp shared].config.themeColor setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextMoveToPoint(ctx, 2, 3);
    CGContextAddLineToPoint(ctx, 5, 7);
    CGContextAddLineToPoint(ctx, 8, 3);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
