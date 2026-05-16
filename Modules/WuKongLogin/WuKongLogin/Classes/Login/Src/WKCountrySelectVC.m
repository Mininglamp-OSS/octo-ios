//
//  WKCountrySelectVC.m
//  WuKongLogin
//
//  Created by tt on 2020/6/8.
// 国家区号选择器
#import "NSString+PinYin.h"
#import "WKCountrySelectVC.h"

#define searchHeight 36.0f

@interface WKCountrySelectVC ()<UITableViewDelegate,UITableViewDataSource,UISearchBarDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonnull,strong) NSArray *data; // 列表数据
@property(nonatomic, strong) UIView *closeView; // 取消按钮
@property(nonatomic,strong) UISearchBar *searchBar;
@property(nonatomic,copy) NSString *searchKeyword; // 搜索关键字

@end

@implementation WKCountrySelectVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = LLang(@"选择国家和地区");
    
    [self.view addSubview:self.searchBar];
    [self.view addSubview:self.tableView];
    
    [self refreshData];
    // 请求国家列表并且刷新数据
    [self requestCountriesAndRefreshData];
    self.navigationItem.leftBarButtonItem =  [[UIBarButtonItem alloc] initWithCustomView:self.closeView];
   
}


// 请求国家列表并且刷新数据
-(void) requestCountriesAndRefreshData {
    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:@"common/countries" parameters:nil].then(^(NSArray*data){
           // 缓存下来
           [[NSUserDefaults standardUserDefaults] setObject:data
                                                     forKey:@"countriesList"];
           [[NSUserDefaults standardUserDefaults] synchronize];
           [weakSelf refreshData];
    }).catch(^(NSError *error){
           WKLogError(@"请求国家区号失败！-> %@",error);
    });
}

-(void) refreshData {
    NSArray *array =
    [[NSUserDefaults standardUserDefaults] objectForKey:@"countriesList"];
    NSMutableArray *filterArray = [[NSMutableArray alloc] init];
    if(self.searchKeyword && ![[self.searchKeyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""]) {
        for (NSDictionary *data in array) {
            NSString *name = data[@"name"];
            if([name containsString:self.searchKeyword]) {
                [filterArray addObject:data];
            }
        }
    }else {
        [filterArray addObjectsFromArray:array];
    }
    NSArray *indexArray = [filterArray arrayWithPinYinFirstLetterFormat];
    self.data = [NSMutableArray arrayWithArray:indexArray];
    [self.tableView reloadData];
}

#pragma mark -- 视图初始化
- (UITableView *)tableView {
    if(!_tableView) {
        CGFloat navHeight =  self.navigationController.navigationBar.lim_height;
        CGFloat statusHeight =  [UIApplication sharedApplication].statusBarFrame.size.height;
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0f, self.searchBar.lim_bottom+15.0f, self.view.lim_width, self.view.lim_height-navHeight - statusHeight - searchHeight-15.0f) style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [_tableView registerClass:[UITableViewCell class]
        forCellReuseIdentifier:@"cellID"];
    }
    return _tableView;
}

- (UIView *)closeView {
    if (!_closeView) {
        _closeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        _closeView.backgroundColor = [UIColor clearColor];
        UIButton *closeBtn = [[UIButton alloc] init];
        [closeBtn setTitle:LLang(@"取消") forState:UIControlStateNormal];
        [[closeBtn titleLabel] setTextColor:WKApp.shared.config.defaultTextColor];
        [closeBtn setTitleColor:WKApp.shared.config.defaultTextColor forState:UIControlStateNormal];
        [closeBtn addTarget:self
                      action:@selector(closePressed)
            forControlEvents:UIControlEventTouchUpInside];
        [closeBtn sizeToFit];
        closeBtn.lim_left = 0;
        closeBtn.lim_top = 40 / 2 - closeBtn.lim_height / 2;
        [_closeView addSubview:closeBtn];
    }
    return _closeView;
}

