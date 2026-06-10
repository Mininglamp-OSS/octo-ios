//
//  WKMePushSettingVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKMePushSettingVC.h"
#import "WKMeCardStyle.h"

@interface WKMePushSettingVC ()<WKMePushSettingDelegate>

@end

@implementation WKMePushSettingVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKMePushSettingVM new];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
}

- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleInsetGrouped;
}

- (NSString *)langTitle {
    return LLang(@"新消息通知");
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    [cell wk_applyMeCardStyleAtIndexPath:indexPath inTableView:tableView];
}

#pragma mark - WKMePushSettingDelegate

- (void)mePushSettingVMRefreshTable:(WKMePushSettingVM *)vm {
    [self reloadData];
}

@end
