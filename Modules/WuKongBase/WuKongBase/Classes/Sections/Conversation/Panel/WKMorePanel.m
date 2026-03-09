//
//  WKMorePanel.m
//  WuKongBase
//
//  Created by tt on 2020/1/9.
//

#import "WKMorePanel.h"
#import "WKConstant.h"
#import "WKCollectionViewGridLayout.h"
#import "WKApp.h"
#import "WKMoreItemCell.h"
#import "WKConstant.h"
#import "WKMoreItemModel.h"
@interface WKMorePanel ()<UICollectionViewDataSource,UICollectionViewDelegate>

@property(nonatomic,strong) UICollectionView *collectionView;

@property(nonatomic,strong) NSArray<WKMoreItemModel*> *moreItems;

@end
@implementation WKMorePanel

-(instancetype) initWithContext:(id<WKConversationContext>) context {
    self = [super initWithContext:context];
    if(self) {
        self.moreItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_PANELMORE_ITEMS param:@{@"context":context}];
        [self addSubview:self.collectionView];
    }
    return self;
}

-(void) layoutPanel:(CGFloat)height {
    self.frame = CGRectMake(0, 0, WKScreenWidth,height);
     self.collectionView.frame = self.frame;
}


// grid布局
+(WKCollectionViewGridLayout *)newGridLayout
{
    WKCollectionViewGridLayout *layout = [WKCollectionViewGridLayout new];
    layout.itemSpacing = 20;
    layout.lineSpacing = 40;
    layout.lineSize = 0;
    layout.lineItemCount = 4;
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.sectionsStartOnNewLine = NO;
    
    return layout;
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

-(UICollectionView*) collectionView {
    if(!_collectionView) {
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) collectionViewLayout:[[self class] newGridLayout]];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        [_collectionView setBackgroundColor:[WKApp shared].config.backgroundColor];
        [_collectionView setContentInset:UIEdgeInsetsMake(40.0f, 20.0f, 20.0f, 20.0f)];
        if(self.moreItems) {
            for (WKMoreItemModel *model in self.moreItems) {
                 Class moreItemCellClass = [[model class] moreItemCellClass];
                [_collectionView registerClass:moreItemCellClass forCellWithReuseIdentifier:[moreItemCellClass reuseIdentifier]];
            }
        }
    }
    return _collectionView;
}


#pragma mark - UICollectionViewDataSource && UICollectionViewDelegate
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.moreItems.count;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    WKMoreItemModel *model = [self.moreItems objectAtIndex:indexPath.row];
    Class moreItemCellClass = [[model class] moreItemCellClass];
    WKMoreItemCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[moreItemCellClass reuseIdentifier] forIndexPath:indexPath];
    cell.conversatonContext = self.context;
    
    return cell;
}
-(void)collectionView:(UICollectionView *)collectionView willDisplayCell:(WKMoreItemCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath{
      WKMoreItemModel *model = [self.moreItems objectAtIndex:indexPath.row];
    [cell refresh:model];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    WKMoreItemModel *model = [self.moreItems objectAtIndex:indexPath.row];
    if(model.oncClickBLock) {
        model.oncClickBLock(self.context);
    }
}
@end
