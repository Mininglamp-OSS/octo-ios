//
//  WKContactsAddVC.m
//  WuKongContacts
//
//  Created by tt on 2019/12/31.
//

#import "WKContactsAddVC.h"
#import <WuKongBase/WuKongBase.h>
#import <WuKongBase/WKSearchController.h>
#import "WKContactsVM.h"
#import "WKContactsInfoVC.h"
#import "WKSearchbarView.h"
#import "WKContactsSearchVC.h"
@interface WKContactsAddVC ()
@property(nonatomic,strong) WKSearchbarView *searchbarView;
@end

@implementation WKContactsAddVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [WKContactsVM new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableHeaderView = self.searchbarView;
    
}

- (NSString *)langTitle {
    return LLang(@"添加朋友");
}

- (WKSearchbarView *)searchbarView {
    if(!_searchbarView) {
        _searchbarView = [[WKSearchbarView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, WKScreenWidth, 40.0f)];
        _searchbarView.placeholder = LLang(@"搜索");
        _searchbarView.onClick = ^{
            [[WKNavigationManager shared] pushViewController:[WKContactsSearchVC new] animated:NO];
        };
        
    }
    return _searchbarView;
}


//- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
//    __weak typeof(self) weakSelf = self;
//    [self.contactsVM searchFriend:searchBar.text].then(^(WKUserSearchResp *resp){
//        if(!resp.exist) {
//            [weakSelf.view showMsg:@"用户不存在！"];
//            return;
//        }
//        [[WKApp shared] invoke:WKPOINT_CONTACTSINFO_SHOW param:@{@"uid":resp.user.uid}];
//    });
//}

@end
