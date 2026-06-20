//
//  WKChannelWebhookVC.m
//  WuKongBase
//

#import "WKChannelWebhookVC.h"
#import "WuKongBase.h"
#import "WKChannelWebhookCell.h"
#import "WKChannelWebhookEditVC.h"
#import "WKChannelWebhookUrlVC.h"
#import "WKIncomingWebhook.h"
#import "WKIncomingWebhookManager.h"
#import "WKFloatingMenu.h"
#import "WKActionSheetView2.h"
#import "WKActionSheetItem2.h"

static NSString * const kWebhookCellId = @"WKChannelWebhookCell";

@interface WKChannelWebhookVC ()<UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>

@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) UIView *headerDescView;
@property(nonatomic,strong) UIView *emptyView;
@property(nonatomic,strong) UIButton *addBtn;
@property(nonatomic,strong) UILongPressGestureRecognizer *longPress;

@property(nonatomic,strong) NSMutableArray<WKIncomingWebhook *> *items;
// 单条切换启停 in-flight 的 webhookId 集合 —— UI 上 Switch 转 loading 态
@property(nonatomic,strong) NSMutableSet<NSString *> *togglingIds;
// 是否已发起首次加载（避免 viewWillAppear 时重复刷新带来的闪烁）
@property(nonatomic,assign) BOOL hasLoaded;

@end

@implementation WKChannelWebhookVC

- (NSString *)langTitle {
    return LLang(@"群消息推送");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.items = [NSMutableArray array];
    self.togglingIds = [NSMutableSet set];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.title = LLang(@"群消息推送");

    [self.view addSubview:self.tableView];
    [self.view addSubview:self.emptyView];

    // 右上 + 按钮：列表非空才展示（与 web 一致；空态把 CTA 放在内容区中央）。
    self.rightView = self.addBtn;
    self.addBtn.hidden = YES;

    [self attachLongPress];

    [self loadList:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [WKFloatingMenu dismiss];
}

#pragma mark - Subviews

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:[self visibleRect] style:UITableViewStyleGrouped];
        _tableView.backgroundColor = [WKApp shared].config.backgroundColor;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        [_tableView registerClass:WKChannelWebhookCell.class forCellReuseIdentifier:kWebhookCellId];
        _tableView.tableHeaderView = self.headerDescView;
    }
    return _tableView;
}

- (UIView *)headerDescView {
    if (!_headerDescView) {
        // 顶部说明（与 web `ChannelWebhookPanel` 的 description 文案一致）。
        // 用 sizeToFit 让文字自动换行，wrapper 高度跟着 label 实际占用走 ——
        // 之前用了固定 36pt label + 56pt wrapper，文字会被截。
        CGFloat W = self.view.lim_width;
        UILabel *desc = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, W - 32, 0)];
        desc.font = [[WKApp shared].config appFontOfSize:13.0f];
        desc.textColor = [WKApp shared].config.tipColor;
        desc.numberOfLines = 0;
        desc.text = LLang(@"通过 Webhook 把外部系统的消息（CI 通知、监控告警、GitHub 事件等）推送到本群。");
        [desc sizeToFit];
        desc.lim_width = W - 32;
        // 重新算高度
        CGSize fit = [desc sizeThatFits:CGSizeMake(W - 32, CGFLOAT_MAX)];
        desc.lim_height = fit.height;

        UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, fit.height + 20)];
        wrap.backgroundColor = [UIColor clearColor];
        [wrap addSubview:desc];
        _headerDescView = wrap;
    }
    return _headerDescView;
}

