//
//  WKForwardDirectoryVC.m
//  WuKongBase
//
//  「新建会话」全量目录选择页：群聊 / 联系人 / Bot 三个 tab + 搜索。
//

#import "WKForwardDirectoryVC.h"
#import "WKForwardConfirmPanel.h"
#import "WKConversationGroupThreadCell.h"
#import "WKThreadModel.h"
#import "WKThreadService.h"
#import "WKChineseSort.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WuKongBase/WuKongBase.h>

#define LLang(a) [a Localized:self]

#pragma mark - 目录项模型

typedef NS_ENUM(NSInteger, WKDirTab) {
    WKDirTabGroup = 0,   // 群聊
    WKDirTabContact,     // 联系人
    WKDirTabBot,         // Bot
};

typedef NS_ENUM(NSInteger, WKDirItemType) {
    WKDirItemGroup,        // 群聊行
    WKDirItemThreadToggle, // 子区折叠 toggle
    WKDirItemThread,       // 子区行
    WKDirItemContact,      // 联系人 / Bot 行
};

/// 统一目录目标，承载群/子区/联系人/bot 的展示与频道信息
@interface WKDirItem : NSObject
@property (nonatomic, assign) WKDirItemType type;
// 通用
@property (nonatomic, copy, nullable) NSString *channelId;   // 群号 / uid / 子区 channelId
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *avatarURL;   // 联系人/bot 头像
@property (nonatomic, assign) BOOL isRobot;
// 群子区
@property (nonatomic, copy, nullable) NSString *parentGroupNo;
@property (nonatomic, assign) NSInteger threadCount;
@property (nonatomic, assign) BOOL threadExpanded;
@end

@implementation WKDirItem
@end

#pragma mark - 通用行 Cell（头像/# + 名称 + AI 角标）

@interface WKDirCell : UITableViewCell
@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UILabel *botBadge;
@end

@implementation WKDirCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

        _avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        [self.contentView addSubview:_avatarView];

        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        _nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_nameLbl];

        _botBadge = [[UILabel alloc] init];
        _botBadge.text = @"AI";
        _botBadge.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        _botBadge.textColor = [UIColor whiteColor];
        _botBadge.backgroundColor = [WKApp shared].config.themeColor;
        _botBadge.textAlignment = NSTextAlignmentCenter;
        _botBadge.layer.cornerRadius = 4;
        _botBadge.layer.masksToBounds = YES;
        _botBadge.hidden = YES;
        [self.contentView addSubview:_botBadge];
    }
    return self;
}

