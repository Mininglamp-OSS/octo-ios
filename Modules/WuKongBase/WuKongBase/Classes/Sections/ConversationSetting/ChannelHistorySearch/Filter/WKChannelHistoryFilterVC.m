//
//  WKChannelHistoryFilterVC.m
//

#import "WKChannelHistoryFilterVC.h"
#import "WKChannelHistorySenderPickerVC.h"
#import "WKApp.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKGroupManager.h"

#define kRowHeight 52.0f

@interface WKChannelHistoryFilterVC () <
    UITableViewDataSource, UITableViewDelegate,
    WKChannelHistorySenderPickerVCDelegate
>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *resetBtn;
@property (nonatomic, strong) UIButton *applyBtn;

/// 已加载的发送人简要展示文本缓存（避免每次 cellForRow 都查 channel manager）。
@property (nonatomic, copy) NSString *senderSummaryText;

@end

@implementation WKChannelHistoryFilterVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.title = LLang(@"筛选");
    if (!self.draft) self.draft = [WKChannelHistorySearchFilter new];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(onCancel)];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = kRowHeight;
    self.tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    [self.view addSubview:self.tableView];

    self.bottomBar = [UIView new];
    self.bottomBar.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    [self.view addSubview:self.bottomBar];

    self.resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetBtn setTitle:LLang(@"重置") forState:UIControlStateNormal];
    [self.resetBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    self.resetBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
    self.resetBtn.layer.borderWidth = 0.5f;
    self.resetBtn.layer.borderColor = [[UIColor grayColor] colorWithAlphaComponent:0.3].CGColor;
    self.resetBtn.layer.cornerRadius = 22.0f;
    [self.resetBtn addTarget:self action:@selector(onReset) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.resetBtn];

    self.applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.applyBtn setTitle:LLang(@"应用") forState:UIControlStateNormal];
    [self.applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.applyBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:16.0f];
    self.applyBtn.backgroundColor = [WKApp shared].config.themeColor;
    self.applyBtn.layer.cornerRadius = 22.0f;
    [self.applyBtn addTarget:self action:@selector(onApply) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.applyBtn];

    [self refreshSenderSummary];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat barH = 64.0f;
    CGFloat safe = self.view.safeAreaInsets.bottom;
    CGFloat barY = self.view.lim_height - safe - barH;
    self.tableView.frame = CGRectMake(0, 0, self.view.lim_width, barY);
    self.bottomBar.frame = CGRectMake(0, barY, self.view.lim_width, barH + safe);
    CGFloat btnW = (self.view.lim_width - 16 * 3) / 2.0f;
    self.resetBtn.frame = CGRectMake(16, 10, btnW, 44);
    self.applyBtn.frame = CGRectMake(self.view.lim_width - 16 - btnW, 10, btnW, 44);
}

#pragma mark - sender summary

