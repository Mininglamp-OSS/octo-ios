//
//  ATKitSearchController.m
//  WuKongBase
//
//  Created by tt on 2019/12/31.
//

#import "WKSearchController.h"

@interface WKSearchController ()

@end

@implementation WKSearchController

-(instancetype) initWithSearchResultsController:(UIViewController *)searchResultsController{
    self = [super initWithSearchResultsController:searchResultsController];
    if (!self) return nil;
    
    [self defaultStyle];
    return self;
}

-(instancetype) init{
    self = [super init];
    if(!self) return nil;
    [self defaultStyle];
    return self;
}

-(void) defaultStyle {
    self.searchBar.searchBarStyle =UISearchBarStyleProminent;
    self.searchBar.backgroundColor =[UIColor colorWithRed:239.0f/255.0f green:239.0f/255.0f blue: 244.0f/255.0f alpha:1.0];// 设置搜索框背景颜色
    self.searchBar.barTintColor=[UIColor colorWithRed:239.0f/255.0f green:239.0f/255.0f blue: 244.0f/255.0f alpha:1.0];

    [self.searchBar setBackgroundImage:[UIImage new]];
     
    if (@available(iOS 13.0, *)) {
        [self.searchBar searchTextField].layer.backgroundColor = [UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0f].CGColor;
        [self.searchBar searchTextField].backgroundColor = [UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0f];
    } else {
        // Fallback on earlier versions
    }
    
    //  self.dimsBackgroundDuringPresentation = NO;
    
    self.hidesNavigationBarDuringPresentation = YES;
    
    [self.searchBar sizeToFit];
    
    self.searchBar.returnKeyType = UIReturnKeyDone;
    
    
    if (@available(iOS 11.0, *)){
        [self.searchBar setPositionAdjustment:UIOffsetMake((self.searchBar.frame.size.width-100)/2, 0) forSearchBarIcon:UISearchBarIconSearch];
    }
}

-(UIView*) searchBarView{
//    UIView *searchBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, self.searchBar.frame.size.height)];
//    [searchBarView addSubview:self.searchBar];
    return self.searchBar;
}


@end
