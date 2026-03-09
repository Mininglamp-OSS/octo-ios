//
//  WKUserHandleVC.m
//  WuKongBase
//
//  Created by tt on 2021/11/3.
//

#import "WKUserHandleVC.h"
#import "WKTopShadowView.h"
#import "WKTableHeaderBypassTableView.h"
#define reuseIdentifier @"userHandleCell"
#define initialVisibleCellsCount 3.5f

#define decorationHeight 7.0f
#define shadowHeight 10.0f

@interface WKUserHandleVC ()

@property(nonatomic,strong) WKUserHandleTableHeaderView *tableHeaderView;
@property(nonatomic,strong) WKUserHandleTableFooterView *tableFooterView;

@property(nonatomic,copy) void(^onScrollingAnimationEnd)(void);

@end

@implementation WKUserHandleVC

- (void)viewDidLoad {
    
    [self setTableView:[[WKTableHeaderBypassTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain]];
    
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.tableHeaderView = self.tableHeaderView;
    self.tableView.tableFooterView = self.tableFooterView;
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
   

    
    if(self.registerCellBlock) {
        self.registerCellBlock(self.tableView,reuseIdentifier);
    }
    
}

- (CGFloat)rowHeight {
    if(_rowHeight<=0) {
        return 44.0f;
    }
    return _rowHeight;
}

- (NSArray<WKFormItemModel *> *)items {
    if(!_items) {
        _items = [NSArray array];
    }
    return _items;
}

- (void)reload:(NSArray<WKFormItemModel *> *)items{

   
    NSArray *oldItems = self.items;
    NSArray *newItems = items;
    
    if(newItems.count>0) {
        self.view.hidden = NO;
    }
    
    if(oldItems.count > 0 && newItems.count == 0) { // 列表消失
        [self dismiss];
    }else if(oldItems.count == 0 && newItems.count>0) { // 列表从隐藏到显示
        [self show:newItems];
    } else if(self.tableView.contentOffset.y !=0 ) {
        __weak typeof(self) weakSelf = self;
        self.onScrollingAnimationEnd = ^{
            weakSelf.items = items;
            [weakSelf.tableView reloadData];
        };
        [self.tableView setContentOffset:CGPointMake(0.0f, 0.0f) animated:YES];
    } else{
        CGFloat oldContentHeight = self.view.lim_height - self.tableView.tableHeaderView.lim_height;
        CGFloat contentHeight = [self getContentHeight:newItems];
        if(contentHeight !=oldContentHeight) {
            __weak typeof(self) weakSelf = self;
            self.onScrollingAnimationEnd = ^{
                weakSelf.items = items;
                [weakSelf.tableView reloadData];
            };
            [self.tableView setContentOffset:CGPointMake(0.0f, contentHeight-oldContentHeight) animated:YES];
        }else{
            self.items = items;
            [self.tableView reloadData];
        }
    }
    
}

-(void) show:(NSArray<WKFormItemModel *> *)items {
    self.view.hidden = NO;
    [self loadViewIfNeeded];
    self.items = items;
    [self.tableView reloadData];
    
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
    CGFloat diff = self.view.lim_height - self.tableView.tableHeaderView.lim_height;
    [self.tableView setContentOffset:CGPointMake(0.0f, -diff)];
    [self.tableView setContentOffset:CGPointZero animated:YES];
}

-(void) dismiss {
    __weak typeof(self) weakSelf = self;
    self.onScrollingAnimationEnd = ^{
        weakSelf.items = @[];
        [weakSelf.tableView reloadData];
        weakSelf.view.hidden = YES;
    };
    CGFloat diff = self.view.lim_height - self.tableView.tableHeaderView.lim_height;
    [self.tableView setContentOffset:CGPointMake(0.0f, -diff) animated:YES];
}

- (WKUserHandleTableHeaderView *)tableHeaderView {
    if(!_tableHeaderView) {
        _tableHeaderView = [[WKUserHandleTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 100.0f)];
        _tableHeaderView.backgroundColor = [UIColor clearColor];
        _tableHeaderView.clipsToBounds = true;
    }
    return _tableHeaderView;
}

- (WKUserHandleTableFooterView *)tableFooterView {
    if(!_tableFooterView) {
        _tableFooterView = [[WKUserHandleTableFooterView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 7.0f)];
        if([WKApp shared].config.style == WKSystemStyleDark) {
            _tableFooterView.backgroundColor = [UIColor blackColor];
        }else{
            _tableFooterView.backgroundColor = [UIColor whiteColor];
        }
    }
    return _tableFooterView;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self layoutTableHeaderView];

}