- (UIView *)emptyView {
    if (!_emptyView) {
        // 空态：链接图标 + 文案 + 实心新建按钮。logo 用专门的 80×80 矢量绘制版本，
        // 不要复用 32×32 cell 头像那张 50×50 raster 占位图 —— 那图放大会模糊。
        CGRect vr = [self visibleRect];
        _emptyView = [[UIView alloc] initWithFrame:vr];
        _emptyView.hidden = YES;
        _emptyView.backgroundColor = [UIColor clearColor];

        CGFloat iconSize = 88.0f;
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[WKChannelWebhookVC emptyStateIconWithSize:iconSize]];
        iconView.frame = CGRectMake((vr.size.width - iconSize) / 2.0f, vr.size.height * 0.24f, iconSize, iconSize);
        [_emptyView addSubview:iconView];

        UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(20,
                                                                  CGRectGetMaxY(iconView.frame) + 16,
                                                                  vr.size.width - 40, 0)];
        tip.font = [[WKApp shared].config appFontOfSize:15.0f];
        tip.textColor = [WKApp shared].config.tipColor;
        tip.textAlignment = NSTextAlignmentCenter;
        tip.text = LLang(@"暂无 Webhook，新建后可推送外部消息到本群");
        tip.numberOfLines = 0;
        CGSize fit = [tip sizeThatFits:CGSizeMake(vr.size.width - 40, CGFLOAT_MAX)];
        tip.lim_height = fit.height;
        [_emptyView addSubview:tip];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake((vr.size.width - 160) / 2.0f, CGRectGetMaxY(tip.frame) + 24, 160, 40);
        btn.backgroundColor = [WKApp shared].config.themeColor;
        [btn setTitle:LLang(@"新建 Webhook") forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [[WKApp shared].config appFontOfSize:15.0f];
        btn.layer.cornerRadius = 20;
        btn.layer.masksToBounds = YES;
        [btn addTarget:self action:@selector(onAddPressed) forControlEvents:UIControlEventTouchUpInside];
        [_emptyView addSubview:btn];
    }
    return _emptyView;
}

// 空态专用大图标：圆角矩形浅灰底 + 居中链接（两个圆环 + 中间连接段），
// 在指定 size 下原生绘制，避免缩放模糊。UIBezierPath 自带 lineWidth=1，
// 不继承 CGContextSetLineWidth；所有 stroke 属性必须显式设到 path 上。
+ (UIImage *)emptyStateIconWithSize:(CGFloat)size {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);

    // 圆角矩形底
    UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:size * 0.22f];
    [[UIColor colorWithRed:0xEE/255.0 green:0xF1/255.0 blue:0xF6/255.0 alpha:1.0] setFill];
    [bg fill];

    // 链接图形：以 80×80 为参考画，等比缩放
    CGFloat k = size / 80.0f;
    CGFloat lineW = 4.5f * k;
    UIColor *stroke = [UIColor colorWithRed:0x7A/255.0 green:0x82/255.0 blue:0x99/255.0 alpha:1.0];
    [stroke setStroke];

    CGFloat cx = size / 2.0f;
    CGFloat cy = size / 2.0f;
    CGFloat ringR = 11 * k;
    CGFloat off = 8 * k;
    CGFloat tilt = -M_PI_4; // 链子沿 -45° 倾斜

    // 计算左右环中心（相对画布中心、按 tilt 旋转 off 单位）
    CGFloat dx = off * cos(tilt);
    CGFloat dy = off * sin(tilt);

    // 左环：开口朝右下；右环：开口朝左上。开口角度大约 60°。
    CGFloat half = M_PI / 3.0f; // 60°
    UIBezierPath *leftRing = [UIBezierPath bezierPath];
    leftRing.lineWidth = lineW;
    leftRing.lineCapStyle = kCGLineCapRound;
    [leftRing addArcWithCenter:CGPointMake(cx - dx, cy - dy)
                        radius:ringR
                    startAngle:tilt + half
                      endAngle:tilt - half + 2 * M_PI
                     clockwise:YES];
    [leftRing stroke];

    UIBezierPath *rightRing = [UIBezierPath bezierPath];
    rightRing.lineWidth = lineW;
    rightRing.lineCapStyle = kCGLineCapRound;
    [rightRing addArcWithCenter:CGPointMake(cx + dx, cy + dy)
                         radius:ringR
                     startAngle:tilt + M_PI + half
                       endAngle:tilt + M_PI - half + 2 * M_PI
                      clockwise:YES];
    [rightRing stroke];

    // 中间连接段：从左环靠右一点到右环靠左一点
    UIBezierPath *bar = [UIBezierPath bezierPath];
    bar.lineWidth = lineW;
    bar.lineCapStyle = kCGLineCapRound;
    CGFloat barLen = ringR * 1.1f;
    [bar moveToPoint:CGPointMake(cx - barLen * cos(tilt), cy - barLen * sin(tilt))];
    [bar addLineToPoint:CGPointMake(cx + barLen * cos(tilt), cy + barLen * sin(tilt))];
    [bar stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIButton *)addBtn {
    if (!_addBtn) {
        _addBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60.0f, 30.0f)];
        [_addBtn setTitle:LLang(@"新建") forState:UIControlStateNormal];
        [_addBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _addBtn.backgroundColor = [WKApp shared].config.themeColor;
        _addBtn.titleLabel.font = [[WKApp shared].config appFontOfSize:14.0f];
        _addBtn.layer.cornerRadius = 4.0f;
        _addBtn.layer.masksToBounds = YES;
        [_addBtn addTarget:self action:@selector(onAddPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _addBtn;
}

- (void)attachLongPress {
    _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onTableLongPress:)];
    _longPress.minimumPressDuration = 0.4;
    _longPress.delegate = self;
    [self.tableView addGestureRecognizer:_longPress];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // 不抢 tableView 自带的点击与滚动，长按手势独立工作即可。
    return YES;
}

