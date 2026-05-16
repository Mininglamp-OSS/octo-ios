// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKCategoryReorderVC.m
//  WuKongBase
//

#import "WKCategoryReorderVC.h"
#import "WKCategoryEntity.h"
#import "WKCategoryService.h"
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
@end

@implementation WKCategoryReorderVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.title = LLang(@"排序分组");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;

    // 完成按钮
    UIButton *doneBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [doneBtn setTitle:LLang(@"完成") forState:UIControlStateNormal];
    [doneBtn setTitleColor:[WKApp shared].config.themeColor forState:UIControlStateNormal];
    doneBtn.titleLabel.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
    [doneBtn sizeToFit];
    [doneBtn addTarget:self action:@selector(onDone) forControlEvents:UIControlEventTouchUpInside];
    self.rightView = doneBtn;

    // 数据
    _reorderList = [NSMutableArray array];
    for (WKCategoryEntity *cat in self.categories) {
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
}

#pragma mark - 长按拖拽排序

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:_tableView];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:location];
            if (!indexPath) return;
            _dragIndexPath = indexPath;

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
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!_dragIndexPath) return;
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:_dragIndexPath];
            [UIView animateWithDuration:0.2 animations:^{
                self.snapshotView.transform = CGAffineTransformIdentity;
                CGRect rect = [self.tableView rectForRowAtIndexPath:self.dragIndexPath];
                self.snapshotView.frame = [self.tableView convertRect:rect toView:self.tableView.superview];
            } completion:^(BOOL finished) {
                cell.contentView.alpha = 1;
                [self.snapshotView removeFromSuperview];
                self.snapshotView = nil;
                self.dragIndexPath = nil;
                [self.tableView reloadData]; // 刷新序号
            }];
            break;
        }
        default:
            break;
    }
}

#pragma mark - 完成

- (void)onDone {
    NSMutableArray *ids = [NSMutableArray array];
    for (WKCategoryEntity *cat in _reorderList) {
        [ids addObject:cat.category_id];
    }
    __weak typeof(self) weakSelf = self;
    [[WKCategoryService shared] sortCategories:self.spaceId categoryIds:ids].then(^(id r) {
        if (weakSelf.onReorderComplete) {
            weakSelf.onReorderComplete();
        }
        [[WKNavigationManager shared] popViewControllerAnimated:YES];
    }).catch(^(NSError *e) {
        NSLog(@"排序失败: %@", e);
    });
}

@end
