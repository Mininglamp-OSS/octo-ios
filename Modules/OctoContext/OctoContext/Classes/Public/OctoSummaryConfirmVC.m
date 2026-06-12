//
//  OctoSummaryConfirmVC.m
//  OctoContext
//

#import "OctoSummaryConfirmVC.h"
#import "OctoSummaryAPI.h"

@interface OctoSummaryConfirmVC () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSMutableSet<NSString *> *checkedSourceKeys;
@end

@implementation OctoSummaryConfirmVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationBar.title = LLang(@"参与确认");

    self.checkedSourceKeys = [NSMutableSet set];
    for (OctoSourceItem *s in self.detail.sources) {
        [self.checkedSourceKeys addObject:[NSString stringWithFormat:@"%ld:%@", (long)s.sourceType, s.sourceId]];
    }

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
    [self.view addSubview:self.tableView];

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 80)];
    UIButton *confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [confirmBtn setTitle:LLang(@"确认参与") forState:UIControlStateNormal];
    [confirmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    confirmBtn.backgroundColor = [UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:1.0];
    confirmBtn.layer.cornerRadius = 22;
    confirmBtn.frame = CGRectMake(16, 16, self.view.bounds.size.width - 32, 44);
    confirmBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [confirmBtn addTarget:self action:@selector(onConfirm) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:confirmBtn];
    self.tableView.tableFooterView = footer;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = CGRectGetMaxY(self.navigationBar.frame);
    self.tableView.frame = CGRectMake(0, top,
                                      self.view.bounds.size.width,
                                      self.view.bounds.size.height - top);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.detail.participants.count;
    return self.detail.sources.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? LLang(@"参与者") : LLang(@"来源");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    if (indexPath.section == 0) {
        OctoParticipant *p = self.detail.participants[indexPath.row];
        cell.textLabel.text = p.userName ?: p.userId;
        NSString *st = @"";
        switch (p.status) {
            case OctoParticipantConfirmed: st = LLang(@"已确认"); break;
            case OctoParticipantDeclined:  st = LLang(@"已拒绝"); break;
            default: st = LLang(@"等待中"); break;
        }
        cell.detailTextLabel.text = st;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        OctoSourceItem *s = self.detail.sources[indexPath.row];
        cell.textLabel.text = s.sourceName ?: s.sourceId;
        NSString *key = [NSString stringWithFormat:@"%ld:%@", (long)s.sourceType, s.sourceId];
        cell.accessoryType = [self.checkedSourceKeys containsObject:key]
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1) return;
    OctoSourceItem *s = self.detail.sources[indexPath.row];
    NSString *key = [NSString stringWithFormat:@"%ld:%@", (long)s.sourceType, s.sourceId];
    if ([self.checkedSourceKeys containsObject:key]) [self.checkedSourceKeys removeObject:key];
    else [self.checkedSourceKeys addObject:key];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)onConfirm {
    NSMutableArray<OctoSourceItem *> *picked = [NSMutableArray array];
    for (OctoSourceItem *s in self.detail.sources) {
        NSString *key = [NSString stringWithFormat:@"%ld:%@", (long)s.sourceType, s.sourceId];
        if ([self.checkedSourceKeys containsObject:key]) [picked addObject:s];
    }
    if (picked.count == 0) {
        [self.view showHUDWithHide:LLang(@"请至少选一个来源")];
        return;
    }
    [[OctoSummaryAPI shared] confirmParticipation:self.detail.taskId sources:picked
        callback:^(id _Nullable result, NSError * _Nullable error) {
            if (error) { [self.view showHUDWithHide:LLang(@"提交失败")]; return; }
            [self.view showHUDWithHide:LLang(@"已确认参与")];
            [self.navigationController popViewControllerAnimated:YES];
        }];
}

@end
