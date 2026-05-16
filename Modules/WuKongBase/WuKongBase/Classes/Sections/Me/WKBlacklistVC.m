//
//  WKBlacklistVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/26.
//

#import "WKBlacklistVC.h"
#import "WKBlacklistCell.h"
#import "WKChineseSort.h"
#import "WKUserInfoVC.h"
@interface WKBlacklistVC ()<UITableViewDataSource,UITableViewDelegate>
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) NSArray *sectionTitleArr; //排序后的出现过的拼音首字母数组
@property(nonatomic,strong) NSMutableArray<NSArray*> *items;
@end

@implementation WKBlacklistVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.items = [NSMutableArray array];
    [self.view addSubview:self.tableView];
    [self requestData];
    
}

- (NSString *)langTitle {
    return LLang(@"黑名单");
}

-(void) requestData {
    self.items = [NSMutableArray array];
    self.sectionTitleArr = @[];
    // 查询黑名单的频道数据
    NSArray<WKChannelInfo*> *blacklist = [[WKChannelInfoDB shared] queryChannelInfosWithStatus:WKChannelStatusBlacklist];
    NSMutableArray *items = [NSMutableArray array];
    if(blacklist) {
        for (WKChannelInfo *channelInfo in blacklist) {
            WKBlacklistModel *model = [[WKBlacklistModel alloc] init];
            model.name = channelInfo.name;
            model.uid = channelInfo.channel.channelId;
            [items addObject:model];
        }
    }
    if(items.count>0) {
        [self sortAndGroup:items];
    }
}

// 联系人排序和分组
-(void) sortAndGroup:(NSArray*)items{
    __weak typeof(self) weakSelf = self;
    [WKChineseSort sortAndGroup:items key:@"name" finish:^(bool isSuccess, NSMutableArray *unGroupArr, NSMutableArray *sectionTitleArr, NSMutableArray<NSMutableArray *> *sortedObjArr) {
        if(isSuccess) {
            weakSelf.sectionTitleArr = sectionTitleArr;
            [weakSelf.items addObjectsFromArray:sortedObjArr];
            [weakSelf.tableView reloadData];
        }
    }];
}

-(UITableView *)tableView{
    if(!_tableView){
        _tableView = [[UITableView alloc] initWithFrame:[self visibleRect]];
        [_tableView setBackgroundColor:[UIColor redColor]];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        UIEdgeInsets separatorInset   = _tableView.separatorInset;
        separatorInset.right          = 0;
        _tableView.separatorInset = separatorInset;
        _tableView.backgroundColor=[UIColor clearColor];
        
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [_tableView registerClass:WKBlacklistCell.class forCellReuseIdentifier:[WKBlacklistCell cellId]];
        
    }
    return _tableView;
}


#pragma mark UITableDataSource && UITableViewDelegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return  self.items[section].count;;
}
-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKBlacklistModel *model =  self.items[indexPath.section][indexPath.row];
    WKBlacklistCell *cell =  [tableView dequeueReusableCellWithIdentifier:[WKBlacklistCell cellId]];
    [cell refresh:model];
    return cell;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return  60.0;
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  
    return 20.0f;
}
-(UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    NSString *title = [self.sectionTitleArr objectAtIndex:section];
    return [self headView:title headHeight:20.0f color:[UIColor grayColor]];
}

//点击右侧索引表项时调用 索引与section的对应关系
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return index;
}
//
//section右侧index数组
-(NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView{
    return self.sectionTitleArr;
}
//
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return self.sectionTitleArr.count;
}
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WKBlacklistModel *model =  self.items[indexPath.section][indexPath.row];
    WKUserInfoVC *vc = [WKUserInfoVC new];
    vc.uid = model.uid;
    [[WKNavigationManager shared] pushViewController:vc animated:YES];
   
}

// 头部字母部分
-(UIView*) headView:(NSString*)title headHeight:(CGFloat)headHheght color:(UIColor*)color{
    
    UIView *headView =[[UIView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, headHheght)];
    [headView setBackgroundColor: [WKApp shared].config.backgroundColor];
    UILabel  *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, headView.lim_width, headView.lim_height)];
    [titleLbl setFont:[[WKApp shared].config appFontOfSize:14.0f]];
    [titleLbl setTextColor:color];
    [titleLbl setText:title];
    [headView addSubview:titleLbl];
    return headView;
}


@end