#pragma mark - Load

- (void)loadList:(BOOL)showHud {
    if (self.channel.channelId.length == 0) return;
    MBProgressHUD *hud = nil;
    if (showHud && !self.hasLoaded) {
        hud = [self.view showHUD];
    }
    __weak typeof(self) weakSelf = self;
    [[WKIncomingWebhookManager shared] listWebhooksOfGroup:self.channel.channelId complete:^(NSArray<WKIncomingWebhook *> *items, NSError * _Nullable error) {
        if (hud) [hud hideAnimated:YES];
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;
        self_.hasLoaded = YES;
        if (error) {
            // 首次加载失败仅 toast，列表保留旧状态（如果有）。
            [self_.view showMsg:error.domain.length > 0 ? error.domain : LLang(@"加载失败")];
            return;
        }
        [self_.items removeAllObjects];
        [self_.items addObjectsFromArray:items];
        [self_ refreshUIAfterLoad];
        [self_ writeBackCountToChannelInfo:items.count];
    }];
}

- (void)refreshUIAfterLoad {
    BOOL empty = self.items.count == 0;
    self.emptyView.hidden = !empty;
    self.tableView.hidden = empty;
    self.addBtn.hidden = empty; // 列表非空才显示右上 +；空态用居中 CTA
    [self.tableView reloadData];
}

// 把 webhook 数量写回 channelInfo.extra，给群信息页副标题用（参考 GROUP.md 的做法）。
- (void)writeBackCountToChannelInfo:(NSInteger)count {
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:self.channel];
    if (!info) return;
    NSNumber *prev = info.extra[@"incoming_webhook_count"];
    if (prev && prev.integerValue == count) return;
    info.extra[@"incoming_webhook_count"] = @(count);
    [[WKSDK shared].channelManager updateChannelInfo:info];
}

#pragma mark - Actions: add / edit

- (void)onAddPressed {
    [self pushEditVCForWebhook:nil];
}

- (void)pushEditVCForWebhook:(WKIncomingWebhook * _Nullable)webhook {
    WKChannelWebhookEditVC *vc = [WKChannelWebhookEditVC new];
    vc.channel = self.channel;
    vc.editingWebhook = webhook;
    vc.isManagerOrCreator = self.isManagerOrCreator;
    __weak typeof(self) weakSelf = self;
    vc.onCreated = ^(WKIncomingWebhook *created) {
        // Pop 动画占用 ~0.3s，期间 list VC 还没真正成为 topmost，直接 present 会
        // 让 URL 弹窗夹在 pop 动画里。延一帧到下一拍再弹，避免 UI 错位。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf presentUrlVCFor:created];
        });
        [weakSelf loadList:NO];
    };
    vc.onUpdated = ^{
        [weakSelf loadList:NO];
    };
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
}

