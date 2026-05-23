//
//  WKCategoryReorderVC.m
//  WuKongBase
//

#import "WKCategoryReorderVC.h"
#import "WKCategoryEntity.h"
#import "WKCategoryService.h"
#import "WKFollowedKeysStore.h"
#import "WKApp.h"
#import "UIView+WK.h"
#import "WuKongBase.h"

#pragma mark - Cell

@interface WKCategoryReorderCell : UITableViewCell
@property (nonatomic, strong) UILabel *indexLbl;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UIImageView *dragIcon;
@end

@implementation WKCategoryReorderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

        // 序号
        _indexLbl = [[UILabel alloc] init];
        _indexLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        _indexLbl.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _indexLbl.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_indexLbl];

        // 名称
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        [self.contentView addSubview:_nameLbl];

        // 拖拽手柄
        _dragIcon = [[UIImageView alloc] initWithImage:[WKCategoryReorderCell dragHandleImage]];
        _dragIcon.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_dragIcon];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.lim_height;
    CGFloat w = self.contentView.lim_width;
    _indexLbl.frame = CGRectMake(0, 0, 44, h);
    _nameLbl.frame = CGRectMake(44, 0, w - 44 - 50, h);
    _dragIcon.frame = CGRectMake(w - 40, (h - 20) / 2.0, 20, 20);
}

+ (UIImage *)dragHandleImage {
    CGSize size = CGSizeMake(20, 20);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;
    [[UIColor colorWithWhite:0.7 alpha:1.0] setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    for (int i = 0; i < 3; i++) {
        CGFloat y = 6 + i * 4;
        CGContextMoveToPoint(ctx, 3, y);
        CGContextAddLineToPoint(ctx, 17, y);
    }
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end

#pragma mark - VC

@interface WKCategoryReorderVC () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<WKCategoryEntity *> *reorderList;
@property (nonatomic, strong) UIView *snapshotView;
@property (nonatomic, strong) NSIndexPath *dragIndexPath;
@property (nonatomic, assign) BOOL didReorderInGesture; // 本次手势期间是否实际换过位
@end

@implementation WKCategoryReorderVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.title = LLang(@"排序分组");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    // 数据
    _reorderList = [NSMutableArray array];
    for (WKCategoryEntity *cat in self.categories) {
        if (cat.is_default) continue; // 与关注 tab 一致：默认分组不参与排序
        if (cat.category_id && cat.category_id.length > 0) {
            [_reorderList addObject:cat];
        }
    }

    // TableView（不使用 editing 模式，用长按拖拽手势代替）
    CGRect rect = CGRectMake(0, self.navigationBar.lim_bottom, self.view.lim_width, self.view.lim_height - self.navigationBar.lim_bottom);
    _tableView = [[UITableView alloc] initWithFrame:rect style:UITableViewStylePlain];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [WKApp shared].config.backgroundColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _tableView.separatorInset = UIEdgeInsetsMake(0, 20, 0, 20);
    _tableView.rowHeight = 56;
    _tableView.tableFooterView = [[UIView alloc] init];
    [_tableView registerClass:[WKCategoryReorderCell class] forCellReuseIdentifier:@"cell"];
    [self.view addSubview:_tableView];

    // 长按拖拽手势
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.3;
    [_tableView addGestureRecognizer:longPress];
}

#pragma mark - DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _reorderList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKCategoryReorderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.indexLbl.text = [NSString stringWithFormat:@"%ld", (long)(indexPath.row + 1)];
    cell.nameLbl.text = _reorderList[indexPath.row].name;
    return cell;
}

#pragma mark - 点击行 → 操作菜单

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self showRowActions:indexPath];
}

- (void)showRowActions:(NSIndexPath *)indexPath {
    NSInteger count = _reorderList.count;
    if (count <= 1) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:_reorderList[indexPath.row].name message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    if (indexPath.row > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"移到最前") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf moveItem:indexPath.row to:0];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"上移一位") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf moveItem:indexPath.row to:indexPath.row - 1];
        }]];
    }
    if (indexPath.row < count - 1) {
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"下移一位") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf moveItem:indexPath.row to:indexPath.row + 1];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:LLang(@"移到最后") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf moveItem:indexPath.row to:count - 1];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)moveItem:(NSInteger)from to:(NSInteger)to {
    if (from == to) return;
    WKCategoryEntity *item = _reorderList[from];
    [_reorderList removeObjectAtIndex:from];
    [_reorderList insertObject:item atIndex:to];
    [_tableView beginUpdates];
    [_tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:from inSection:0]
                       toIndexPath:[NSIndexPath indexPathForRow:to inSection:0]];
    [_tableView endUpdates];
    // 刷新序号
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
    // tap 触发的"移到最前 / 上移 / 下移 / 移到最后"也要走持久化 —— 之前只在 long-press
    // 拖完才 commitReorder，"完成"按钮也已经被移除，导致用户用 row action 改顺序后退出
    // 页面就丢。这里同步触发一次保存，commit 异步走 API 不阻塞 UI。
    [self commitReorder];
}

#pragma mark - 左滑删除（iOS 11+）

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (indexPath.row >= (NSInteger)_reorderList.count) return nil;
    WKCategoryEntity *cat = _reorderList[indexPath.row];
    if (cat.is_default || cat.category_id.length == 0) return nil; // 默认分组不允许删
    __weak typeof(self) weakSelf = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                      title:LLang(@"删除")
                                                                    handler:^(UIContextualAction *action, UIView *src, void (^completion)(BOOL)) {
        [weakSelf confirmDeleteCategoryAtIndexPath:indexPath completion:completion];
    }];
    UISwipeActionsConfiguration *cfg = [UISwipeActionsConfiguration configurationWithActions:@[del]];
    cfg.performsFirstActionWithFullSwipe = NO; // 防止误触：必须点击红色按钮才删
    return cfg;
}

