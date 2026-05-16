//
//  WKFuncGroupEditVC.m
//  WuKongBase
//
//  Created by tt on 2022/5/5.
//

#import "WKFuncGroupEditVC.h"
#import "WKFuncGroupEditItemCell.h"
#import "WKFuncGroupEditItemModel.h"
#import "WKAPMManager.h"
#define favoriteSectionIndex 0 // 个人收藏的section下标
#define moreSectionIndex 1 // 更多app的section下标

@interface WKFuncGroupEditVC ()<UITableViewDelegate,UITableViewDataSource>

@property(nonatomic,strong) UIButton *editBtn;
@property(nonatomic,strong) UIButton *completeBtn;

@property(nonatomic,strong) UITableView *tableView;


@property(nonatomic,strong) NSMutableArray<NSMutableArray<WKFuncGroupEditItemModel*>*> *items;

@property(nonatomic,strong) NSDictionary<NSString*,WKAPMSortInfo*> *apmSortDict;

@end

@implementation WKFuncGroupEditVC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationBar.lim_top = 0.0f;
    self.navigationBar.lim_height = [WKApp shared].config.navHeight - [UIApplication sharedApplication].statusBarFrame.size.height;
    
    [self.navigationBar addSubview:self.editBtn];
    [self.navigationBar addSubview:self.completeBtn];

    [self.view addSubview:self.tableView];
    
    NSArray<WKAPMSortInfo*> *apmSortInfos =  [WKAPMManager shared].apmSorts;
    if(apmSortInfos && apmSortInfos.count>0) {
        NSMutableDictionary *apmSortMulDict = [NSMutableDictionary dictionary];
        for (WKAPMSortInfo *apmSortInfo in apmSortInfos) {
            apmSortMulDict[apmSortInfo.apmID] = apmSortInfo;
        }
        self.apmSortDict = apmSortMulDict;
    }
    NSArray<WKFuncGroupEditItemModel*> *funcItems = [self funcItems];
    
    NSMutableArray *favrites = [NSMutableArray array];
    NSMutableArray *mores = [NSMutableArray array];
    for (WKFuncGroupEditItemModel *model in funcItems) {
        if(model.type == WKFuncGroupEditItemTypeFavorite) {
            [favrites addObject:model];
        }else {
            [mores addObject:model];
        }
    }
    // 个人收藏
    [self.items addObject:favrites];
    
    // 更多APP
    [self.items addObject:mores];

  
}

- (NSArray<WKFuncGroupEditItemModel*> *)funcItems {
    NSArray<id<WKPanelFuncItemProto>> *funcItems = [[WKApp shared] invokes:WKPOINT_CATEGORY_PANELFUNCITEM param:@{@"context":self.conversationContext}];
    
    NSMutableArray<WKFuncGroupEditItemModel*> *newFuncItems = [NSMutableArray array];
    if(funcItems && funcItems.count>0) {
        for (id<WKPanelFuncItemProto> panelFuncItem in funcItems) {
            if(![[panelFuncItem sid] isEqualToString:@"apm.wukong.more"]) { // 更多不添加到编辑里
                WKFuncGroupEditItemModel *model = [[WKFuncGroupEditItemModel alloc] initWithFuncItem:panelFuncItem];
                WKAPMSortInfo *sortInfo = self.apmSortDict[model.sid];
                if(sortInfo) {
                    model.type = sortInfo.type;
                    model.sort = sortInfo.sort;
                    model.disable = sortInfo.disable;
                }
                [newFuncItems addObject: model];
            }
        }
    }
    [newFuncItems sortUsingComparator:^NSComparisonResult(WKFuncGroupEditItemModel  *obj1, WKFuncGroupEditItemModel *obj2) {
        if(![obj1 allowEdit] && [obj2 allowEdit]) {
            return NSOrderedAscending;
        }
        if([obj1 allowEdit] && ![obj2 allowEdit]) {
            return NSOrderedDescending;
        }
        if([obj1 sort] < [obj2 sort]) {
            return NSOrderedAscending;
        }
        if([obj1 sort] > [obj2 sort]) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
        
    }];
    return newFuncItems;
}

- (NSMutableArray<NSMutableArray<WKFuncGroupEditItemModel*> *> *)items {
    if(!_items) {
        _items = [NSMutableArray array];
    }
    return _items;
}



