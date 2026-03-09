//
//  WKGlobalSearchResultController.m
//  WuKongBase
//
//  Created by tt on 2020/4/24.
//
#import "WKGlobalSearchVM.h"
#import "WKGlobalSearchResultController.h"
#import "WKTabbar.h"
#define searchBarHeight 36.0f
@interface WKGlobalSearchResultController ()<WKChannelManagerDelegate>
@property(nonatomic,strong) WKGlobalSearchVM *vm; // 搜索逻辑

@property(nonatomic,strong) UITextField *searchBarInput; // 搜索输入框
@property(nonatomic,strong) UIView *searchBarView; // 输入框的bar

@property(nonatomic,strong) WKTabbar *tabbar; // 顶部搜索类型的tabbar



@end

@implementation WKGlobalSearchResultController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.vm = [WKGlobalSearchVM new];
        self.vm.enablePullup = true;
        self.viewModel = self.vm;
    }
    return self;
}

- (void)viewDidLoad {
    
    self.vm.searchType = self.searchType;
    self.vm.channel = self.channel;
    
    [super viewDidLoad];
   
    [self.navigationBar addSubview:self.searchBarView];
    [self.searchBarView addSubview:self.searchBarInput];
    [self.view addSubview:self.tabbar];
    
    [self.searchBarInput becomeFirstResponder];
    
    self.searchBarInput.text = self.keyword;
    self.vm.keyword = self.keyword;
    
    [[WKSDK shared].channelManager addDelegate:self];
    
    self.tabbar.lim_bottom = self.tableView.lim_top;
    
}
- (CGRect)tableViewFrame {
    CGRect rect = [self visibleRect];
    return CGRectMake(0.0f, rect.origin.y + self.tabbar.lim_height + 4.0f, rect.size.width, rect.size.height - self.tabbar.lim_height - 4.0f);
}

- (void)dealloc {
    [[WKSDK shared].channelManager removeDelegate:self];
}

- (UITextField *)searchBarInput {
    if(!_searchBarInput) {
        _searchBarInput = [[UITextField alloc] initWithFrame:CGRectMake(26.0f, 0.0f, self.searchBarView.lim_width - 26.0f, searchBarHeight)];
        _searchBarInput.placeholder = LLang(@"搜索");
        [_searchBarInput addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
        
    }
    return _searchBarInput;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}



- (UIView *)searchBarView {
    if(!_searchBarView) {
        CGFloat statusHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
        _searchBarView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.lim_width - 70.0f, searchBarHeight)];
        _searchBarView.lim_left = 45.0f;
        [_searchBarView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
        _searchBarView.layer.masksToBounds = YES;
        _searchBarView.layer.cornerRadius = 4.0f;
        _searchBarView.lim_top = (self.navigationBar.lim_height-statusHeight)/2.0f - _searchBarView.lim_height/2.0f + statusHeight;
        
        UIImageView *iconImgView = [[UIImageView alloc] initWithImage: [self imageName:@"Common/Index/IconSearch2"]];
        iconImgView.frame = CGRectMake(6.0f, 0.0f, 16.0f, 16.0f);
        iconImgView.lim_top = _searchBarView.lim_height/2.0f - iconImgView.lim_height/2.0f;
        [_searchBarView addSubview:iconImgView];
    }
    return _searchBarView;
}

- (WKTabbar *)tabbar {
    if(!_tabbar) {
        __weak typeof(self) weakSelf = self;
        NSMutableArray<WKTabbarItem*> *items = [NSMutableArray array];
        
        BOOL existFileModule = [WKApp.shared hasMethod:WKPOINT_SEARCH_ITEM_FILE]; // 是否存在文件模块
        [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"聊天") onClick:^{
            [weakSelf.vm changeTabType:@"all"];
        }]];
        
        if(!self.vm.searchInChannel) {
            [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"联系人") onClick:^{
                [weakSelf.vm changeTabType:@"contacts"];
            }]];
            [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"群组") onClick:^{
                [weakSelf.vm changeTabType:@"group"];
            }]];
        }
       
        
        if(self.vm.searchInChannel) { // 在频道内搜才有这个
            [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"图片/视频") onClick:^{
                [weakSelf.vm changeTabType:@"media"];
            }]];
        }
        
        
        if(existFileModule) {
            [items addObject:[[WKTabbarItem alloc] initWithTitle:LLang(@"文件") onClick:^{
                [weakSelf.vm changeTabType:@"file"];
            }]];
        }
        
        CGFloat space = 15.0f;
        _tabbar = [[WKTabbar alloc] initWithItems:items width:WKScreenWidth - space*2];
        
        _tabbar.lim_left = space;
    
    }
    return _tabbar;
}



- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
     [[[UIApplication sharedApplication] keyWindow] endEditing:YES];
}

-(void) viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if(type == WKViewConfigChangeTypeStyle) {
        [_searchBarView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
}


#pragma mark -- 事件

- (void)textFieldEditingChanged:(UITextField *)textField {
    [self.vm changeKeyword:textField.text];
}

// 重写返回事件
-(void) backPressed {
    [[WKNavigationManager shared] popViewControllerAnimated:NO];
}

#pragma mark -- 其他

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

#pragma mark -- WKChannelManagerDelegate

- (void)channelInfoUpdate:(WKChannelInfo *)channelInfo {
    [self reloadData];
}
@end
