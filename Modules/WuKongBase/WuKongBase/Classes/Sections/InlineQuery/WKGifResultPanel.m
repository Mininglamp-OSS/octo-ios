//
//  WKGifResultPanel.m
//  WuKongBase
//
//  Created by tt on 2021/11/9.
//

#import "WKGifResultPanel.h"
#import "WKGIFContent.h"
@interface WKGifResultPanel ()<UICollectionViewDelegate,UICollectionViewDataSource>

@property(nonatomic,strong) UICollectionView *contentView;

@property(nonatomic,strong) WKInlineQueryResult *result;

@property(nonatomic,strong) NSMutableArray<WKGifResult*> *gifItems;

@property(nonatomic,assign) CGFloat itemWidth;

@property(nonatomic,weak) id<WKConversationContext> context;

@property(nonatomic,assign) BOOL startLoading;

@end

@implementation WKGifResultPanel

+(instancetype) result:(WKInlineQueryResult*)result context:(id<WKConversationContext>)context{
    CGFloat itemWidth = WKScreenWidth/3.0f - 20.0f;
    WKGifResultPanel *panel = [[WKGifResultPanel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, itemWidth)];
    panel.result = result;
    panel.itemWidth = itemWidth;
    if(result.results) {
        [panel.gifItems addObjectsFromArray:result.results];
    }
    panel.context = context;
    [panel setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    [panel setupUI];
    [panel reload];
    return panel;
}


-(void) setupUI {
    [self addSubview:self.contentView];
}

-(void) reload {
   
    [self.contentView reloadData];

}


- (UICollectionView *)contentView {
    if(!_contentView) {
        UICollectionViewFlowLayout*layout=[[UICollectionViewFlowLayout alloc]init];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.itemSize = CGSizeMake(self.itemWidth, self.itemWidth);
        layout.minimumLineSpacing = 2.0f;
        layout.minimumInteritemSpacing = 2.0f;
        _contentView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        _contentView.delegate = self;
        _contentView.dataSource = self;
        [_contentView setBackgroundColor:[UIColor clearColor]];
        [_contentView registerClass:WKGifResultCell.class forCellWithReuseIdentifier:@"WKGifResultCell"];
    }
    return _contentView;
}

- (NSMutableArray<WKGifResult *> *)gifItems {
    if(!_gifItems) {
        _gifItems = [NSMutableArray array];
    }
    return _gifItems;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.contentView.frame = self.bounds;

}
//
//- (void)layoutSubviews {
//    [super layoutSubviews];
//    self.contentView.frame = self.bounds;
//    NSArray *subviews = self.contentView.subviews;
//    if(subviews && subviews.count>0) {
//        UIView *preView;
//        for (UIView *subView in subviews) {
//            if(preView) {
//                subView.lim_top = 0.0f;
//                subView.lim_left = preView.lim_right;
//            }else {
//                subView.lim_top = 0.0f;
//                subView.lim_left = 0.0f;
//            }
//            preView = subView;
//        }
//        [self.contentView setContentSize:CGSizeMake(preView.lim_right, self.lim_height)];
//    }
//
//
//}

#pragma mark -- UICollectionViewDelegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.gifItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    WKGifResult *result =self.gifItems[indexPath.row];
    WKGifResultCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"WKGifResultCell" forIndexPath:indexPath];
    [cell refresh:result];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    WKGifResult *result =self.gifItems[indexPath.row];
    [self.context setInputTopView:nil];
    WKGIFContent *content = [WKGIFContent initWithURL:result.url width:result.width height:result.height];
    [self.context sendMessage:content];
    [self.context inputSetText:@""];
}



#pragma mark -- UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(self.startLoading) {
        return;
    }
    NSLog(@" scrollView.contentOffset.x-%0.2f--%0.2f",(scrollView.contentOffset.x + self.contentView.lim_width),scrollView.contentSize.width);
    if((scrollView.contentOffset.x + self.contentView.lim_width) - scrollView.contentSize.width>30.0f) {
        self.startLoading = true;
        [self loadMoreData];
    }
}


-(void) loadMoreData {
    __weak typeof(self) weakSelf = self;
    self.loadMore(self.result.nextOffset, ^(WKInlineQueryResult * _Nonnull result,NSError *error) {
       
        if(error) {
            weakSelf.startLoading = false;
            return;
        }
        weakSelf.result = result;
        [weakSelf.gifItems addObjectsFromArray:result.results];
        [weakSelf reload];
        weakSelf.startLoading = false;
    });
}

@end

@interface WKGifResultCell ()

@property(nonatomic,strong) UIImageView *gifImgView;

@end

@implementation WKGifResultCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self.contentView addSubview:self.gifImgView];
    }
    return self;
}

-(void) refresh:(WKGifResult*)result {
    [self.gifImgView setSd_imageIndicator:SDWebImageActivityIndicator.grayIndicator];
    [self.gifImgView lim_setImageWithURL:[NSURL URLWithString:result.url] placeholderImage:nil options:SDWebImageFromLoaderOnly context:nil];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.gifImgView.frame = self.bounds;
}

- (UIImageView *)gifImgView {
    if(!_gifImgView) {
        _gifImgView = [[UIImageView alloc] init];
    }
    return _gifImgView;
}
@end