-(void) layoutTableHeaderView {
    CGFloat contentHeight = [self getContentHeight:self.items];
    CGFloat tableHeaderHeight = MAX(0, self.tableView.lim_height - contentHeight);
    if (self.tableHeaderView.lim_height != tableHeaderHeight) {
        self.tableHeaderView.lim_height = tableHeaderHeight;
        self.tableView.tableHeaderView = self.tableHeaderView;
    }
}

-(CGFloat) getContentHeight:(NSArray<WKFormItemModel*>*)items {
    CGFloat contentHeight = MIN((CGFloat)items.count, initialVisibleCellsCount) * self.rowHeight + decorationHeight;
    return contentHeight;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKFormItemCell *cell = (WKFormItemCell*)[tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    WKFormItemModel *model = [self.items objectAtIndex:indexPath.row];
    [cell refresh:model];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(self.onSelect) {
        WKFormItemModel *model = [self.items objectAtIndex:indexPath.row];
        self.onSelect(model);
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if(self.onScrollingAnimationEnd) {
        self.onScrollingAnimationEnd();
        self.onScrollingAnimationEnd = nil;
    }
}

@end



@interface WKUserHandleTableHeaderView ()

@property(nonatomic,strong) WKTopShadowView *shadowView;
@property(nonatomic,strong) UIView *decorationView;

@end

@implementation WKUserHandleTableHeaderView

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if(self) {
        [self setupUI];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self setupUI];
    }
    return self;
}

-(void) setupUI {
    self.shadowView.userInteractionEnabled = false;
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.shadowView.backgroundColor = [UIColor blackColor];
    }else{
        self.shadowView.backgroundColor = [UIColor whiteColor];
    }
    [self addSubview:self.shadowView];
    
    self.decorationView.userInteractionEnabled = false;
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.decorationView.backgroundColor = [UIColor blackColor];
    }else{
        self.decorationView.backgroundColor = [UIColor whiteColor];
    }
    [self addSubview:self.decorationView];
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.decorationView.frame = CGRectMake(0, self.lim_height - decorationHeight, self.lim_width, decorationHeight);
    
    self.shadowView.lim_width = self.lim_width;
    self.shadowView.lim_height = shadowHeight;
    self.shadowView.lim_top = self.decorationView.lim_top +  self.shadowView.lim_height;
}

- (WKTopShadowView *)shadowView {
    if(!_shadowView) {
        _shadowView = [[WKTopShadowView alloc] init];
    }
    return _shadowView;
}

- (UIView *)decorationView {
    if(!_decorationView) {
        _decorationView = [[UIView alloc] init];
    }
    return _decorationView;
}

@end

@interface WKUserHandleTableFooterView ()

@property(nonatomic,strong) UIView *bottomFillingBackgroundView;
@end

@implementation WKUserHandleTableFooterView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        self.bottomFillingBackgroundView = [[UIView alloc] init];
        if([WKApp shared].config.style == WKSystemStyleDark) {
            self.bottomFillingBackgroundView.backgroundColor = [UIColor blackColor];
        }else{
            self.bottomFillingBackgroundView.backgroundColor = [UIColor whiteColor];
        }
        
        [self addSubview:self.bottomFillingBackgroundView];
      
        
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.bottomFillingBackgroundView.lim_width = self.lim_width;
    self.bottomFillingBackgroundView.lim_top = self.lim_height;
    self.bottomFillingBackgroundView.lim_height = 900.0f;
}

@end
