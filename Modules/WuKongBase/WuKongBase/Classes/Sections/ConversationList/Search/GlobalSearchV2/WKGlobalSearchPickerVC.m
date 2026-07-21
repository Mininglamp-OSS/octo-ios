//
//  WKGlobalSearchPickerVC.m
//  WuKongBase
//

#import "WKGlobalSearchPickerVC.h"
#import "WKUserAvatar.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import "UIView+WKCommon.h"

#define kPickerSearchDebounceMs 300
#define kPickerSearchBarH 36.0f
#define kPickerRowH 56.0f

@implementation WKGlobalSearchPickEntry
+ (instancetype)entryWithId:(NSString *)identifier name:(NSString *)name avatarUrl:(nullable NSString *)avatarUrl channelType:(NSInteger)channelType {
    WKGlobalSearchPickEntry *e = [WKGlobalSearchPickEntry new];
    e.identifier = identifier ?: @"";
    e.name = name ?: @"";
    e.avatarUrl = avatarUrl;
    e.channelType = channelType;
    return e;
}
@end

@interface WKGlobalSearchPickerVC () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIView *searchBarContainer;
@property (nonatomic, strong) UITextField *searchInput;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *applyBtn;

@property (nonatomic, copy) NSArray<WKGlobalSearchPickEntry *> *candidates;
/// 选中 id 集合（顺序保留）。
@property (nonatomic, strong) NSMutableArray<NSString *> *selectedIds;
/// id → entry（含预选 + 搜索中发现的），用于回传名称。
@property (nonatomic, strong) NSMutableDictionary<NSString *, WKGlobalSearchPickEntry *> *entryById;
@end

@implementation WKGlobalSearchPickerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.title = self.navTitle ?: LLang(@"选择");

    self.selectedIds = [NSMutableArray array];
    self.entryById = [NSMutableDictionary dictionary];
    self.candidates = @[];
    for (WKGlobalSearchPickEntry *e in self.preselected) {
        if (e.identifier.length == 0) continue;
        if (![self.selectedIds containsObject:e.identifier]) [self.selectedIds addObject:e.identifier];
        self.entryById[e.identifier] = e;
    }

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:LLang(@"完成")
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(onApply)];

    [self setupSearchBar];
    [self setupTable];
    [self runSearch:@""];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)setupSearchBar {
    self.searchBarContainer = [UIView new];
    self.searchBarContainer.backgroundColor = [WKApp shared].config.backgroundColor;
    [self.view addSubview:self.searchBarContainer];

    UIView *bg = [UIView new];
    bg.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.10];
    bg.layer.cornerRadius = kPickerSearchBarH / 2.0f;
    bg.layer.masksToBounds = YES;
    bg.tag = 200;
    [self.searchBarContainer addSubview:bg];

    UILabel *icon = [UILabel new];
    icon.text = @"🔍";
    icon.font = [UIFont systemFontOfSize:14.0f];
    icon.textAlignment = NSTextAlignmentCenter;
    icon.tag = 201;
    [bg addSubview:icon];

    self.searchInput = [UITextField new];
    self.searchInput.font = [[WKApp shared].config appFontOfSize:15.0f];
    self.searchInput.textColor = [WKApp shared].config.defaultTextColor;
    self.searchInput.placeholder = self.searchPlaceholder ?: LLang(@"搜索");
    self.searchInput.returnKeyType = UIReturnKeySearch;
    self.searchInput.delegate = self;
    self.searchInput.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.searchInput addTarget:self action:@selector(onInputChanged) forControlEvents:UIControlEventEditingChanged];
    [bg addSubview:self.searchInput];
}

