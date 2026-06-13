//
//  WKForwardSelectVC.m
//  WuKongBase
//
//  转发选择会话：关注/最近 Tab + 分组 + 子区折叠 + 多选 + 搜索
//  口径与会话列表保持一致：
//    关注 tab —— WKFollowedKeysStore 提供的已关注集合（DM/Channel/Thread），
//                按用户分组展示，分组内含群、群下子区、已关注 DM。
//    最近 tab —— SDK getConversationList 的全部类型（DM/群/子区），按时间倒序平铺。
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
#import "WKSpaceFilter.h"
#import "WKConversationListVM.h"
#import "WKSearchbarView.h"
#import "WKForwardConfirmPanel.h"
#import "WKForwardDirectoryVC.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import "WKFollowedKeysStore.h"
#import "WKSidebarItemEntity.h"
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
    _hashTagLbl.hidden = YES;
    _avatarView.hidden = NO;

    NSString *avatarURL = nil;
    if (isGroup) {
        avatarURL = [WKAvatarUtil getGroupAvatar:model.channel.channelId];
        if (model.channelInfo.logo.length > 0) {
            avatarURL = [WKAvatarUtil getFullAvatarWIthPath:model.channelInfo.logo];
        }
    } else if (model.channelInfo) {
        avatarURL = [WKAvatarUtil getAvatar:model.channel.channelId cacheKey:model.channelInfo.avatarCacheKey];
        if (model.channelInfo.logo.length > 0) {
            avatarURL = [WKAvatarUtil getFullAvatarWIthPath:model.channelInfo.logo];
        }
    }
    [_avatarView.avatarImgView sd_setImageWithURL:[NSURL URLWithString:avatarURL ?: @""]
                                 placeholderImage:[WKApp.shared loadImage:@"Common/Index/DefaultAvatar" moduleID:@"WuKongBase"]];
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

    _avatarView.frame = CGRectMake(left + 3, (h - 40) / 2, 40, 40);
    _nameLbl.frame = CGRectMake(left + 48, 0, w - left - 63, h);
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
// 跨刷新持久化勾选 channel——按 uniqueKey 反查。原 onConfirm 走 _displayList 遍历,
// 折叠 section / 切 tab 后那些 row 不在 _displayList 里, 勾选静默丢 (PR #32 R7 review)。
// 与 sibling WKForwardDirectoryVC._checkedChannels 同款思路, 与 _checkedIds 一一对偶维护。
@property (nonatomic, strong) NSMutableDictionary<NSString *, WKChannel *> *checkedChannels;
// 一次性 guard: onConfirm 内 dispatch_after 0.3s 才 pop, 期间 confirmBtn 仍 tappable,
// 下游 forwardMessage: 链路无 dedup, 一秒内双击会双发 (PR #32 R10 review)。
@property (nonatomic, assign) BOOL confirming;

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
    _checkedChannels = [NSMutableDictionary dictionary];

    // 预选: 把外部传进来的 channels 直接打勾, 用户就是来 "二次编辑" 的, 不用全选一遍。
    // 与 cell 的 isChecked 同步靠 reload(loadData → reloadData), 这里只填 backing store。
    //
    // 关键: _checkedIds 的 key 格式必须与 FWDisplayItem.uniqueKey 完全一致,
    // 否则 applyCheckedState: 用 uniqueKey 反查时根本对不上, cell 永远不打勾。
    // FWDisplayItem.uniqueKey 对 FWItemThread 返回的是 "纯 channelId" (不带 "_5"),
    // 对 FWItemConversation 才返回 "channelId_channelType"。这里走相同口径。
    if (self.preselectedChannels.count > 0) {
        for (WKChannel *ch in self.preselectedChannels) {
            if (ch.channelId.length == 0) continue;
            NSString *key = (ch.channelType == WK_COMMUNITY_TOPIC)
                ? ch.channelId
                : [NSString stringWithFormat:@"%@_%d", ch.channelId, ch.channelType];
            [_checkedIds addObject:key];
            _checkedChannels[key] = ch;
            // 子区: 解析出父群 groupNo (channelId 形如 "groupNo____shortId"), 加进展开集合,
            // 否则父群默认折叠, 用户看不见已勾选的子区还以为没选上。
            if (ch.channelType == WK_COMMUNITY_TOPIC) {
                NSArray *parts = [ch.channelId componentsSeparatedByString:@"____"];
                if (parts.count >= 2) {
                    NSString *groupNo = parts[0];
                    if (groupNo.length > 0) [_expandedThreadGroups addObject:groupNo];
                }
            }
        }
    }

    [self setupNavBar];
    [self setupSearchBar];
    [self setupNewSessionEntry];
    [self setupTabView];
    [self setupTableView];
    [self loadData];

    // store 异步加载完成后刷新关注 tab —— 冷启动时 store 还没数据，filterAndDisplay 退化路径
    // 拿到的内容跟用户期望不符；store 一就绪就重排。
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onFollowedKeysStoreDidUpdate)
                                                 name:kWKFollowedKeysStoreDidUpdateNotification
                                               object:nil];

    // preselect 已经填充 _checkedIds, 立刻把右上 "确定(N)" 显出来,
    // 不必等用户再勾一下才看到当前选中数量。
    if (_checkedIds.count > 0) {
        [self updateConfirmBtn];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onFollowedKeysStoreDidUpdate {
    if (_currentTab != 0) return;
    [self filterAndDisplay];
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

- (void)setupNewSessionEntry {
    UIView *searchContainer = [self.view viewWithTag:8801];
    CGFloat y = searchContainer.lim_bottom;
    CGFloat w = self.view.lim_width;
    CGFloat h = 38;

    UIView *entry = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, h)];
    entry.backgroundColor = [WKApp shared].config.backgroundColor;
    entry.tag = 8802;

    // 右侧蓝色文字链接「新建会话」（仿微信「创建聊天」）
    UIButton *createBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [createBtn setTitle:LLang(@"新建会话") forState:UIControlStateNormal];
    [createBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    createBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    [createBtn addTarget:self action:@selector(onNewSessionTap) forControlEvents:UIControlEventTouchUpInside];
    CGFloat btnW = 90;
    createBtn.frame = CGRectMake(w - btnW - 15, 0, btnW, h);
    createBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [entry addSubview:createBtn];

    [self.view addSubview:entry];
}

- (void)onNewSessionTap {
    WKForwardDirectoryVC *vc = [WKForwardDirectoryVC new];
    vc.singleSelectMode = self.singleSelectMode;
    vc.shareFileInfos = self.shareFileInfos;
    vc.onSelect = self.onSelect;
    vc.onConfirmChannels = self.onConfirmChannels;
    vc.onSingleConfirm = self.onSingleConfirm;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)setupTabView {
    UIView *entry = [self.view viewWithTag:8802];
    CGFloat y = entry.lim_bottom;
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
        // 不再过滤 WK_COMMUNITY_TOPIC —— 最近 tab 要展示子区会话，关注 tab 也要用子区 followed 集合。
        // 按当前空间过滤 (跨空间的会话不应出现在转发候选里)。
        if (![self shouldKeepConversationForSpace:conv]) continue;
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
            // 与 loadData 保持一致：含 WK_COMMUNITY_TOPIC + 当前空间过滤。
            if (![ws shouldKeepConversationForSpace:conv]) continue;
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

#pragma mark - Filtering helpers

// 按当前空间过滤会话: 直接复用主列表 WKConversationListVM (singleton) 的
// shouldShowConversation:, 与主会话列表完全一致 — 含 WKSpaceFilter 决策 + 系统/
// 文件助手/BotFather 放行 + WK_GROUP FailOpen 时降级走 syncedGroupChannelIds
// 白名单 + WK_PERSON FailOpen 时看 lastMessage.content.space_id 兜底。
// 子区由父群代表 anchor, 转发候选放行 (子区关闭/删除另由 isTopicChannelVisible 过滤)。
- (BOOL)shouldKeepConversationForSpace:(WKConversation *)conv {
    if (conv.channel.channelType == WK_COMMUNITY_TOPIC) return YES;
    return [[WKConversationListVM shared] shouldShowConversation:conv];
}

// 子区在最近 tab 是否可见: 过滤掉已关闭/删除的子区。
// 两个判定信号互为兜底:
//   1) channelInfo.displayName 空 → server 端不再下发 thread info, 大概率是
//      关闭/删除 (cache miss 也会空, 但即便误判, 没名字的子区用户也用不上)
//   2) _threadCache 已加载 (_threadsLoaded=YES) 但找不到该 channelId →
//      server 端不再返回 = WKThreadStatus Archived / Deleted
// fail-open: thread cache 未加载时不过滤, 等用户后续刷新自然收敛, 避免错过滤。
- (BOOL)isTopicChannelVisible:(WKConversationWrapModel *)m {
    NSString *displayName = m.channelInfo ? m.channelInfo.displayName : @"";
    if (displayName.length == 0) return NO;
    if (!_threadsLoaded) return YES;
    NSString *cid = m.channel.channelId;
    // 子区 channelId 格式: "groupNo____shortId" (4 下划线, 见 WKThreadModel.h:21)
    NSArray *parts = [cid componentsSeparatedByString:@"____"];
    if (parts.count < 2) return YES;
    NSString *groupNo = parts[0];
    NSArray<WKThreadModel *> *threads = _threadCache[groupNo];
    if (threads.count == 0) return YES;  // 父群的 thread 列表还没拉到, fail-open
    for (WKThreadModel *t in threads) {
        if ([t.channelId isEqualToString:cid]) {
            return t.status == WKThreadStatusActive;
        }
    }
    return NO;  // thread 列表已加载但找不到这个 channelId → 已 archived/deleted
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
        // 关注 tab：按用户分组显示「已关注的群（含群下子区）+ 已关注 DM」。
        // 关注集合的唯一可信源是 WKFollowedKeysStore（与会话列表关注 tab 同源）；store 没加载完
        // 时退化到「展示自定义分组下所有群」的旧行为，避免冷启动时关注 tab 一片空白。
        WKFollowedKeysStore *followStore = [WKFollowedKeysStore shared];
        BOOL followLoaded = followStore.loaded;
        NSSet<NSString *> *followedGroupNos = followStore.followedGroupNos;
        NSDictionary<NSString *, NSArray<WKSidebarItemEntity *> *> *followItemsByCat = followStore.itemsByCategory;

        // 建立 channelId → wrap 映射，DM 也要建（关注 tab 要展示已关注 DM）。
        NSMutableDictionary<NSString *, WKConversationWrapModel *> *groupMap = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString *, WKConversationWrapModel *> *dmMap = [NSMutableDictionary dictionary];
        for (WKConversationWrapModel *m in _allConversations) {
            if (m.channel.channelType == WK_GROUP) groupMap[m.channel.channelId] = m;
            else if (m.channel.channelType == WK_PERSON) dmMap[m.channel.channelId] = m;
        }

        for (WKCategoryEntity *cat in _categoryList) {
            if (!cat.category_id || cat.category_id.length == 0) continue;
            if (cat.is_default) continue; // 默认分组不显示 header

            // 计算本分组要展示的群与 DM
            NSMutableArray<WKConversationWrapModel *> *visibleGroups = [NSMutableArray array];
            for (WKCategoryGroup *cg in cat.groups) {
                if (followLoaded && ![followedGroupNos containsObject:cg.group_no]) continue;
                WKConversationWrapModel *m = groupMap[cg.group_no];
                if (m) [visibleGroups addObject:m];
            }
            NSMutableArray<WKConversationWrapModel *> *visibleDMs = [NSMutableArray array];
            NSArray<WKSidebarItemEntity *> *items = followItemsByCat[cat.category_id] ?: @[];
            NSMutableSet<NSString *> *addedDMIds = [NSMutableSet set];
            for (WKSidebarItemEntity *it in items) {
                if (it.target_type != WKFollowTargetTypeDM) continue;
                if (it.target_id.length == 0) continue;
                if ([addedDMIds containsObject:it.target_id]) continue;
                WKConversationWrapModel *dm = dmMap[it.target_id];
                if (dm) {
                    [visibleDMs addObject:dm];
                    [addedDMIds addObject:it.target_id];
                }
            }

            // store 没加载完时退化：展示分组下所有有 conv 的群，DM 集合为空（无可信源）
            if (!followLoaded) {
                [visibleGroups removeAllObjects];
                for (WKCategoryGroup *cg in cat.groups) {
                    WKConversationWrapModel *m = groupMap[cg.group_no];
                    if (m) [visibleGroups addObject:m];
                }
            }

            if (visibleGroups.count == 0 && visibleDMs.count == 0) continue;

            FWDisplayItem *header = [FWDisplayItem new];
            header.type = FWItemSectionHeader;
            header.sectionId = cat.category_id;
            header.sectionTitle = cat.name;
            [list addObject:header];

            if (![_collapsedSections containsObject:cat.category_id]) {
                [self sortList:visibleGroups];
                for (WKConversationWrapModel *m in visibleGroups) {
                    FWDisplayItem *ci = [FWDisplayItem new]; ci.type = FWItemConversation; ci.conversation = m;
                    [list addObject:ci];
                    [self appendThreads:list forGroupNo:m.channel.channelId];
                }
                [self sortList:visibleDMs];
                for (WKConversationWrapModel *dm in visibleDMs) {
                    FWDisplayItem *ci = [FWDisplayItem new]; ci.type = FWItemConversation; ci.conversation = dm;
                    [list addObject:ci];
                }
            }
        }
    } else {
        // 最近 tab：DM + 群 + 子区，按时间倒序平铺（置顶优先），与会话列表最近 tab 同口径。
        NSMutableArray<WKConversationWrapModel *> *flat = [NSMutableArray array];
        for (WKConversationWrapModel *m in _allConversations) {
            uint8_t type = m.channel.channelType;
            if (type == WK_PERSON || type == WK_GROUP) {
                [flat addObject:m];
            } else if (type == WK_COMMUNITY_TOPIC) {
                // 过滤掉已关闭/删除的子区 + 名字空的子区
                if (![self isTopicChannelVisible:m]) continue;
                [flat addObject:m];
            }
        }
        [self sortList:flat];
        for (WKConversationWrapModel *m in flat) {
            FWDisplayItem *ci = [FWDisplayItem new];
            // 子区用 FWItemThread cell（# 图标 + name）以与关注 tab 子区行视觉一致。
            if (m.channel.channelType == WK_COMMUNITY_TOPIC) {
                ci.type = FWItemThread;
                ci.threadChannelId = m.channel.channelId;
                ci.threadName = m.channelInfo ? m.channelInfo.displayName : @"";
            } else {
                ci.type = FWItemConversation;
                ci.conversation = m;
            }
            [list addObject:ci];
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

    WKFollowedKeysStore *followStore = [WKFollowedKeysStore shared];
    BOOL followLoaded = followStore.loaded;
    NSSet<NSString *> *followedGroupNos = followStore.followedGroupNos;

    for (WKConversationWrapModel *m in _allConversations) {
        uint8_t type = m.channel.channelType;
        if (_currentTab == 0) {
            // 关注 tab 搜索范围：已关注的群 + 已关注 DM + 已关注子区。store 未加载时退化到群/DM/子区全部。
            if (type == WK_GROUP) {
                if (followLoaded && ![followedGroupNos containsObject:m.channel.channelId]) continue;
            } else if (type == WK_PERSON) {
                if (followLoaded && ![followStore isFollowedWithType:WKFollowTargetTypeDM targetId:m.channel.channelId]) continue;
            } else if (type == WK_COMMUNITY_TOPIC) {
                if (followLoaded && ![followStore isFollowedWithType:WKFollowTargetTypeThread targetId:m.channel.channelId]) continue;
            } else {
                continue;
            }
        } else {
            // 最近 tab 搜索范围：DM + 群 + 子区。
            if (type != WK_PERSON && type != WK_GROUP && type != WK_COMMUNITY_TOPIC) continue;
            // 子区: 过滤已关闭/删除 (与 filterAndDisplay 最近 tab 同口径)
            if (type == WK_COMMUNITY_TOPIC && ![self isTopicChannelVisible:m]) continue;
        }
        NSString *name = m.channelInfo ? m.channelInfo.displayName : @"";
        if (![name.lowercaseString containsString:lower]) continue;
        FWDisplayItem *ci = [FWDisplayItem new];
        if (type == WK_COMMUNITY_TOPIC) {
            ci.type = FWItemThread;
            ci.threadChannelId = m.channel.channelId;
            ci.threadName = name;
        } else {
            ci.type = FWItemConversation;
            ci.conversation = m;
        }
        [list addObject:ci];
    }

    // 关注 tab 还要补一类子区：通过群下子区缓存（WKThreadService 拉到、但未必在 conversationList 里）搜索，
    // 仅当 store 已加载时按 followed 过滤；未加载时回退展示全部命中。
    if (_currentTab == 0) {
        NSMutableSet<NSString *> *alreadyAdded = [NSMutableSet set];
        for (FWDisplayItem *item in list) {
            if (item.type == FWItemThread && item.threadChannelId.length > 0) {
                [alreadyAdded addObject:item.threadChannelId];
            }
        }
        for (NSString *groupNo in _threadCache) {
            if (followLoaded && ![followedGroupNos containsObject:groupNo]) continue;
            for (WKThreadModel *t in _threadCache[groupNo]) {
                if ([alreadyAdded containsObject:t.channelId]) continue;
                if (followLoaded && ![followStore isFollowedWithType:WKFollowTargetTypeThread targetId:t.channelId]) continue;
                if (![t.name.lowercaseString containsString:lower]) continue;
                FWDisplayItem *ti = [FWDisplayItem new];
                ti.type = FWItemThread;
                ti.threadChannelId = t.channelId;
                ti.threadName = t.name;
                [list addObject:ti];
                [alreadyAdded addObject:t.channelId];
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
            // onLongPress 属性已移除：WKCategorySectionCell 不再持有长按手势，
            // 长按交互由消费方 VC 上的统一手势驱动；转发选择页本就不需要长按。
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
        if (item.isChecked) {
            [_checkedIds addObject:key];
            // 同步记录 channel, onConfirm 直接读 _checkedChannels.allValues 不走 _displayList。
            WKChannel *ch = nil;
            if (item.type == FWItemConversation && item.conversation) {
                ch = item.conversation.channel;
            } else if (item.type == FWItemThread && item.threadChannelId) {
                ch = [WKChannel channelID:item.threadChannelId channelType:WK_COMMUNITY_TOPIC];
            }
            if (ch) _checkedChannels[key] = ch;
        } else {
            [_checkedIds removeObject:key];
            [_checkedChannels removeObjectForKey:key];
        }
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
        // sizeToFit 只更新 bounds.size, 不动 frame.origin —— 父 WKNavigationBar.setRightView:
        // 在 view 安装时按当时宽度算了 lim_left, 之后 title 加长(数量上去)就会撞到屏幕右边缘
        // (用户报"按钮太靠近右侧"的根因)。这里手动按新宽度重锚回 20pt 右边距。
        UIView *parent = _confirmBtn.superview;
        if (parent.lim_width > 0) {
            _confirmBtn.lim_left = parent.lim_width - _confirmBtn.lim_width - 20.0;
        }
    } else {
        _confirmBtn.hidden = YES;
    }
}

- (void)onConfirm {
    if (_confirming) return;
    _confirming = YES;
    // 直接读持久化的 _checkedChannels, 与 _displayList 解耦; 否则折叠 section
    // 或切 tab 把行移出 _displayList 后, 勾选会被静默丢掉 (PR #32 R7 review)。
    NSArray<WKChannel *> *channels = [_checkedChannels.allValues copy];

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
    __weak typeof(self) ws = self;
    [WKForwardConfirmPanel showForChannel:channel
                                     name:name
                                  isGroup:isGroup
                                 isThread:isThread
                           shareFileInfos:self.shareFileInfos
                                   onSend:^(NSString * _Nullable extraText) {
        if (channel) {
            if (ws.onSingleConfirm) {
                ws.onSingleConfirm(channel, extraText);
            } else if (ws.onSelect) {
                ws.onSelect(channel);
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[WKNavigationManager shared] popViewControllerAnimated:YES];
        });
    }];
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