- (void)configureWithItem:(WKDirItem *)item {
    _nameLbl.text = item.displayName ?: @"";
    _botBadge.hidden = !item.isRobot;
    [_avatarView.avatarImgView sd_setImageWithURL:[NSURL URLWithString:item.avatarURL ?: @""]
                                 placeholderImage:[WKApp.shared loadImage:@"Common/Index/DefaultAvatar" moduleID:@"WuKongBase"]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.lim_height;
    CGFloat w = self.contentView.lim_width;
    CGFloat left = 15;
    _avatarView.frame = CGRectMake(left + 3, (h - 40) / 2, 40, 40);
    CGFloat nameLeft = left + 48;

    if (_botBadge.hidden) {
        _nameLbl.frame = CGRectMake(nameLeft, 0, w - nameLeft - 15, h);
    } else {
        // 给 AI 角标留出固定宽度
        CGFloat badgeW = 22;
        CGSize nameSize = [_nameLbl sizeThatFits:CGSizeMake(w - nameLeft - badgeW - 12 - 15, h)];
        CGFloat nameW = MIN(nameSize.width, w - nameLeft - badgeW - 12 - 15);
        _nameLbl.frame = CGRectMake(nameLeft, 0, nameW, h);
        _botBadge.frame = CGRectMake(nameLeft + nameW + 6, (h - 16) / 2, badgeW, 16);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _avatarView.avatarImgView.image = nil;
    _botBadge.hidden = YES;
}
@end

#pragma mark - 子区行 Cell

@interface WKDirThreadCell : UITableViewCell
@property (nonatomic, strong) UIImageView *hashIcon;
@property (nonatomic, strong) UILabel *nameLbl;
@end

@implementation WKDirThreadCell
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
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.lim_height;
    CGFloat w = self.contentView.lim_width;
    _hashIcon.frame = CGRectMake(45, (h - 14) / 2, 14, 14);
    _nameLbl.frame = CGRectMake(65, 0, w - 80, h);
}
@end

#pragma mark - 子区 Toggle Cell

@interface WKDirThreadToggleCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UIImageView *arrowView;
@end

@implementation WKDirThreadToggleCell
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

#pragma mark - 三段 Tab 控件

@interface WKDirSegment : UIView
@property (nonatomic, copy) void(^onChange)(NSInteger index);
@property (nonatomic, assign) NSInteger selectedIndex;
- (instancetype)initWithFrame:(CGRect)frame titles:(NSArray<NSString *> *)titles;
@end

@implementation WKDirSegment {
    NSArray<UIButton *> *_buttons;
    UIView *_indicator;
}
- (instancetype)initWithFrame:(CGRect)frame titles:(NSArray<NSString *> *)titles {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [WKApp shared].config.backgroundColor;
        NSMutableArray *btns = [NSMutableArray array];
        for (NSInteger i = 0; i < titles.count; i++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn setTitle:titles[i] forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
            [btn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateSelected];
            btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            btn.tag = i;
            [btn addTarget:self action:@selector(onTap:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:btn];
            [btns addObject:btn];
        }
        _buttons = btns;
        _indicator = [[UIView alloc] init];
        _indicator.backgroundColor = [WKApp shared].config.themeColor;
        _indicator.layer.cornerRadius = 1.5;
        [self addSubview:_indicator];
        _selectedIndex = 0;
        [self updateSelection:NO];
    }
    return self;
}
- (void)onTap:(UIButton *)sender {
    if (_selectedIndex == sender.tag) return;
    _selectedIndex = sender.tag;
    [self updateSelection:YES];
    if (self.onChange) self.onChange(_selectedIndex);
}
- (void)updateSelection:(BOOL)animated {
    CGFloat segW = self.lim_width / _buttons.count;
    for (NSInteger i = 0; i < _buttons.count; i++) {
        UIButton *btn = _buttons[i];
        btn.frame = CGRectMake(i * segW, 0, segW, self.lim_height);
        btn.selected = (i == _selectedIndex);
    }
    void(^move)(void) = ^{
        CGFloat indW = 28;
        CGFloat cx = self->_selectedIndex * segW + segW / 2;
        self->_indicator.frame = CGRectMake(cx - indW/2, self.lim_height - 4, indW, 3);
    };
    if (animated) {
        [UIView animateWithDuration:0.2 animations:move];
    } else {
        move();
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateSelection:NO];
}
@end

#pragma mark - VC

@interface WKForwardDirectoryVC () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) WKDirSegment *segment;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *confirmBtn;
// 一次性 guard: onConfirm 内 dispatch_after 0.3s 才 pop, 期间 confirmBtn 仍 tappable,
// 下游 forwardMessage: 链路无 dedup, 一秒内双击会双发 (PR #32 R10 review)。
@property (nonatomic, assign) BOOL confirming;

@property (nonatomic, assign) WKDirTab currentTab;

// 群聊
@property (nonatomic, strong) NSMutableArray<WKDirItem *> *groups;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<WKThreadModel *> *> *threadCache;
@property (nonatomic, strong) NSMutableSet<NSString *> *expandedGroups;
@property (nonatomic, strong) NSMutableSet<NSString *> *threadLoading;

// 联系人 / bot
@property (nonatomic, strong) NSMutableArray<WKDirItem *> *contacts;     // 不含 bot
@property (nonatomic, strong) NSMutableArray<WKDirItem *> *bots;
// 联系人分组（A-Z）
@property (nonatomic, strong) NSMutableArray<NSMutableArray<WKDirItem *> *> *contactSections;
@property (nonatomic, strong) NSMutableArray<NSString *> *contactSectionTitles;

// 当前展示
@property (nonatomic, strong) NSArray<WKDirItem *> *displayList; // 群/bot/搜索结果（单 section）
@property (nonatomic, assign) BOOL contactsGrouped;             // 联系人 tab 且无搜索时按分组展示
@property (nonatomic, copy)   NSString *keyword;

// 多选
@property (nonatomic, strong) NSMutableSet<NSString *> *checkedIds;
@property (nonatomic, strong) NSMutableDictionary<NSString *, WKChannel *> *checkedChannels;

@end

