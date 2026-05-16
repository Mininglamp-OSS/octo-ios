//
//  WKStickerHotContentView.m
//  WuKongBase
//
//  Created by tt on 2020/1/10.
//

#import "WKStickerGIFContentView.h"
#import "WKCollectionViewGridLayout.h"
#import "WKStickerGIFCell.h"
#import "WKResource.h"
#import "UIView+WK.h"
#import "WKGIFContent.h"
#import "WKLottieStickerContent.h"
#import "WKStickerPackage.h"





@interface WKStickerGIFContentView ()<UICollectionViewDataSource,UICollectionViewDelegate>

@property(nonatomic,strong) UICollectionView *collectionView;
@property(nonatomic,strong) WKStickerPackage *stickerPackage;
@property(nonatomic,copy) NSString *keyword;

@property(nonatomic,strong) UIView *tabView;

@property(nonatomic,strong) NSURL *tabIconURL;

@property(nonatomic,assign) BOOL selectedInner;

@end

static NSMutableDictionary *cacheGifDict;

@implementation WKStickerGIFContentView

-(instancetype) initWithKeyword:(NSString*)keyword tabIconURL:(NSURL*)tabIconURL
{
    self = [super init];
    if (self) {
        self.keyword = keyword;
        self.tabIconURL = tabIconURL;
        [self addSubview:self.collectionView];
        [self setBackgroundColor:[UIColor whiteColor]];
    }
    return self;
}

- (void)setSelected:(BOOL)selected {
    BOOL change = self.selectedInner != selected;
    self.selectedInner = selected;
    if(self.selectedInner) {
        NSLog(@"keyword--->%@",self.keyword);
    }
    if(change) {
        [self.collectionView reloadData];
    }
    if(!selected) {
       NSArray<WKStickerGIFCell*> *cells = self.collectionView.visibleCells;
        for (WKStickerGIFCell *cell in cells) {
            [cell onEndDisplay];
        }
    }
}

- (BOOL)selected {
    return self.selectedInner;
}

- (void)loadData {
    [self requestHotGif];
}

-(void) requestHotGif {
    NSString *keyword = self.keyword;
    if(!self.keyword) {
        keyword = LLang(@"热图");
    }
    if(!cacheGifDict) {
        cacheGifDict = [NSMutableDictionary dictionary];
    }
    id stickerPackage = cacheGifDict[keyword];
    if(stickerPackage) {
        self.stickerPackage = stickerPackage;
        [self.collectionView reloadData];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:@"sticker/user/sticker" parameters:@{@"category":keyword} model:WKStickerPackage.class].then(^(WKStickerPackage *stickerPackage){
        weakSelf.stickerPackage = stickerPackage;
        cacheGifDict[keyword] = stickerPackage;
        [weakSelf.collectionView reloadData];
    });
}

- (UIView *)customTabView {
    if(!_tabView) {
        UIImageView *icon = [[UIImageView alloc] init];
        [icon lim_setImageWithURL:self.tabIconURL];
        _tabView= icon;
    }
    return _tabView;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if([self.customTabView isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel*)self.customTabView;
        lbl.textColor = [WKApp shared].config.defaultTextColor;
    }
    self.collectionView.lim_size = self.lim_size;
}

// grid布局
+(WKCollectionViewGridLayout *)newGridLayout
{
    WKCollectionViewGridLayout *layout = [WKCollectionViewGridLayout new];
    layout.itemSpacing = 10;
    layout.lineSpacing = 10;
    layout.lineSize = 0;
    layout.lineItemCount = 5;
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.sectionsStartOnNewLine = NO;
    
    return layout;
}

-(UICollectionView*) collectionView {
    if(!_collectionView) {
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) collectionViewLayout:[[self class] newGridLayout]];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        [_collectionView setBackgroundColor:[UIColor clearColor]];
        [_collectionView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f,0.0f)];
        [_collectionView registerClass:[WKStickerGIFCell class] forCellWithReuseIdentifier:[WKStickerGIFCell reuseIdentifier]];
    }
    return _collectionView;
}


#pragma mark - UICollectionViewDataSource && UICollectionViewDelegate
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if(self.stickerPackage && self.stickerPackage.list) {
        return self.stickerPackage.list.count;
    }
    return 0;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    WKStickerGIFCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[WKStickerGIFCell reuseIdentifier] forIndexPath:indexPath];
   
    return cell;
}
-(void)collectionView:(UICollectionView *)collectionView willDisplayCell:(WKStickerGIFCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath{
   WKSticker *resp =  self.stickerPackage.list[indexPath.row];
    resp.isPlay = self.selected;
    if(self.selected) { // true为当前被选中的面板
        NSLog(@"self.isPlay--->%d",resp.isPlay?1:0);
    }
    [cell refresh:resp];
    
    [cell onWillDisplay];
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(WKStickerGIFCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    [cell onEndDisplay];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    WKSticker *resp =  self.stickerPackage.list[indexPath.row];
    WKLottieStickerContent *content = [WKLottieStickerContent new];
    content.url = resp.path;
    content.category =  resp.category;
    content.placeholder = resp.placeholder;
    content.format = resp.format;
    [self.context sendMessage:content];
}


- (void)dealloc
{
    WKLogDebug(@"%s",__func__);
}

@end