- (void)setupTable {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.rowHeight = kPickerRowH;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.tableView];

    self.bottomBar = [UIView new];
    self.bottomBar.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    [self.view addSubview:self.bottomBar];

    self.applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.applyBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
    self.applyBtn.backgroundColor = [WKApp shared].config.themeColor;
    self.applyBtn.layer.cornerRadius = 22.0f;
    [self.applyBtn addTarget:self action:@selector(onApply) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.applyBtn];
    [self refreshApplyTitle];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.lim_width;
    CGFloat top = self.view.safeAreaInsets.top;
    self.searchBarContainer.frame = CGRectMake(0, top, w, kPickerSearchBarH + 12.0f);
    UIView *bg = [self.searchBarContainer viewWithTag:200];
    bg.frame = CGRectMake(12, 6, w - 24, kPickerSearchBarH);
    UILabel *icon = [bg viewWithTag:201];
    icon.frame = CGRectMake(8, 0, 24, kPickerSearchBarH);
    self.searchInput.frame = CGRectMake(CGRectGetMaxX(icon.frame), 0, bg.lim_width - CGRectGetMaxX(icon.frame) - 8, kPickerSearchBarH);

    CGFloat barH = 64.0f;
    CGFloat safe = self.view.safeAreaInsets.bottom;
    CGFloat barY = self.view.lim_height - safe - barH;
    self.tableView.frame = CGRectMake(0, self.searchBarContainer.lim_bottom, w, barY - self.searchBarContainer.lim_bottom);
    self.bottomBar.frame = CGRectMake(0, barY, w, barH + safe);
    self.applyBtn.frame = CGRectMake(16, 10, w - 32, 44);
}

#pragma mark - search

- (void)onInputChanged {
    if (self.searchInput.markedTextRange != nil) return;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scheduledSearch) object:nil];
    [self performSelector:@selector(scheduledSearch) withObject:nil afterDelay:kPickerSearchDebounceMs / 1000.0];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scheduledSearch) object:nil];
    [self scheduledSearch];
    return YES;
}

- (void)scheduledSearch { [self runSearch:self.searchInput.text ?: @""]; }

- (void)runSearch:(NSString *)keyword {
    if (!self.candidateProvider) return;
    __weak typeof(self) ws = self;
    NSString *kw = keyword;
    self.candidateProvider(keyword, ^(NSArray<WKGlobalSearchPickEntry *> *entries) {
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        // 只接受最新一次输入的回包
        if (![(ss.searchInput.text ?: @"") isEqualToString:kw]) return;
        ss.candidates = entries ?: @[];
        for (WKGlobalSearchPickEntry *e in ss.candidates) {
            if (e.identifier.length > 0 && !ss.entryById[e.identifier]) ss.entryById[e.identifier] = e;
        }
        [ss.tableView reloadData];
    });
}

#pragma mark - table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.candidates.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *rid = @"pickerRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    WKUserAvatar *avatar;
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
        cell.textLabel.font = [[WKApp shared].config appFontOfSize:15.0f];
        cell.textLabel.textColor = [WKApp shared].config.defaultTextColor;
        avatar = [[WKUserAvatar alloc] initWithFrame:CGRectMake(16, 10, 36, 36)];
        avatar.tag = 301;
        [cell.contentView addSubview:avatar];
    } else {
        avatar = [cell.contentView viewWithTag:301];
    }
    avatar.frame = CGRectMake(16, (kPickerRowH - 36) / 2.0f, 36, 36);
    WKGlobalSearchPickEntry *e = self.candidates[indexPath.row];
    avatar.url = e.avatarUrl;
    cell.textLabel.text = e.name.length > 0 ? e.name : e.identifier;
    cell.indentationLevel = 4; // 给头像让位
    cell.indentationWidth = 16.0f;
    BOOL selected = [self.selectedIds containsObject:e.identifier];
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.tintColor = [WKApp shared].config.themeColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WKGlobalSearchPickEntry *e = self.candidates[indexPath.row];
    if (e.identifier.length == 0) return;
    if ([self.selectedIds containsObject:e.identifier]) {
        [self.selectedIds removeObject:e.identifier];
    } else {
        [self.selectedIds addObject:e.identifier];
        self.entryById[e.identifier] = e;
    }
    [self refreshApplyTitle];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)refreshApplyTitle {
    NSString *base = LLang(@"完成");
    NSString *title = self.selectedIds.count > 0 ? [NSString stringWithFormat:@"%@ (%ld)", base, (long)self.selectedIds.count] : base;
    [self.applyBtn setTitle:title forState:UIControlStateNormal];
}

- (void)onApply {
    NSMutableArray<WKGlobalSearchPickEntry *> *result = [NSMutableArray array];
    for (NSString *uid in self.selectedIds) {
        WKGlobalSearchPickEntry *e = self.entryById[uid];
        if (e) [result addObject:e];
        else [result addObject:[WKGlobalSearchPickEntry entryWithId:uid name:uid avatarUrl:nil channelType:0]];
    }
    if (self.onFinish) self.onFinish(result);
    if (self.navigationController) [self.navigationController popViewControllerAnimated:YES];
    else [self dismissViewControllerAnimated:YES completion:nil];
}

@end
