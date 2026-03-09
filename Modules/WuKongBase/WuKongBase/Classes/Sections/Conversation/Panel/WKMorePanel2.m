//
//  WKMorePanel2.m
//  WuKongBase
//
//  Created by tt on 2020/9/28.
//

#import "WKMorePanel2.h"
#import "WKTabPageView.h"

#define eachPagelineCount 2 // 每页行数
#define eachLineItemCount 4 // 每行item数量

#define itemSpacing 10.0f
#define lineSpacing 10.0f

#define contentInsets  UIEdgeInsetsMake(10.0f, 10.0f, 30.0f, 10.0f)

@interface WKMorePanel2 ()<UIScrollViewDelegate>

@property(nonatomic,strong) UIScrollView *scrollView;

@property(nonatomic,strong) UIPageControl *pageControl;

@property(nonatomic,strong) NSArray<WKMoreItemModel*> *moreItems;

@end

@implementation WKMorePanel2

-(instancetype) initWithContext:(id<WKConversationContext>)context {
    self = [super initWithContext:context];
    if (self) {
        
        [self addSubview:self.scrollView];
        self.scrollView.backgroundColor = [WKApp shared].config.backgroundColor;
        [self addSubview:self.pageControl];
        self.moreItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_PANELMORE_ITEMS param:@{@"context":context}];
    }
   
    return self;
}


-(void) layoutPanel:(CGFloat)height {
    self.frame = CGRectMake(0, 0, WKScreenWidth,height);
    self.scrollView.frame = self.frame;
    
    [[self.scrollView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self layoutItems];
    
}

// 实现scrollView滚动的方法
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    //如何计算当前滚动到了第几页
    // 1.获取滚动的x方向的偏移量
    CGFloat offsetX = self.scrollView.contentOffset.x;
    offsetX = offsetX + self.scrollView.frame.size.width/2;
     // 2.用x方向的偏移量除以一张图片的宽度，取商就是当前滚动到了第几页
      int page = offsetX/self.scrollView.frame.size.width;
      //3.将页码赋值给UIPageControl
    self.pageControl.currentPage = page;

}

-(void) layoutItems {
    if(!self.moreItems || self.moreItems.count<=0) {
        return;
    }
    CGFloat bottomSafeArea = 0.0f;
    if (@available(iOS 11.0, *)) {
        bottomSafeArea = [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom;
    }
    CGFloat itemWidth = (self.scrollView.lim_width - contentInsets.left - contentInsets.right-(eachLineItemCount-1)*itemSpacing)/eachLineItemCount;
    CGFloat itemHeight = (self.scrollView.lim_height - bottomSafeArea - contentInsets.top - contentInsets.bottom - (eachPagelineCount-1)*lineSpacing)/eachPagelineCount;
    NSInteger rowIndex = 0;
    NSInteger columnIndex = 0;
    NSInteger pageIndex = 0;
    
    for (NSInteger i=0; i<self.moreItems.count; i++) {
        WKMoreItemModel *model = self.moreItems[i];
        if( i!=0  && i%eachLineItemCount == 0 ) {
            rowIndex++;
            columnIndex = 0;
        }
        if(i!=0 && i%(eachPagelineCount*eachLineItemCount) == 0) {
            pageIndex++;
            rowIndex = 0;
        }
        WKMoreItemView *moreView = [[WKMoreItemView alloc] initWithFrame:CGRectMake((columnIndex)*itemSpacing + columnIndex*itemWidth + contentInsets.left + pageIndex*self.scrollView.lim_width, (rowIndex)*lineSpacing+rowIndex*itemHeight+contentInsets.top, itemWidth, itemHeight)];
        [moreView.iconImgView setImage:model.image];
        moreView.tag = i;
        [moreView addTarget:self action:@selector(morePressed:) forControlEvents:UIControlEventTouchUpInside];
        [moreView.titleLbl setText:model.title];
        [moreView layoutIfNeeded]; // 如果这里不执行[moreView layoutIfNeeded]会有时候出现moreItem点击不了的情况
        [self.scrollView addSubview:moreView];
        columnIndex++;
    }
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.lim_width*(pageIndex+1), self.scrollView.lim_height)];
    
    self.pageControl.lim_left = self.lim_width/2.0f - self.pageControl.lim_width/2.0f;
    self.pageControl.lim_top = self.lim_height - bottomSafeArea - 20.0f;
    self.pageControl.numberOfPages = pageIndex+1;
}

-(void) morePressed:(UIView*)view {
    WKMoreItemModel *model = self.moreItems[view.tag];
    if(model) {
        model.oncClickBLock(self.context);
    }
}

-(UIScrollView*) scrollView {
    if(!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, 0)];
        _scrollView.pagingEnabled = YES;
        _scrollView.delegate=self;
        _scrollView.showsHorizontalScrollIndicator = NO;
    }
    return _scrollView;
}

- (UIPageControl *)pageControl {
    if(!_pageControl) {
        _pageControl = [[UIPageControl alloc] init];
        _pageControl.pageIndicatorTintColor = [UIColor grayColor];
        _pageControl.currentPageIndicatorTintColor = [WKApp shared].config.defaultTextColor;
        _pageControl.hidesForSinglePage = YES;
    }
    return _pageControl;
}


@end

@interface WKMoreItemView ()


@end

@implementation WKMoreItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.iconImgView];
        [self addSubview:self.titleLbl];
        [self setBackgroundColor:[UIColor clearColor]];
    }
    return self;
}

- (UIImageView *)iconImgView {
    if(!_iconImgView) {
        _iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)];
    }
    return _iconImgView;
}

- (UILabel *)titleLbl {
    if(!_titleLbl) {
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        [_titleLbl setTextColor:[UIColor grayColor]];
    }
    return _titleLbl;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat titleTop = 5.0f;
    
    [self.titleLbl sizeToFit];
    
    CGFloat contentHeight = self.iconImgView.lim_height + self.titleLbl.lim_height + titleTop;
    
    CGFloat iconTop = self.lim_height/2.0f - contentHeight/2.0f;
    
    self.iconImgView.lim_left = self.lim_width/2.0f - self.iconImgView.lim_width/2.0f;
    self.iconImgView.lim_top =iconTop;
    
   
    self.titleLbl.lim_top = self.iconImgView.lim_bottom + titleTop;
    self.titleLbl.lim_left = self.lim_width/2.0f - self.titleLbl.lim_width/2.0f;
    
    
}

@end