- (void)presentUrlVCFor:(WKIncomingWebhook *)webhook {
    WKChannelWebhookUrlVC *vc = [WKChannelWebhookUrlVC new];
    vc.webhook = webhook;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - DataSource / Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [WKChannelWebhookCell cellHeight];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return CGFLOAT_MIN; }
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section { return 10.0f; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKChannelWebhookCell *cell = [tableView dequeueReusableCellWithIdentifier:kWebhookCellId];
    WKIncomingWebhook *item = self.items[indexPath.row];
    BOOL canManage = [item canManageByCurrentUser:self.isManagerOrCreator] && (
        self.isManagerOrCreator || [item.creatorUid isEqualToString:[WKApp shared].loginInfo.uid]);
    BOOL loading = [self.togglingIds containsObject:item.webhookId];
    NSString *creator = [self displayNameForUid:item.creatorUid];
    [cell refreshWithWebhook:item creatorDisplayName:creator canManage:canManage switchLoading:loading];

    __weak typeof(self) weakSelf = self;
    cell.onSwitchToggle = ^(BOOL nextOn) {
        [weakSelf toggleWebhook:item to:nextOn];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.items.count) return;
    WKIncomingWebhook *item = self.items[indexPath.row];
    // 单击直接打开编辑 —— 让"编辑"成为最主路径；长按只承担破坏性 / 不常用动作。
    // 无权限者点击无效（编辑接口会被服务端 403），保留长按"复制名称"兜底。
    if ([self canManageWebhook:item]) {
        [self pushEditVCForWebhook:item];
    }
}

#pragma mark - 创建者展示名

- (NSString *)displayNameForUid:(NSString *)uid {
    if (uid.length == 0) return @"";
    if ([uid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return [WKApp shared].loginInfo.displayName ?: LLang(@"我");
    }
    WKChannelMember *member = [[WKSDK shared].channelManager getMember:self.channel uid:uid];
    if (member.memberRemark.length > 0) return member.memberRemark;
    if (member.memberName.length > 0) return member.memberName;
    return @"";
}

#pragma mark - 启停切换（直接打 PUT，不走二次确认）

- (void)toggleWebhook:(WKIncomingWebhook *)webhook to:(BOOL)nextOn {
    if (webhook.webhookId.length == 0) return;
    [self.togglingIds addObject:webhook.webhookId];
    [self.tableView reloadData];

    NSInteger nextStatus = nextOn ? WKIncomingWebhookStatusEnabled : WKIncomingWebhookStatusDisabled;
    __weak typeof(self) weakSelf = self;
    [[WKIncomingWebhookManager shared] updateWebhook:webhook.webhookId
                                              ofGroup:self.channel.channelId
                                                 name:nil
                                               avatar:nil
                                               status:@(nextStatus)
                                             complete:^(NSError * _Nullable error) {
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;
        [self_.togglingIds removeObject:webhook.webhookId];
        if (error) {
            [self_.view showMsg:error.domain.length > 0 ? error.domain : LLang(@"操作失败")];
            // 失败也要刷新一次，把 Switch 拉回原状态
            [self_.tableView reloadData];
            return;
        }
        // 成功后乐观更新本地数据；继续刷一次后台保证 last_used_at 等其它字段一致。
        webhook.status = nextStatus;
        [self_.tableView reloadData];
    }];
}

#pragma mark - 长按弹 WKFloatingMenu

- (void)onTableLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateBegan) return;
    CGPoint pt = [gr locationInView:self.tableView];
    NSIndexPath *idx = [self.tableView indexPathForRowAtPoint:pt];
    if (!idx || idx.row >= (NSInteger)self.items.count) return;
    WKIncomingWebhook *item = self.items[idx.row];

    BOOL canManage = [self canManageWebhook:item];
    NSMutableArray<NSDictionary *> *menu = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    if (canManage) {
        BOOL enabled = item.status == WKIncomingWebhookStatusEnabled;
        BOOL onCooldown = [[WKIncomingWebhookManager shared] isWebhookOnTestCooldown:item.webhookId];
        BOOL anyInFlight = [WKIncomingWebhookManager shared].hasTestInFlight;

        // 「编辑」与「启用/禁用」已分别下放给单击 cell 与 cell 右侧 Switch，
        // 菜单只承担相对低频 / 破坏性的动作，避免菜单堆 5 项导致主路径被淹。

        // 测试发送（仅 enabled 才出现；冷却中文案变化但仍可见，置灰由 action 内部守卫）
        if (enabled) {
            NSString *title = onCooldown ? LLang(@"测试发送（冷却中）") : LLang(@"测试发送");
            [menu addObject:@{
                @"title": title,
                @"icon": [WKChannelWebhookVC iconTest],
                @"action": ^{
                    if (anyInFlight || [[WKIncomingWebhookManager shared] isWebhookOnTestCooldown:item.webhookId]) {
                        [weakSelf.view showMsg:LLang(@"请稍候再试")];
                        return;
                    }
                    [weakSelf testWebhook:item];
                }
            }];
        }

        // 重置 token —— destructive 二次确认
        [menu addObject:@{
            @"title": LLang(@"重置 Token"),
            @"icon": [WKChannelWebhookVC iconRegenerate],
            @"action": ^{ [weakSelf confirmRegenerate:item]; }
        }];

        // 删除 —— destructive 二次确认
        [menu addObject:@{
            @"title": LLang(@"删除"),
            @"icon": [WKChannelWebhookVC iconDelete],
            @"isDestructive": @YES,
            @"action": ^{ [weakSelf confirmDelete:item]; }
        }];
    } else {
        // 无权限：仅给一个"复制名称"，避免长按啥都没有的迷惑感
        [menu addObject:@{
            @"title": LLang(@"复制名称"),
            @"icon": [WKChannelWebhookVC iconCopy],
            @"action": ^{
                [UIPasteboard generalPasteboard].string = item.name ?: @"";
                [weakSelf.view showMsg:LLang(@"已复制")];
            }
        }];
    }

    // 锚点：cell 中心，转 window 坐标
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:idx];
    CGPoint anchor;
    if (cell) {
        CGPoint center = CGPointMake(CGRectGetMidX(cell.bounds), CGRectGetMidY(cell.bounds));
        anchor = [cell.superview convertPoint:center toView:nil];
    } else {
        anchor = [self.tableView convertPoint:pt toView:nil];
    }
    [WKFloatingMenu showItems:menu atPoint:anchor];
}

