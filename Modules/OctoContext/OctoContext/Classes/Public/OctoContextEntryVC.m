//
//  OctoContextEntryVC.m
//  OctoContext
//

#import "OctoContextEntryVC.h"
#import "OctoContextEntryGridCell.h"
#import "OctoContextSparkleIconView.h"
#import "OctoSummaryListVC.h"

@interface OctoContextEntryItem : NSObject
@property(nonatomic, copy) NSString *itemId;
@property(nonatomic, copy) NSString *titleKey;     // LLang key
@property(nonatomic, copy) UIView *(^iconBuilder)(void);
@property(nonatomic, copy) void (^onTap)(UIViewController *fromVC);
@end
@implementation OctoContextEntryItem
@end


@interface OctoContextEntryVC () <UICollectionViewDataSource, UICollectionViewDelegate>
@property(nonatomic, strong) UICollectionView *collectionView;
@property(nonatomic, strong) NSArray<OctoContextEntryItem *> *items;
@end

@implementation OctoContextEntryVC

- (void)viewDidLoad {
    [super viewDidLoad];

    // largeTitle = YES 让 WKNavigationBar 把 title 左对齐到 20pt, 对齐设计稿的
    // 22pt 左 padding。设计稿是 16pt, navbar 内置 20pt 在视觉上几乎一致。
    self.navigationBar.largeTitle = YES;
    self.navigationBar.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    self.navigationBar.title = LLang(@"上下文");

    self.items = [self buildItems];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    // 设计稿: app-grid 容器 padding 0 10, 每个 item 94×100。375 viewport 下 4 列 ≈ (375-20)/4 = 88.75,
    // 取 90 列宽 + 4 列适配 iPhone 14 Pro / 普通设备宽度。
    layout.itemSize = CGSizeMake(94, 100);
    layout.minimumInteritemSpacing = 0;
    layout.minimumLineSpacing = 0;
    layout.sectionInset = UIEdgeInsetsMake(0, 10, 0, 10);
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:OctoContextEntryGridCell.class forCellWithReuseIdentifier:@"OctoContextEntryGridCell"];
    [self.view addSubview:self.collectionView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = CGRectGetMaxY(self.navigationBar.frame);
    self.collectionView.frame = CGRectMake(0, top,
                                           self.view.bounds.size.width,
                                           self.view.bounds.size.height - top);
}

- (NSArray<OctoContextEntryItem *> *)buildItems {
    OctoContextEntryItem *summary = [OctoContextEntryItem new];
    summary.itemId = @"smart_summary";
    summary.titleKey = @"智能总结";
    summary.iconBuilder = ^UIView *{ return [OctoContextSparkleIconView new]; };
    summary.onTap = ^(UIViewController *fromVC) {
        OctoSummaryListVC *vc = [OctoSummaryListVC new];
        vc.hidesBottomBarWhenPushed = YES;
        [fromVC.navigationController pushViewController:vc animated:YES];
    };
    return @[summary];
}

#pragma mark - UICollectionView

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    OctoContextEntryGridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"OctoContextEntryGridCell" forIndexPath:indexPath];
    OctoContextEntryItem *item = self.items[indexPath.item];
    UIView *icon = item.iconBuilder ? item.iconBuilder() : [UIView new];
    [cell bindIcon:icon title:LLang(item.titleKey)];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    OctoContextEntryItem *item = self.items[indexPath.item];
    if (item.onTap) item.onTap(self);
}

@end
