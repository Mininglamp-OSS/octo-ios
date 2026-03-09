//
//  WKGlobalSearchController.m
//  WuKongBase
//
//  Created by tt on 2020/4/24.
//

#import "WKGlobalSearchController.h"
#import "WKGlobalSearchResultController.h"
@interface WKGlobalSearchController ()<UISearchControllerDelegate>

@property(nonatomic,strong) WKGlobalSearchResultController *searchResultController;
@end

@implementation WKGlobalSearchController

-(instancetype) initWithSearchResultsController:(WKGlobalSearchResultController *)searchResultsController{
    self = [super initWithSearchResultsController:searchResultsController];
    self.searchResultController = searchResultsController;
    if (!self) return nil;
    [self defaultStyle];
    return self;
}
-(void) defaultStyle {
    self.searchBar.frame = CGRectMake(10.0f, 0.0f, WKScreenWidth-20.0f, 44.0f);
    [self.searchBar setBackgroundImage:[UIImage new]];
    self.searchBar.backgroundColor =[WKApp shared].config.backgroundColor;// 设置搜索框背景颜色
    self.searchBar.barTintColor=[WKApp shared].config.backgroundColor;
    self.searchBar.searchBarStyle =UISearchBarStyleProminent;
    [self.searchBar setPlaceholder:LLang(@"搜索")];
    
    if (@available(iOS 13.0, *)) {
        [self.searchBar searchTextField].layer.backgroundColor = [UIColor whiteColor].CGColor;
        [self.searchBar searchTextField].backgroundColor = [UIColor whiteColor];
        [self.searchBar searchTextField].layer.masksToBounds = YES;
        [self.searchBar searchTextField].layer.cornerRadius = 4.0f;
       } else {
           // Fallback on earlier versions
       }
    
    
    //UIImageView *barImageView = [[[self.searchBar.subviews firstObject] subviews] firstObject];
   // barImageView.layer.borderColor = [UIColor colorWithRed:239.0f/255.0f green:239.0f/255.0f blue: 244.0f/255.0f alpha:1.0].CGColor;
  //  barImageView.layer.borderWidth = 1;
    
    self.dimsBackgroundDuringPresentation = YES;
    
    [self.searchBar sizeToFit];
    
    self.searchBar.returnKeyType = UIReturnKeyDone;
    
    
//    if (@available(iOS 11.0, *)){
//        [self.searchBar setPositionAdjustment:UIOffsetMake((self.searchBar.frame.size.width-100)/2, 0) forSearchBarIcon:UISearchBarIconSearch];
//    }
}

-(void) refreshSearchbar {
    [self defaultStyle];
}

+(instancetype) searchController{
    WKGlobalSearchController *controller = [[WKGlobalSearchController alloc] initWithSearchResultsController:[WKGlobalSearchResultController new]];
    return controller;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.searchResultsUpdater = self.searchResultController;
}



@end