@implementation WKForwardDirectoryVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    if (self.title.length == 0) self.title = LLang(@"新建会话");

    _currentTab = WKDirTabGroup;
    _groups = [NSMutableArray array];
    _threadCache = [NSMutableDictionary dictionary];
    _expandedGroups = [NSMutableSet set];
    _threadLoading = [NSMutableSet set];
    _contacts = [NSMutableArray array];
    _bots = [NSMutableArray array];
    _contactSections = [NSMutableArray array];
    _contactSectionTitles = [NSMutableArray array];
    _displayList = @[];
    _checkedIds = [NSMutableSet set];
    _checkedChannels = [NSMutableDictionary dictionary];

    [self setupNavBar];
    [self setupSearchBar];
    [self setupSegment];
    [self setupTableView];

    [self loadGroups];
    [self loadContactsAndBots];
}

#pragma mark - Setup

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

- (void)setupSegment {
    UIView *searchContainer = [self.view viewWithTag:8801];
    CGFloat y = searchContainer.lim_bottom;
    NSArray *titles = @[LLang(@"群聊"), LLang(@"联系人"), LLang(@"Bot")];
    _segment = [[WKDirSegment alloc] initWithFrame:CGRectMake(0, y, self.view.lim_width, 40) titles:titles];
    __weak typeof(self) ws = self;
    _segment.onChange = ^(NSInteger index) {
        ws.currentTab = index;
        [ws filterAndDisplay];
    };
    [self.view addSubview:_segment];
}

- (void)setupTableView {
    CGFloat y = _segment.lim_bottom;
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, y, self.view.lim_width, self.view.lim_height - y) style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.tableFooterView = [[UIView alloc] init];
    _tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _tableView.sectionIndexColor = [WKApp shared].config.themeColor;
    _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
    UITapGestureRecognizer *tapDismiss = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapDismiss.cancelsTouchesInView = NO;
    [_tableView addGestureRecognizer:tapDismiss];
    [_tableView registerClass:[WKDirCell class] forCellReuseIdentifier:@"dir"];
    [_tableView registerClass:[WKDirThreadCell class] forCellReuseIdentifier:@"thread"];
    [_tableView registerClass:[WKDirThreadToggleCell class] forCellReuseIdentifier:@"toggle"];
    [self.view addSubview:_tableView];
}

#pragma mark - Data: 群聊

