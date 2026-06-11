//
//  WKCommonSettingVC.m
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import "WKCommonSettingVC.h"
#import "WKCommonSettingVM.h"
#import "WKActionSheetView2.h"
#import "WKMeCardStyle.h"
@interface WKCommonSettingVC ()

@end

@implementation WKCommonSettingVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKCommonSettingVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LLang(@"通用");
    self.view.backgroundColor = [WKApp shared].config.backgroundColor;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(realnameUpdated:)
                                                 name:WKNOTIFY_REALNAME_VERIFIED
                                               object:nil];
}

- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleInsetGrouped;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    [cell wk_applyMeCardStyleAtIndexPath:indexPath inTableView:tableView];
}

- (void)realnameUpdated:(NSNotification*)noti {
    [self reloadData];
}


- (void)viewConfigChange:(WKViewConfigChangeType)type {
    [super viewConfigChange:type];
    if(type == WKViewConfigChangeTypeLang) {
        self.title = LLang(@"通用");
        [self reloadData];
    }

}

#pragma mark - WKCommonSettingVMDelegate
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    WKLogDebug(@"WKCommonSettingVC dealloc!");
}

@end