- (void)confirmDeleteCategoryAtIndexPath:(NSIndexPath *)indexPath completion:(void(^)(BOOL))completion {
    if (indexPath.row >= (NSInteger)_reorderList.count) { if (completion) completion(NO); return; }
    WKCategoryEntity *cat = _reorderList[indexPath.row];
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if (spaceId.length == 0 || cat.category_id.length == 0) { if (completion) completion(NO); return; }

    NSString *msg = [NSString stringWithFormat:LLang(@"确认删除分组「%@」？该分组下所有关注会被取消。"), cat.name];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"取消") style:UIAlertActionStyleCancel handler:^(UIAlertAction *_) {
        if (completion) completion(NO);
    }]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:LLang(@"删除") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
        [[WKCategoryService shared] deleteCategory:spaceId categoryId:cat.category_id].then(^(id r) {
            // 服务端会把该分组下的全部 follow 一并取消，本地 followedKeys 必须同步刷新,
            // 否则返回列表页长按这些会话还会显示"取消关注"，要等下次 30s debounce 兜底才正确。
            [[WKFollowedKeysStore shared] reload];
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) { if (completion) completion(YES); return; }
            NSInteger idx = [strongSelf->_reorderList indexOfObject:cat];
            if (idx != NSNotFound) {
                [strongSelf->_reorderList removeObjectAtIndex:idx];
                [strongSelf->_tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [strongSelf.tableView reloadData];
                });
            }
            if (completion) completion(YES);
        }).catch(^(NSError *err) {
            [self.view showMsg:err.domain ?: LLang(@"删除分组失败")];
            if (completion) completion(NO);
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - 长按拖拽排序

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:_tableView];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:location];
            if (!indexPath) return;
            _dragIndexPath = indexPath;
            _didReorderInGesture = NO;

            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
            _snapshotView = [cell snapshotViewAfterScreenUpdates:YES];
            _snapshotView.frame = [_tableView rectForRowAtIndexPath:indexPath];
            _snapshotView.frame = [_tableView convertRect:_snapshotView.frame toView:_tableView.superview];
            _snapshotView.layer.shadowColor = [UIColor blackColor].CGColor;
            _snapshotView.layer.shadowOpacity = 0.2;
            _snapshotView.layer.shadowRadius = 8;
            _snapshotView.layer.shadowOffset = CGSizeMake(0, 2);
            _snapshotView.alpha = 0.95;
            [_tableView.superview addSubview:_snapshotView];

            [UIView animateWithDuration:0.2 animations:^{
                self.snapshotView.transform = CGAffineTransformMakeScale(1.03, 1.03);
                cell.contentView.alpha = 0;
            }];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!_snapshotView || !_dragIndexPath) return;
            CGPoint ptInSuper = [gesture locationInView:_tableView.superview];
            _snapshotView.center = CGPointMake(_snapshotView.center.x, ptInSuper.y);

            NSIndexPath *toIndexPath = [_tableView indexPathForRowAtPoint:location];
            if (toIndexPath && toIndexPath.row != _dragIndexPath.row) {
                WKCategoryEntity *item = _reorderList[_dragIndexPath.row];
                [_reorderList removeObjectAtIndex:_dragIndexPath.row];
                [_reorderList insertObject:item atIndex:toIndexPath.row];
                [_tableView moveRowAtIndexPath:_dragIndexPath toIndexPath:toIndexPath];
                _dragIndexPath = toIndexPath;
                _didReorderInGesture = YES;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!_dragIndexPath) return;
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:_dragIndexPath];
            BOOL shouldCommit = _didReorderInGesture;
            [UIView animateWithDuration:0.2 animations:^{
                self.snapshotView.transform = CGAffineTransformIdentity;
                CGRect rect = [self.tableView rectForRowAtIndexPath:self.dragIndexPath];
                self.snapshotView.frame = [self.tableView convertRect:rect toView:self.tableView.superview];
            } completion:^(BOOL finished) {
                cell.contentView.alpha = 1;
                [self.snapshotView removeFromSuperview];
                self.snapshotView = nil;
                self.dragIndexPath = nil;
                self.didReorderInGesture = NO;
                [self.tableView reloadData]; // 刷新序号
                if (shouldCommit) {
                    [self commitReorder];
                }
            }];
            break;
        }
        default:
            break;
    }
}

#pragma mark - 保存排序

/// 拖拽结束后立即调用 — 与关注 tab 长按拖动排序走同一个接口（WKCategoryService.sortCategories:）。
/// 提交的 ID 列表必须包含所有分组（含默认分组），否则服务端会判定为不完整并拒绝。
/// 默认分组不参与拖动排序，按 self.categories 中的原位置塞回；非默认分组按用户拖动的新顺序排。
- (void)commitReorder {
    NSMutableArray *ids = [NSMutableArray array];
    NSInteger reorderIdx = 0;
    for (WKCategoryEntity *cat in self.categories) {
        if (cat.category_id.length == 0) continue;
        if (cat.is_default) {
            [ids addObject:cat.category_id];
        } else if (reorderIdx < _reorderList.count) {
            [ids addObject:_reorderList[reorderIdx].category_id];
            reorderIdx++;
        }
    }
    if (ids.count == 0) return;
    __weak typeof(self) weakSelf = self;
    [[WKCategoryService shared] sortCategories:self.spaceId categoryIds:ids].then(^(id r) {
        if (weakSelf.onReorderComplete) weakSelf.onReorderComplete();
    }).catch(^(NSError *e) {
        NSLog(@"排序失败: %@", e);
        [weakSelf.view showMsg:LLang(@"排序失败")];
    });
}

@end