- (BOOL)canManageWebhook:(WKIncomingWebhook *)item {
    if (self.isManagerOrCreator) return YES;
    NSString *me = [WKApp shared].loginInfo.uid;
    return me.length > 0 && [item.creatorUid isEqualToString:me];
}

#pragma mark - 测试 / 重置 / 删除

- (void)testWebhook:(WKIncomingWebhook *)item {
    [self.view showHUD];
    __weak typeof(self) weakSelf = self;
    [[WKIncomingWebhookManager shared] testWebhook:item.webhookId
                                            ofGroup:self.channel.channelId
                                           complete:^(BOOL sent, NSError * _Nullable error) {
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;
        [self_.view hideHud];
        if (!sent) {
            // 命中守卫（已冷却 / 在飞）；UI 已经给了"冷却中"文案，这里再 toast 兜底
            if (error) {
                [self_.view showMsg:error.domain.length > 0 ? error.domain : LLang(@"测试失败")];
            }
            return;
        }
        [self_.view showMsg:LLang(@"已发送测试消息")];
    }];
}

- (void)confirmRegenerate:(WKIncomingWebhook *)item {
    NSString *tip = [NSString stringWithFormat:LLang(@"重置后旧地址将立即失效，确定要重置「%@」的 Token 吗？"), item.name ?: @""];
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:tip cancel:LLang(@"取消")];
    __weak typeof(self) weakSelf = self;
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"重置 Token") onClick:^{
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;
        [self_.view showHUD];
        [[WKIncomingWebhookManager shared] regenerateWebhook:item.webhookId
                                                       ofGroup:self_.channel.channelId
                                                      complete:^(WKIncomingWebhook * _Nullable webhook, NSError * _Nullable error) {
            [self_.view hideHud];
            if (error) {
                [self_.view showMsg:error.domain.length > 0 ? error.domain : LLang(@"重置失败")];
                return;
            }
            // 把新地址（token 仅此一次）弹出来给用户复制
            if (webhook) [self_ presentUrlVCFor:webhook];
            [self_ loadList:NO];
        }];
    }]];
    [sheet show];
}

- (void)confirmDelete:(WKIncomingWebhook *)item {
    NSString *tip = [NSString stringWithFormat:LLang(@"确定要删除「%@」吗？删除后该地址将立即失效。"), item.name ?: @""];
    WKActionSheetView2 *sheet = [WKActionSheetView2 initWithTip:tip cancel:LLang(@"取消")];
    __weak typeof(self) weakSelf = self;
    [sheet addItem:[WKActionSheetButtonItem2 initWithAlertTitle:LLang(@"删除") onClick:^{
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) return;
        [self_.view showHUD];
        [[WKIncomingWebhookManager shared] deleteWebhook:item.webhookId
                                                   ofGroup:self_.channel.channelId
                                                  complete:^(NSError * _Nullable error) {
            [self_.view hideHud];
            if (error) {
                [self_.view showMsg:error.domain.length > 0 ? error.domain : LLang(@"删除失败")];
                return;
            }
            [self_.view showMsg:LLang(@"已删除")];
            [self_ loadList:NO];
        }];
    }]];
    [sheet show];
}