- (void)loadGroups {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{@"page_size": @(1000)}];
    if (spaceId.length > 0) params[@"space_id"] = spaceId;

    [self.view showHUD];
    __weak typeof(self) ws = self;
    [[WKAPIClient sharedClient] GET:@"group/my" parameters:params].then(^(id resp) {
        [ws.view hideHud];
        NSArray *list = [resp isKindOfClass:[NSArray class]] ? resp : nil;
        [ws.groups removeAllObjects];
        for (id obj in list) {
            if (![obj isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *d = obj;
            NSString *groupNo = d[@"group_no"];
            if (groupNo.length == 0) continue;
            WKDirItem *item = [WKDirItem new];
            item.type = WKDirItemGroup;
            item.channelId = groupNo;
            NSString *remark = d[@"remark"];
            NSString *name = d[@"name"];
            item.displayName = (remark.length > 0) ? remark : (name ?: groupNo);
            item.parentGroupNo = groupNo;
            item.avatarURL = [WKAvatarUtil getGroupAvatar:groupNo];
            [ws.groups addObject:item];
        }
        if (ws.currentTab == WKDirTabGroup) [ws filterAndDisplay];
        // 预加载所有群的子区，使「+N个子区」能直接展示（与会话列表行为一致）
        [ws preloadAllThreads];
    }).catch(^(NSError *e) {
        [ws.view hideHud];
        if (ws.currentTab == WKDirTabGroup) [ws filterAndDisplay];
    });
}

/// 批量预加载所有群的子区，加载完成后刷新群聊 tab
- (void)preloadAllThreads {
    if (![WKApp shared].remoteConfig.threadOn) return;
    if (_groups.count == 0) return;
    // cap 在 20 (与 sibling ensureThreadsLoadedForSearch 一致); 否则大账号 cold
    // start 会对 N 个群并发跑 listAllThreads:maxPages:10 引爆请求风暴 (PR #32
    // R13 review: yujiawei / lml2468)。剩下的群等用户实际展开 / 搜索时再 lazy load
    // (didSelectRow / ensureThreadsLoadedForSearch 已覆盖)。
    static const NSInteger kMaxPreloadGroups = 20;
    NSInteger triggered = 0;
    __block NSInteger pending = 0;
    __weak typeof(self) ws = self;
    for (WKDirItem *g in _groups) {
        NSString *groupNo = g.channelId;
        if (groupNo.length == 0) continue;
        if (_threadCache[groupNo] || [_threadLoading containsObject:groupNo]) continue;
        if (triggered >= kMaxPreloadGroups) break;
        triggered++;
        pending++;
        [self loadThreadsForGroup:groupNo then:^{
            pending--;
            if (pending <= 0 && ws.currentTab == WKDirTabGroup && ws.keyword.length == 0) {
                [ws filterAndDisplay];
            }
        }];
    }
}

- (void)loadThreadsForGroup:(NSString *)groupNo then:(void(^)(void))then {
    if (_threadCache[groupNo] || [_threadLoading containsObject:groupNo]) {
        if (then) then();
        return;
    }
    if (![WKApp shared].remoteConfig.threadOn) {
        _threadCache[groupNo] = @[];
        if (then) then();
        return;
    }
    [_threadLoading addObject:groupNo];
    __weak typeof(self) ws = self;
    [[WKThreadService shared] listAllThreads:groupNo maxPages:10].then(^(NSArray<WKThreadModel *> *threads) {
        NSMutableArray *active = [NSMutableArray array];
        for (WKThreadModel *t in threads) {
            if (t.status == WKThreadStatusActive) [active addObject:t];
        }
        [active sortUsingComparator:^NSComparisonResult(WKThreadModel *a, WKThreadModel *b) {
            return [b.updatedAt compare:a.updatedAt];
        }];
        ws.threadCache[groupNo] = active;
        [ws.threadLoading removeObject:groupNo];
        if (then) then();
    }).catch(^(NSError *e) {
        ws.threadCache[groupNo] = @[];
        [ws.threadLoading removeObject:groupNo];
        if (then) then();
    });
}

#pragma mark - Data: 联系人 / Bot

- (void)loadContactsAndBots {
    // 联系人：本地 DB（与现有选人页同口径）
    NSArray<WKChannelInfo *> *infos = [[WKChannelInfoDB shared] queryChannelInfosWithStatusAndFollow:WKChannelStatusNormal follow:WKChannelInfoFollowFriend];
    NSMutableArray<WKDirItem *> *contactItems = [NSMutableArray array];
    for (WKChannelInfo *info in infos) {
        if (info.robot) continue; // bot 单独成 tab
        WKDirItem *item = [WKDirItem new];
        item.type = WKDirItemContact;
        item.channelId = info.channel.channelId;
        item.displayName = info.displayName.length > 0 ? info.displayName : (info.name ?: info.channel.channelId);
        item.isRobot = NO;
        if (info.logo.length > 0) {
            item.avatarURL = [WKAvatarUtil getFullAvatarWIthPath:info.logo];
        } else {
            item.avatarURL = [WKAvatarUtil getAvatar:info.channel.channelId cacheKey:info.avatarCacheKey];
        }
        [contactItems addObject:item];
    }
    _contacts = contactItems;
    [self regroupContacts];

    // Bot：仅已添加 bot
    [self loadBots];
}

- (void)regroupContacts {
    __weak typeof(self) ws = self;
    [WKChineseSort sortAndGroup:_contacts key:@"displayName" finish:^(bool isSuccess, NSMutableArray *unGroupedArr, NSMutableArray *sectionTitleArr, NSMutableArray<NSMutableArray *> *sortedObjArr) {
        if (isSuccess) {
            ws.contactSectionTitles = sectionTitleArr;
            ws.contactSections = sortedObjArr;
        } else {
            ws.contactSectionTitles = [@[] mutableCopy];
            ws.contactSections = [@[ws.contacts] mutableCopy];
        }
        if (ws.currentTab == WKDirTabContact) [ws filterAndDisplay];
    }];
}

- (void)loadBots {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    __weak typeof(self) ws = self;
    if (spaceId.length > 0) {
        AnyPromise *myBots = [[WKAPIClient sharedClient] GET:@"robot/my_bots" parameters:@{@"space_id": spaceId}];
        AnyPromise *spaceBots = [[WKAPIClient sharedClient] GET:@"robot/space_bots" parameters:@{@"space_id": spaceId}];
        PMKWhen(@[myBots, spaceBots]).then(^(NSArray *results) {
            NSMutableArray<WKDirItem *> *bots = [NSMutableArray array];
            NSMutableSet *addedUids = [NSMutableSet set];
            NSArray *my = results.count > 0 ? results[0] : @[];
            if ([my isKindOfClass:[NSArray class]]) {
                for (id obj in my) {
                    if (![obj isKindOfClass:[NSDictionary class]]) continue;
                    WKDirItem *b = [ws botItemFromDict:obj];
                    if (b.channelId.length == 0) continue;
                    [bots addObject:b];
                    [addedUids addObject:b.channelId];
                }
            }
            NSArray *sp = results.count > 1 ? results[1] : @[];
            if ([sp isKindOfClass:[NSArray class]]) {
                for (id obj in sp) {
                    if (![obj isKindOfClass:[NSDictionary class]]) continue;
                    NSDictionary *d = obj;
                    NSString *uid = d[@"uid"];
                    if (uid.length == 0 || [addedUids containsObject:uid]) continue;
                    if (![d[@"status"] isEqual:@"added"]) continue;
                    [bots addObject:[ws botItemFromDict:d]];
                    [addedUids addObject:uid];
                }
            }
            ws.bots = bots;
            if (ws.currentTab == WKDirTabBot) [ws filterAndDisplay];
        }).catch(^(NSError *e) {});
    } else {
        [[WKAPIClient sharedClient] GET:@"robot/my_bots" parameters:nil].then(^(id resp) {
            NSMutableArray<WKDirItem *> *bots = [NSMutableArray array];
            if ([resp isKindOfClass:[NSArray class]]) {
                for (id obj in resp) {
                    if (![obj isKindOfClass:[NSDictionary class]]) continue;
                    WKDirItem *b = [ws botItemFromDict:obj];
                    if (b.channelId.length > 0) [bots addObject:b];
                }
            }
            ws.bots = bots;
            if (ws.currentTab == WKDirTabBot) [ws filterAndDisplay];
        }).catch(^(NSError *e) {});
    }
}

- (WKDirItem *)botItemFromDict:(NSDictionary *)d {
    WKDirItem *item = [WKDirItem new];
    item.type = WKDirItemContact;
    item.channelId = d[@"uid"] ?: @"";
    NSString *name = d[@"name"];
    item.displayName = name.length > 0 ? name : item.channelId;
    item.isRobot = YES;
    item.avatarURL = [WKAvatarUtil getAvatar:item.channelId];
    return item;
}

#pragma mark - Filter & Display

- (void)filterAndDisplay {
    _keyword = [_searchField.text lowercaseString] ?: @"";
    BOOL searching = _keyword.length > 0;
    _contactsGrouped = (_currentTab == WKDirTabContact && !searching);

    NSMutableArray<WKDirItem *> *list = [NSMutableArray array];

    if (_currentTab == WKDirTabGroup) {
        for (WKDirItem *g in _groups) {
            BOOL groupMatch = !searching || [g.displayName.lowercaseString containsString:_keyword];
            // 搜索态：父群匹配 或 任意已加载子区匹配，则展示该群
            NSArray<WKThreadModel *> *threads = _threadCache[g.channelId];
            NSMutableArray<WKThreadModel *> *matchedThreads = [NSMutableArray array];
            if (searching && threads) {
                for (WKThreadModel *t in threads) {
                    if ([t.name.lowercaseString containsString:_keyword]) [matchedThreads addObject:t];
                }
            }
            if (searching && !groupMatch && matchedThreads.count == 0) continue;

            [list addObject:g];

            if (searching) {
                // 搜索态：直接平铺匹配到的子区
                for (WKThreadModel *t in matchedThreads) {
                    [list addObject:[self threadItemFrom:t parent:g.channelId]];
                }
            } else if (threads.count > 0) {
                // 非搜索：toggle + 展开
                WKDirItem *toggle = [WKDirItem new];
                toggle.type = WKDirItemThreadToggle;
                toggle.parentGroupNo = g.channelId;
                toggle.threadCount = threads.count;
                toggle.threadExpanded = [_expandedGroups containsObject:g.channelId];
                [list addObject:toggle];
                if (toggle.threadExpanded) {
                    for (WKThreadModel *t in threads) {
                        [list addObject:[self threadItemFrom:t parent:g.channelId]];
                    }
                }
            }
        }
        // 搜索态需要把还没加载子区的群补载一次，以便能搜到子区
        if (searching) [self ensureThreadsLoadedForSearch];
    } else if (_currentTab == WKDirTabBot) {
        for (WKDirItem *b in _bots) {
            if (searching && ![b.displayName.lowercaseString containsString:_keyword]) continue;
            [list addObject:b];
        }
    } else {
        // 联系人
        if (searching) {
            for (WKDirItem *c in _contacts) {
                if ([c.displayName.lowercaseString containsString:_keyword]) [list addObject:c];
            }
        }
        // 非搜索走分组 section，displayList 不用
    }

    [self applyCheckedState:list];
    _displayList = list;
    [_tableView reloadData];
}

- (WKDirItem *)threadItemFrom:(WKThreadModel *)t parent:(NSString *)groupNo {
    WKDirItem *ti = [WKDirItem new];
    ti.type = WKDirItemThread;
    ti.channelId = t.channelId;
    ti.displayName = t.name;
    ti.parentGroupNo = groupNo;
    return ti;
}

/// 搜索群时把尚未加载子区的群批量补载（节流：一次最多触发若干个），加载完重刷
- (void)ensureThreadsLoadedForSearch {
    if (![WKApp shared].remoteConfig.threadOn) return;
    NSInteger triggered = 0;
    __weak typeof(self) ws = self;
    for (WKDirItem *g in _groups) {
        if (triggered >= 20) break; // 避免一次性打爆
        if (_threadCache[g.channelId] || [_threadLoading containsObject:g.channelId]) continue;
        triggered++;
        [self loadThreadsForGroup:g.channelId then:^{
            // 仍处于搜索态时刷新
            if (ws.keyword.length > 0 && ws.currentTab == WKDirTabGroup) {
                [ws filterAndDisplay];
            }
        }];
    }
}

- (void)applyCheckedState:(NSArray<WKDirItem *> *)list {
    // 选中态用 checkedIds（channelId+type 维度），cell 渲染时直接查
}

- (NSString *)checkKeyForItem:(WKDirItem *)item {
    if (item.type == WKDirItemThread) return [@"t_" stringByAppendingString:item.channelId ?: @""];
    if (item.type == WKDirItemGroup) return [@"g_" stringByAppendingString:item.channelId ?: @""];
    return [@"p_" stringByAppendingString:item.channelId ?: @""];
}

- (WKChannel *)channelForItem:(WKDirItem *)item {
    if (item.type == WKDirItemThread) {
        return [WKChannel channelID:item.channelId channelType:WK_COMMUNITY_TOPIC];
    }
    if (item.type == WKDirItemGroup) {
        return [WKChannel channelID:item.channelId channelType:WK_GROUP];
    }
    return [WKChannel channelID:item.channelId channelType:WK_PERSON];
}

#pragma mark - Search

- (void)searchTextChanged { [self filterAndDisplay]; }
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }
- (void)dismissKeyboard { [self.view endEditing:YES]; }