- (void)refreshSenderSummary {
    NSArray<NSString *> *uids = self.draft.senderUids ?: @[];
    if (uids.count == 0) {
        self.senderSummaryText = LLang(@"全部成员");
        return;
    }
    // 简单显示数量；多人时不在此 fetch 头像名，避免拖慢
    self.senderSummaryText = [NSString stringWithFormat:LLang(@"已选 %ld 人"), (long)uids.count];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1; // sender
    if (section == 1) return 3; // start date / end date / preset
    return 2; // sort: desc / asc
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 32.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *v = [UIView new];
    v.backgroundColor = [WKApp shared].config.backgroundColor;
    UILabel *t = [UILabel new];
    t.frame = CGRectMake(16, 8, 300, 22);
    t.font = [[WKApp shared].config appFontOfSize:13.0f];
    t.textColor = [UIColor grayColor];
    if (section == 0) t.text = LLang(@"发送人");
    else if (section == 1) t.text = LLang(@"日期范围");
    else t.text = LLang(@"排序");
    [v addSubview:t];
    return v;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"row"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.font = [[WKApp shared].config appFontOfSize:15.0f];
    cell.textLabel.textColor = [WKApp shared].config.defaultTextColor;
    cell.detailTextLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
    cell.detailTextLabel.textColor = [UIColor grayColor];

    static NSDateFormatter *dateFmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dateFmt = [NSDateFormatter new];
        dateFmt.dateFormat = @"yyyy/MM/dd";
    });

    if (indexPath.section == 0) {
        cell.textLabel.text = LLang(@"选择发送人");
        cell.detailTextLabel.text = self.senderSummaryText;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = LLang(@"起始日期");
            cell.detailTextLabel.text = self.draft.startDate ? [dateFmt stringFromDate:self.draft.startDate] : LLang(@"不限");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = LLang(@"结束日期");
            cell.detailTextLabel.text = self.draft.endDate ? [dateFmt stringFromDate:self.draft.endDate] : LLang(@"不限");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.textLabel.text = LLang(@"快速选择");
            cell.detailTextLabel.text = LLang(@"今天 / 7 天 / 30 天 / 全部");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        NSInteger curSort = self.draft.sort;
        BOOL selected = (indexPath.row == 0 && curSort == WKChannelHistorySearchSortTimeDesc)
                      || (indexPath.row == 1 && curSort == WKChannelHistorySearchSortTimeAsc);
        cell.textLabel.text = indexPath.row == 0 ? LLang(@"时间倒序（最新在前）") : LLang(@"时间正序（最早在前）");
        cell.detailTextLabel.text = selected ? @"✓" : @"";
        cell.detailTextLabel.textColor = [WKApp shared].config.themeColor;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        WKChannelHistorySenderPickerVC *p = [WKChannelHistorySenderPickerVC new];
        p.channel = self.channel;
        p.selectedUids = self.draft.senderUids ?: @[];
        p.delegate = self;
        [self.navigationController pushViewController:p animated:YES];
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) [self showDatePickerForStart:YES];
        else if (indexPath.row == 1) [self showDatePickerForStart:NO];
        else [self showPresetSheet];
    } else {
        self.draft.sort = (indexPath.row == 0)
            ? WKChannelHistorySearchSortTimeDesc
            : WKChannelHistorySearchSortTimeAsc;
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - date

- (void)showDatePickerForStart:(BOOL)isStart {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:isStart ? LLang(@"起始日期") : LLang(@"结束日期")
                                                                 message:@"\n\n\n\n\n\n\n\n\n"
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 30, ac.view.lim_width - 20, 200)];
    picker.datePickerMode = UIDatePickerModeDate;
    if (@available(iOS 14.0, *)) picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    NSDate *initial = isStart ? self.draft.startDate : self.draft.endDate;
    if (!initial) initial = [NSDate date];
    picker.date = initial;
    [ac.view addSubview:picker];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"清除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        if (isStart) self.draft.startDate = nil; else self.draft.endDate = nil;
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"确定") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        if (isStart) self.draft.startDate = picker.date; else self.draft.endDate = picker.date;
        // 守卫：开始 > 结束 时自动交换，避免请求体两个日期顺序倒挂导致服务端返回空。
        if (self.draft.startDate && self.draft.endDate
            && [self.draft.startDate compare:self.draft.endDate] == NSOrderedDescending) {
            NSDate *tmp = self.draft.startDate;
            self.draft.startDate = self.draft.endDate;
            self.draft.endDate = tmp;
        }
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    // iPad 上 actionSheet 走 popover, 必须有非 nil 的 sourceView + sourceRect。
    // 起/止日期两个日期入口都是从 filter 表格里的日期 cell 点触发, 直接锚到 self.view 中心。
    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = self.view;
        ac.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                 self.view.bounds.size.height / 2, 0, 0);
        ac.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)showPresetSheet {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:LLang(@"快速选择")
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    void(^apply)(NSInteger) = ^(NSInteger days) {
        NSDate *end = [NSDate date];
        NSDate *start = days > 0
            ? [end dateByAddingTimeInterval:-(days * 24 * 3600)]
            : nil;
        self.draft.startDate = start;
        self.draft.endDate = days > 0 ? end : nil;
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    };
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"今天") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { apply(1); }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"最近 7 天") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { apply(7); }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"最近 30 天") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { apply(30); }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"全部时间") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { apply(0); }]];
    [ac addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    if (ac.popoverPresentationController) {
        ac.popoverPresentationController.sourceView = self.view;
        ac.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2,
                                                                 self.view.bounds.size.height / 2, 0, 0);
        ac.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - sender picker delegate

- (void)senderPickerVC:(WKChannelHistorySenderPickerVC *)vc didFinishWithUids:(NSArray<NSString *> *)uids {
    self.draft.senderUids = uids;
    [self refreshSenderSummary];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - bottom

- (void)onReset {
    self.draft = [WKChannelHistorySearchFilter new];
    [self refreshSenderSummary];
    [self.tableView reloadData];
}

- (void)onApply {
    if ([self.delegate respondsToSelector:@selector(channelHistoryFilterVC:didApplyFilter:)]) {
        [self.delegate channelHistoryFilterVC:self didApplyFilter:self.draft];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)onCancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