- (UISearchBar *)searchBar {
    if(!_searchBar) {
        _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(15.0f,self.navigationBar.lim_bottom+15.0f,self.view.lim_width - 30.0f, searchHeight)];
//        _searchBar.searchBarStyle = UISearchBarStyleProminent;
        _searchBar.placeholder = LLang(@"搜索");
        [_searchBar setBackgroundColor:[WKApp shared].config.backgroundColor];
        [_searchBar setBackgroundImage:[UIImage new]];
        _searchBar.layer.masksToBounds = YES;
        _searchBar.layer.cornerRadius = 8.0f;
        _searchBar.delegate = self;
        
        if (@available(iOS 13.0, *)) {
           
            [_searchBar searchTextField].layer.backgroundColor = WKApp.shared.config.backgroundColor.CGColor;
            [_searchBar searchTextField].backgroundColor = WKApp.shared.config.backgroundColor;
        } else {
            // Fallback on earlier versions
        }
    }
    return _searchBar;
}


#pragma mark -- 委托

#pragma mark -- UITableViewDelegate && UITableViewDataSource
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.view endEditing:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"cellID"];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    NSDictionary *dict = self.data[indexPath.section];
    NSMutableArray *array = dict[@"content"];
    NSString *code = array[indexPath.row][@"code"];
    code = [code stringByReplacingCharactersInRange:NSMakeRange(0, 2) withString:@"+"];
    cell.textLabel.text =
        [NSString stringWithFormat:@"%@ (%@)", array[indexPath.row][@"name"],
                                   code];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return [self.data count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *dict = self.data[section];
    NSMutableArray *array = dict[@"content"];
    return [array count];
}
- (UIView *)tableView:(UITableView *)tableView
    viewForHeaderInSection:(NSInteger)section {
  //自定义Header标题
  UIView *myView = [[UIView alloc] init];
    myView.backgroundColor =WKApp.shared.config.cellBackgroundColor;
  UILabel *titleLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 90, 22)];
  titleLabel.textColor = WKApp.shared.config.defaultTextColor;

  NSString *title = self.data[section][@"firstLetter"];
  titleLabel.text = title;
  [myView addSubview:titleLabel];
    
    titleLabel.lim_top = 3.0f;

  return myView;
}

//添加TableView头视图标题
- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  NSDictionary *dict = self.data[section];
  NSString *title = dict[@"firstLetter"];
  return title;
}
//添加索引栏标题数组
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
  NSMutableArray *resultArray =
      [NSMutableArray arrayWithObject:UITableViewIndexSearch];
  for (NSDictionary *dict in self.data) {
    NSString *title = dict[@"firstLetter"];
    [resultArray addObject:title];
  }
  return resultArray;
}

//点击索引栏标题时执行
- (NSInteger)tableView:(UITableView *)tableView
    sectionForSectionIndexTitle:(NSString *)title
                        atIndex:(NSInteger)index {
  //这里是为了指定索引index对应的是哪个section的，默认的话直接返回index就好。其他需要定制的就针对性处理
  if ([title isEqualToString:UITableViewIndexSearch]) {
    [tableView setContentOffset:CGPointZero animated:NO]; // tabview移至顶部
    return NSNotFound;
  } else {
    return [[UILocalizedIndexedCollation currentCollation]
               sectionForSectionIndexTitleAtIndex:index] -
           1; // -1 添加了搜索标识
  }
}
- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(self.onFinished) {
        NSDictionary *dict = self.data[indexPath.section];
        NSMutableArray *array = dict[@"content"];
        NSDictionary *data = array[indexPath.row];
        [self dismissViewControllerAnimated:YES completion:nil];
        self.onFinished(data);
        
    }
 
}

#pragma mark -- UISearchBarDelegate
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchKeyword = searchText;
    [self refreshData];
}

#pragma mark -- 事件
-(void) closePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