#pragma mark - TableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_contactsGrouped) return MAX(1, (NSInteger)_contactSections.count);
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_contactsGrouped) {
        if (section < (NSInteger)_contactSections.count) return _contactSections[section].count;
        return 0;
    }
    return _displayList.count;
}

- (WKDirItem *)itemAt:(NSIndexPath *)indexPath {
    if (_contactsGrouped) {
        if (indexPath.section < (NSInteger)_contactSections.count) {
            NSArray *rows = _contactSections[indexPath.section];
            if (indexPath.row < (NSInteger)rows.count) return rows[indexPath.row];
        }
        return nil;
    }
    if (indexPath.row < (NSInteger)_displayList.count) return _displayList[indexPath.row];
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKDirItem *item = [self itemAt:indexPath];
    if (!item) return 0;
    switch (item.type) {
        case WKDirItemThreadToggle: return 30;
        case WKDirItemThread: return 40;
        case WKDirItemGroup: return 48;
        case WKDirItemContact: return 56;
    }
    return 48;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (_contactsGrouped && section < (NSInteger)_contactSectionTitles.count) return 24;
    return 0.01;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (!_contactsGrouped || section >= (NSInteger)_contactSectionTitles.count) return nil;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.lim_width, 24)];
    header.backgroundColor = [WKApp shared].config.backgroundColor;
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 200, 24)];
    lbl.text = _contactSectionTitles[section];
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor grayColor];
    [header addSubview:lbl];
    return header;
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (_contactsGrouped) return _contactSectionTitles;
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKDirItem *item = [self itemAt:indexPath];
    if (!item) return [tableView dequeueReusableCellWithIdentifier:@"dir" forIndexPath:indexPath];

    if (item.type == WKDirItemThread) {
        WKDirThreadCell *tc = [tableView dequeueReusableCellWithIdentifier:@"thread" forIndexPath:indexPath];
        tc.nameLbl.text = item.displayName;
        [self applyAccessory:tc item:item];
        return tc;
    }
    if (item.type == WKDirItemThreadToggle) {
        WKDirThreadToggleCell *tg = [tableView dequeueReusableCellWithIdentifier:@"toggle" forIndexPath:indexPath];
        tg.titleLbl.text = [NSString stringWithFormat:@"%ld%@", (long)item.threadCount, LLang(@"个子区")];
        tg.arrowView.image = [self chevronImage];
        tg.arrowView.transform = item.threadExpanded ? CGAffineTransformIdentity : CGAffineTransformMakeRotation(-M_PI_2);
        return tg;
    }
    WKDirCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dir" forIndexPath:indexPath];
    [cell configureWithItem:item];
    [self applyAccessory:cell item:item];
    return cell;
}

