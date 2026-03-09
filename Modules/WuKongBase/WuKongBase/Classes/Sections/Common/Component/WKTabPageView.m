//
//  WKTabPageView.m
//  WuKongBase
//
//  Created by tt on 2020/1/10.
//
// tabbar栏的高度
#define WK_EMOJI_TABBAR_HEIGHT 46.0f

#define WK_SEND_WIDTH 80.0f
// tab item的大小
#define WK_TAB_ITEM_SIZE CGSizeMake(46.0f, 46.0f)

#import "WKTabPageView.h"
#import "WKPageView.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WuKongBase.h"
@interface WKTabPageView ()<UIScrollViewDelegate,WKPageViewDelegate,WKPageViewDataSource>


@property(nonatomic,strong) UIView *maskView; // 遮挡层

@property(nonatomic,strong) WKPageView *pageView;

@property(nonatomic,strong) UIButton *sendBtn;

@property(nonatomic,assign) BOOL isInited; // 是否已初始化

@end

@implementation WKTabPageView

-(instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        [self addSubview:self.tabbarScrollView];
        [self addSubview:self.pageView];
        [self addSubview:self.sendBtn];
        
    }
    return self;
}

- (NSInteger)currentPage {
    return self.pageView.currentPage;
}

- (void)setPreloadOff:(BOOL)preloadOff {
    self.pageView.preloadOff = preloadOff;
}

-(UIView*) maskView {
    if(!_maskView) {
        _maskView = [[UIView alloc] init];
        _maskView.layer.opacity = 1.0;
    }
    return _maskView;
}
-(void) layoutSubviews {
    [super layoutSubviews];
   
    if([WKApp shared].config.style == WKSystemStyleDark) {
        [self.maskView setBackgroundColor:[UIColor colorWithRed:22.0f/255.0f green:22.0f/255.0f blue:22.0f/255.0f alpha:1.0]];
    }else{
        [self.maskView setBackgroundColor:[UIColor colorWithRed:233.0f/255.0f green:233.0f/255.0f blue:233.0f/255.0f alpha:1.0]];
        
    }
    
    
    self.tabbarScrollView.frame =CGRectMake(self.tabbarScrollViewLeftSpace, self.frame.size.height - WK_EMOJI_TABBAR_HEIGHT, self.frame.size.width - self.sendBtn.lim_width - self.tabbarScrollViewLeftSpace, WK_EMOJI_TABBAR_HEIGHT);
    self.pageView.frame =CGRectMake(0,0, self.frame.size.width, self.frame.size.height - WK_EMOJI_TABBAR_HEIGHT);
    if(!self.isInited) {
        [self initTabScrollView];
        [self reloadTabPageView];
        [self.pageView reloadData];
        self.isInited = true;
    }
    
    self.sendBtn.lim_top = self.tabbarScrollView.lim_top;
    self.sendBtn.lim_height = self.tabbarScrollView.lim_height;
    self.sendBtn.lim_left = self.tabbarScrollView.lim_right;
   
}

-(WKPageView*) pageView {
    if(!_pageView) {
        _pageView = [[WKPageView alloc] init];
        _pageView.dataSource       = self;
        _pageView.pageViewDelegate = self;
        [self initTabScrollView];
    }
    return _pageView;
}

-(UIScrollView*) tabbarScrollView {
    if(!_tabbarScrollView) {
        _tabbarScrollView = [[UIScrollView alloc] init];
    }
    return _tabbarScrollView;
}

- (UIButton *)sendBtn {
    if(!_sendBtn) {
        _sendBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f,WK_SEND_WIDTH, 0.0f)];
        [_sendBtn setTitle:LLang(@"发送") forState:UIControlStateNormal];
        [[_sendBtn titleLabel] setFont:[UIFont systemFontOfSize:20.0f]];
        [_sendBtn setBackgroundColor:[WKApp shared].config.themeColor];
        [_sendBtn addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _sendBtn;
}

-(void) sendPressed {
    if(self.delegate && [self.delegate respondsToSelector:@selector(didSendOfTabPageView:)]) {
        [self.delegate didSendOfTabPageView:self];
    }
}


