//
//  WKForwardSelectVC.m
//  WuKongBase
//
//  转发选择会话：群聊/私聊 Tab + 分组 + 子区折叠 + 多选 + 搜索
//

#import "WKForwardSelectVC.h"
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

- (void)configureWithModel:(WKConversationWrapModel *)model checked:(BOOL)checked checkOnImage:(UIImage *)onImg checkOffImage:(UIImage *)offImg {
    _checkView.image = checked ? onImg : offImg;
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

    _checkView.frame = CGRectMake(15, (h - 22) / 2, 22, 22);

    if (!_hashTagLbl.hidden) {
        // 群聊: # 标识
        _hashTagLbl.frame = CGRectMake(42, (h - 30) / 2, 30, 30);
        _nameLbl.frame = CGRectMake(74, 0, w - 90, h);
    } else {
        // 私聊: 头像
        _avatarView.frame = CGRectMake(45, (h - 40) / 2, 40, 40);
        _nameLbl.frame = CGRectMake(93, 0, w - 108, h);
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

@interface WKForwardSelectVC () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

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
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
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

    // 加载分组
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
            tc.checkView.image = item.isChecked ? [self checkOnImage] : [self checkOffImage];
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
                                               checkOffImage:[self checkOffImage]];
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
    if (channels.count > 0 && self.onSelect) {
        // 逐个转发
        for (WKChannel *ch in channels) {
            self.onSelect(ch);
        }
    }
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