- (UITableView *)tableView {
    if(!_tableView) {
        CGFloat bottom = [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom;
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0f, self.navigationBar.lim_bottom, self.view.lim_width, self.view.lim_height - bottom - self.navigationBar.lim_bottom - [UIApplication sharedApplication].statusBarFrame.size.height - 20.0f)]; // TODO: 还没搞清楚这里为什么减20.0f,不减在iphone 6s上tableView底部被覆盖
        _tableView.dataSource = self;
        _tableView.delegate = self;
//        _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UIEdgeInsets separatorInset = _tableView.separatorInset;
        separatorInset.right          = 0;
        _tableView.separatorInset = separatorInset;
        _tableView.backgroundColor=[UIColor clearColor];
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(-0.1f, 0.0f, 0.0f, 0.0f);
        _tableView.tableFooterView = [[UIView alloc] init];
        _tableView.estimatedRowHeight = 0;
        _tableView.estimatedSectionHeaderHeight = 0;
        _tableView.estimatedSectionFooterHeight = 0;
        _tableView.sectionHeaderHeight = 0.0f;
        _tableView.sectionFooterHeight = 0.0f;
        
        [_tableView registerClass:WKFuncGroupEditItemCell.class forCellReuseIdentifier:NSStringFromClass(WKFuncGroupEditItemCell.class)];
    }
    return _tableView;
}