/// 多选时给行加勾选标记（toggle 行除外）
- (void)applyAccessory:(UITableViewCell *)cell item:(WKDirItem *)item {
    if (self.singleSelectMode || item.type == WKDirItemThreadToggle) {
        cell.accessoryView = nil;
        return;
    }
    BOOL checked = [_checkedIds containsObject:[self checkKeyForItem:item]];
    UIImageView *iv = [[UIImageView alloc] initWithImage:checked ? [self checkOnImage] : [self checkOffImage]];
    iv.frame = CGRectMake(0, 0, 22, 22);
    cell.accessoryView = iv;
}

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WKDirItem *item = [self itemAt:indexPath];
    if (!item) return;

    if (item.type == WKDirItemThreadToggle) {
        NSString *gno = item.parentGroupNo;
        if ([_expandedGroups containsObject:gno]) {
            [_expandedGroups removeObject:gno];
            [self filterAndDisplay];
        } else {
            [_expandedGroups addObject:gno];
            // 确保子区已加载
            [self loadThreadsForGroup:gno then:^{ [self filterAndDisplay]; }];
        }
        return;
    }

    WKChannel *channel = [self channelForItem:item];

    if (self.singleSelectMode) {
        BOOL isGroup = (item.type == WKDirItemGroup);
        BOOL isThread = (item.type == WKDirItemThread);
        __weak typeof(self) ws = self;
        [WKForwardConfirmPanel showForChannel:channel
                                         name:item.displayName
                                      isGroup:isGroup
                                     isThread:isThread
                               shareFileInfos:self.shareFileInfos
                                       onSend:^(NSString * _Nullable extraText) {
            if (ws.onSingleConfirm) {
                ws.onSingleConfirm(channel, extraText);
            } else if (ws.onSelect) {
                ws.onSelect(channel);
            }
            [ws popBackToForwardCaller];
        }];
        return;
    }

    // 多选 toggle
    NSString *key = [self checkKeyForItem:item];
    if ([_checkedIds containsObject:key]) {
        [_checkedIds removeObject:key];
        [_checkedChannels removeObjectForKey:key];
    } else {
        [_checkedIds addObject:key];
        _checkedChannels[key] = channel;
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
    if (_confirming) return;
    _confirming = YES;
    NSArray<WKChannel *> *channels = _checkedChannels.allValues;
    if (channels.count > 0) {
        if (self.onConfirmChannels) {
            self.onConfirmChannels(channels);
        } else if (self.onSelect) {
            for (WKChannel *ch in channels) self.onSelect(ch);
        }
    }
    [self popBackToForwardCaller];
}

/// 转发完成后，pop 回最初发起转发的页面（目录页 + 转发页两层）
- (void)popBackToForwardCaller {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 栈结构：发起页 -> WKForwardSelectVC -> 本目录页。回退到发起页。
        UINavigationController *nav = self.navigationController;
        NSArray<UIViewController *> *stack = nav.viewControllers;
        if (nav && stack.count >= 3) {
            UIViewController *target = stack[stack.count - 3];
            [nav popToViewController:target animated:YES];
            return;
        }
        // 兜底：逐层回退
        [[WKNavigationManager shared] popViewControllerAnimated:NO];
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    });
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