-(void) reloadTabPageView {
    
    // 重置tab滚动视图
    [self resetTabScrollView];
    // 重置内容滚动视图
//    [self resetContentScrollView];
    
    [self selectTabIndex:0];
}



-(void) initTabScrollView {
    // 初始化tab
    __weak typeof(self) weakSelf = self;
    NSInteger tabCount = [weakSelf.delegate numOfTabPageView:weakSelf];
    UIView *preTabView;
    for (NSInteger i=0;i<tabCount;i++) {
        UIView *tabbarView;
        if(preTabView) {
             tabbarView = [self.delegate tabPageView:weakSelf suggestTabFrame:CGRectMake(preTabView.lim_right,self.tabbarScrollView.lim_height/2.0f - WK_TAB_ITEM_SIZE.height/2.0f, WK_TAB_ITEM_SIZE.width, WK_TAB_ITEM_SIZE.height) atIndex:i];
            
        } else {
             tabbarView = [self.delegate tabPageView:weakSelf suggestTabFrame:CGRectMake(0.0f,self.tabbarScrollView.lim_height/2.0f - WK_TAB_ITEM_SIZE.height/2.0f, WK_TAB_ITEM_SIZE.width, WK_TAB_ITEM_SIZE.height) atIndex:i];
        }
        preTabView = tabbarView;
        tabbarView.lim_top = self.tabbarScrollView.lim_height/2.0f - tabbarView.lim_height/2.0f;
        tabbarView.tag = i;
        [self.tabbarScrollView addSubview:tabbarView];
        // TODO: 这个tap没释放不知道会有没有问题
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tabClick:)];
        [tabbarView addGestureRecognizer:tap];
    }
    if(preTabView) {
         self.tabbarScrollView.contentSize = CGSizeMake(preTabView.lim_right, self.tabbarScrollView.frame.size.height);
    }
}

// 重置tab scrollview
-(void) resetTabScrollView {
    [self.tabbarScrollView .subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self initTabScrollView];
 
   
}

-(void) tabClick:(UITapGestureRecognizer*) tapGesture {
    [self selectTabIndex:tapGesture.view.tag];
}
// tab被选中
- (void)selectTabIndex:(NSInteger)index{
    
    [self onlySelectTabIndex:index];
    [self.pageView scrollToPage:index];
    
}

-(void) onlySelectTabIndex:(NSInteger)index {
    [self.maskView removeFromSuperview];
    if(self.tabbarScrollView.subviews.count<=0) {
        return;
    }
    UIView *subView = self.tabbarScrollView.subviews[index];
    self.maskView.frame = CGRectMake(0, 0, subView.frame.size.width, subView.frame.size.height);
    self.maskView.layer.masksToBounds = subView.layer.masksToBounds;
    self.maskView.layer.cornerRadius = subView.layer.cornerRadius;
    [subView addSubview:self.maskView];
    [subView sendSubviewToBack:self.maskView];
    if(subView.frame.origin.x + subView.frame.size.width*2 > self.frame.size.width) {
        [self.tabbarScrollView setContentOffset:CGPointMake(subView.frame.origin.x, 0) animated:YES ];
    }else {
        [self.tabbarScrollView setContentOffset:CGPointMake(0, 0) animated:YES ];
    }
    if(index == 0) {
        self.sendBtn.lim_width = WK_SEND_WIDTH;
        self.sendBtn.hidden = NO;
    }else {
        self.sendBtn.lim_width = 0;
        self.sendBtn.hidden = YES;
    }
}

#pragma mark - WKPageViewDelegate
- (NSInteger)numberOfPages: (WKPageView *)pageView{
    
    
    return [self.delegate numOfTabPageView:self];
}
- (UIView *)pageView: (WKPageView *)pageView viewInPage: (NSInteger)index{
    
    return [self.delegate tabPageView:self suggestContentFrame:CGRectMake(0, 0, self.pageView.frame.size.width, self.pageView.frame.size.height) atIndex:index];
}

- (void)pageViewScrollEnd: (WKPageView *)pageView
             currentIndex: (NSInteger)index
               totolPages: (NSInteger)pages{
    
    [self onlySelectTabIndex:index];
    
    [self.delegate didSelectOfTabPageView:self index:index];
    
}

@end
