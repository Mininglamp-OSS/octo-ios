//
//  WKPageView.h
//  WuKongBase
//
//  Created by tt on 2020/1/10.
//

#import <UIKit/UIKit.h>
@class WKPageView;

@protocol WKPageViewDataSource <NSObject>
- (NSInteger)numberOfPages: (WKPageView *)pageView;
- (UIView *)pageView: (WKPageView *)pageView viewInPage: (NSInteger)index;
@end

@protocol WKPageViewDelegate <NSObject>
@optional
- (void)pageViewScrollEnd: (WKPageView *)pageView
             currentIndex: (NSInteger)index
               totolPages: (NSInteger)pages;

- (void)pageViewDidScroll: (WKPageView *)pageView;
- (BOOL)needScrollAnimation;
@end


@interface WKPageView : UIView<UIScrollViewDelegate>
@property (nonatomic,strong)    UIScrollView   *scrollView;
@property (nonatomic,weak)    id<WKPageViewDataSource>  dataSource;
@property (nonatomic,weak)    id<WKPageViewDelegate>    pageViewDelegate;

@property(nonatomic,assign) BOOL preloadOff; // 是否关闭预加载
- (void)scrollToPage: (NSInteger)pages;
- (void)reloadData;
- (UIView *)viewAtIndex: (NSInteger)index;
- (NSInteger)currentPage;


//旋转相关方法,这两个方法必须配对调用,否则会有问题
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration;

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration;
@end