- (UIButton *)editBtn {
    if(!_editBtn) {
        _editBtn = [[UIButton alloc] init];
        [_editBtn setTitle:LLang(@"编辑") forState:UIControlStateNormal];
        [_editBtn setTitleColor:[WKApp shared].config.navBarButtonColor forState:UIControlStateNormal];
        [_editBtn sizeToFit];
        _editBtn.lim_left = 15.0f;
        _editBtn.lim_centerY_parent = self.navigationBar;
        [_editBtn addTarget:self action:@selector(editPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _editBtn;
}

-(void) editPressed {
    BOOL  isEditing = [self.tableView isEditing];
    BOOL isComplete = isEditing;
    
    [self.tableView setEditing:!isEditing animated:YES];
    NSArray<NSIndexPath*> *indexPathsForVisibleRows = [self.tableView indexPathsForVisibleRows];
    if(indexPathsForVisibleRows && indexPathsForVisibleRows.count>0) {
        NSMutableArray<NSIndexPath*> *refreshIndexPaths = [NSMutableArray array];
        for (NSIndexPath *indexPath in indexPathsForVisibleRows) {
            if(indexPath.section == moreSectionIndex) {
                [refreshIndexPaths addObject:indexPath];
            }
        }
        if(refreshIndexPaths.count>0) {
            [self.tableView reloadRowsAtIndexPaths:refreshIndexPaths withRowAnimation:UITableViewRowAnimationFade];
        }
       
    }
    
    [self refreshEditTitle];

    if(isComplete) {
        NSMutableArray<WKAPMSortInfo*> *sortInfos = [NSMutableArray array];
        NSInteger k = 0;
        for (NSInteger i=0; i<self.items[favoriteSectionIndex].count; i++) {
            WKFuncGroupEditItemModel *model = self.items[favoriteSectionIndex][i];
            WKAPMSortInfo *sortInfo = [WKAPMSortInfo new];
            sortInfo.type = WKFuncGroupEditItemTypeFavorite;
            sortInfo.apmID = model.sid;
            sortInfo.disable = model.disable;
            sortInfo.sort = k+1;
            [sortInfos addObject:sortInfo];
            
            k++;
        }
        for (NSInteger i=0; i<self.items[moreSectionIndex].count; i++) {
            WKFuncGroupEditItemModel *model = self.items[moreSectionIndex][i];
            WKAPMSortInfo *sortInfo = [WKAPMSortInfo new];
            sortInfo.type = WKFuncGroupEditItemTypeMore;
            sortInfo.apmID = model.sid;
            sortInfo.disable = model.disable;
            sortInfo.sort = k+1;
            [sortInfos addObject:sortInfo];
            
            k++;
        }
        [WKAPMManager shared].apmSorts = sortInfos;
        [[WKAPMManager shared] saveAPMSorts];
    }
}

-(void) refreshEditTitle {
    BOOL  isEditing = [self.tableView isEditing];
    if(isEditing) {
        [self.completeBtn setTitle:@"" forState:UIControlStateNormal];
        [self.editBtn setTitle:LLang(@"完成") forState:UIControlStateNormal];
    }else {
        [self.completeBtn setTitle:LLang(@"完成") forState:UIControlStateNormal];
        [self.editBtn setTitle:LLang(@"编辑") forState:UIControlStateNormal];
    }
    [self.editBtn sizeToFit];
}

- (UIButton *)completeBtn {
    if(!_completeBtn) {
        _completeBtn = [[UIButton alloc] init];
        [_completeBtn setTitle:LLang(@"完成") forState:UIControlStateNormal];
        [_completeBtn setTitleColor:[WKApp shared].config.navBarButtonColor forState:UIControlStateNormal];
        [_completeBtn sizeToFit];
        _completeBtn.lim_centerY_parent = self.navigationBar;
        _completeBtn.lim_left = self.view.lim_width - _editBtn.lim_width - 15.0f;
        [_completeBtn addTarget:self action:@selector(dismissPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return _completeBtn;
}

-(void) dismissPressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void) viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
}


#pragma mark -- UITableViewDelegate & UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WKFuncGroupEditItemModel *item = self.items[indexPath.section][indexPath.row];
    WKFuncGroupEditItemCell *cell =  (WKFuncGroupEditItemCell*)[tableView dequeueReusableCellWithIdentifier:NSStringFromClass(WKFuncGroupEditItemCell.class) forIndexPath:indexPath];
    [cell refresh:item];
    if(indexPath.section == moreSectionIndex) {
        cell.enableSwitch.hidden = !self.tableView.isEditing;
        [cell.enableSwitch setOn:![item disable]];
        [cell setOnSwitch:^(BOOL on) {
            item.disable = !on;
        }];
    }else {
        cell.enableSwitch.hidden = YES;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath  {
    return 50.0f;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == favoriteSectionIndex) {
        NSMutableArray *items = self.items[indexPath.section];
        WKFuncGroupEditItemModel *item = items[indexPath.row];
        return [item allowEdit];
    }
    return NO;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == favoriteSectionIndex) {
        NSMutableArray *items = self.items[indexPath.section];
        WKFuncGroupEditItemModel *item = items[indexPath.row];
        return [item allowEdit];
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if(destinationIndexPath.section == moreSectionIndex) {
        [tableView reloadData];
        return;
    }
    if(sourceIndexPath.item<2) {
        [tableView reloadData];
        return;
    }
    WKFuncGroupEditItemModel *destItem = self.items[destinationIndexPath.section][destinationIndexPath.row];
    if(![destItem allowEdit]) {
        [tableView reloadData];
        return;
    }
    
    NSMutableArray *items = self.items[sourceIndexPath.section];
    WKFuncGroupEditItemModel *obj = [items objectAtIndex:sourceIndexPath.row];
    [items removeObjectAtIndex:sourceIndexPath.row];
    [items insertObject:obj atIndex:destinationIndexPath.row];
    if(destinationIndexPath.section == moreSectionIndex) {
        obj.type = WKFuncGroupEditItemTypeMore;
    }
    [tableView reloadData];
    
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == favoriteSectionIndex) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleInsert;
}
- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == favoriteSectionIndex) {
        UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:LLang(@"从个人收藏中移除") handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
            NSMutableArray *firstItems = self.items[favoriteSectionIndex];
            NSMutableArray *lastItems = self.items[moreSectionIndex];
            WKFuncGroupEditItemModel *item = [firstItems objectAtIndex:indexPath.row];
            [firstItems removeObjectAtIndex:indexPath.row];
            [lastItems insertObject:item atIndex:0];
            item.type = WKFuncGroupEditItemTypeMore;
            [tableView reloadData];
        }];
        deleteAction.backgroundColor = [UIColor colorWithRed:236.0f/255.0f green:84.0f/255.0f blue:69.0f/255.0f alpha:1.0f];
        return @[deleteAction];
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if(editingStyle == UITableViewCellEditingStyleInsert) {
        NSMutableArray *firstItems = self.items[favoriteSectionIndex];
        NSMutableArray *lastItems = self.items[moreSectionIndex];
        WKFuncGroupEditItemModel *item = [lastItems objectAtIndex:indexPath.row];
        [lastItems removeObjectAtIndex:indexPath.row];
        [firstItems addObject:item];
        item.type = WKFuncGroupEditItemTypeFavorite;
    }
    [self.tableView reloadData];
}

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
//    if(section == 0) {
//        return LLang(@"个人收藏");
//    }else if(section == 1) {
//        return LLang(@"更多APP");
//    }
//    return @"";
//}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    CGFloat height = [self tableView:tableView heightForHeaderInSection:section];
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, height)];
    UILabel *titleLbl = [[UILabel alloc] init];
    NSString *title = @"";
    if(section == 0) {
        title = LLang(@"个人收藏");
    }else if(section == 1) {
        title = LLang(@"更多APP");
    }
    titleLbl.text = title;
    titleLbl.font = [[WKApp shared].config appFontOfSizeSemibold:20.0f];
    [titleLbl sizeToFit];
    titleLbl.lim_left = 10.0f;
    titleLbl.textColor = [WKApp shared].config.tipColor;
    titleLbl.lim_centerY_parent = headerView;
    [headerView addSubview:titleLbl];
    [headerView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40.0f;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.items.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.items[section].count;
}

@end