#pragma mark - 程序化绘制图标（与 WKFloatingMenu 自带图标统一风格：20pt 单色线条）

+ (UIImage *)templateIcon:(void(^)(CGContextRef ctx))drawer {
    CGSize s = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithWhite:0.3 alpha:1] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    if (drawer) drawer(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconEdit {
    return [self templateIcon:^(CGContextRef ctx) {
        // 铅笔
        CGContextMoveToPoint(ctx, 13, 4);
        CGContextAddLineToPoint(ctx, 16, 7);
        CGContextAddLineToPoint(ctx, 8, 15);
        CGContextAddLineToPoint(ctx, 4, 16);
        CGContextAddLineToPoint(ctx, 5, 12);
        CGContextClosePath(ctx);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 5, 12);
        CGContextAddLineToPoint(ctx, 8, 15);
        CGContextStrokePath(ctx);
    }];
}

+ (UIImage *)iconTest {
    return [self templateIcon:^(CGContextRef ctx) {
        // 纸飞机
        CGContextMoveToPoint(ctx, 17, 3);
        CGContextAddLineToPoint(ctx, 3, 10);
        CGContextAddLineToPoint(ctx, 9, 12);
        CGContextAddLineToPoint(ctx, 11, 17);
        CGContextAddLineToPoint(ctx, 17, 3);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 9, 12);
        CGContextAddLineToPoint(ctx, 17, 3);
        CGContextStrokePath(ctx);
    }];
}

+ (UIImage *)iconDisable {
    return [self templateIcon:^(CGContextRef ctx) {
        // 圆形 + 斜杠（禁用）
        CGContextAddArc(ctx, 10, 10, 6.5, 0, 2 * M_PI, 0);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 5.5, 14.5);
        CGContextAddLineToPoint(ctx, 14.5, 5.5);
        CGContextStrokePath(ctx);
    }];
}

+ (UIImage *)iconEnable {
    return [self templateIcon:^(CGContextRef ctx) {
        // 圆形 + 对勾（启用）
        CGContextAddArc(ctx, 10, 10, 6.5, 0, 2 * M_PI, 0);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 6.5, 10);
        CGContextAddLineToPoint(ctx, 9, 12.5);
        CGContextAddLineToPoint(ctx, 13.5, 7.5);
        CGContextStrokePath(ctx);
    }];
}

+ (UIImage *)iconRegenerate {
    return [self templateIcon:^(CGContextRef ctx) {
        // 循环刷新箭头
        CGContextAddArc(ctx, 10, 10, 6, M_PI_2 + 0.3, M_PI_2 + 2 * M_PI - 0.3, 0);
        CGContextStrokePath(ctx);
        // 箭头头
        CGContextMoveToPoint(ctx, 13.0, 4.5);
        CGContextAddLineToPoint(ctx, 15.5, 6.0);
        CGContextAddLineToPoint(ctx, 13.0, 7.5);
        CGContextStrokePath(ctx);
    }];
}

+ (UIImage *)iconDelete {
    return [self templateIcon:^(CGContextRef ctx) {
        // 垃圾桶
        CGContextMoveToPoint(ctx, 5, 6);
        CGContextAddLineToPoint(ctx, 15, 6);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 6.5, 6);
        CGContextAddLineToPoint(ctx, 7.5, 16);
        CGContextAddLineToPoint(ctx, 12.5, 16);
        CGContextAddLineToPoint(ctx, 13.5, 6);
        CGContextStrokePath(ctx);
        CGContextMoveToPoint(ctx, 8, 6);
        CGContextAddLineToPoint(ctx, 8, 4);
        CGContextAddLineToPoint(ctx, 12, 4);
        CGContextAddLineToPoint(ctx, 12, 6);
        CGContextStrokePath(ctx);
    }];
}

+ (UIImage *)iconCopy {
    return [self templateIcon:^(CGContextRef ctx) {
        // 两叠卡片
        CGContextStrokeRect(ctx, CGRectMake(4, 4, 9, 11));
        CGContextStrokeRect(ctx, CGRectMake(7, 7, 9, 11));
    }];
}

@end
