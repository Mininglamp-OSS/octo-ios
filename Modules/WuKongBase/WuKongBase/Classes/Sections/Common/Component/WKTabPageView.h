//
//  WKTabPageView.h
//  WuKongBase
//
//  Created by tt on 2020/1/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class WKTabPageView;
@protocol WKTabPageViewDelegate <NSObject>


/**
 获取指定下标的正文视图
 
 @param tabPageView <#tabPageView description#>
 @param suggestContentFrame 建议正文视图的frame
 @param index 下标
 @return 正文视图
 */
-(UIView*) tabPageView:(WKTabPageView*) tabPageView suggestContentFrame:(CGRect)suggestContentFrame atIndex:(NSInteger)index;


/**
 获取指定下标的tab视图
 
 @param tabPageView <#tabPageView description#>
 @param suggestTabFrame 建议bar的frame
 @param index 下标
 @return bar视图
 */
-(UIView*) tabPageView:(WKTabPageView*)tabPageView suggestTabFrame:(CGRect)suggestTabFrame atIndex:(NSInteger) index;


/**
tab数量

 @param tabPageView <#tabPageView description#>
 @return <#return value description#>
 */
-(NSInteger) numOfTabPageView:(WKTabPageView*)tabPageView;


/**
 发送

 @param tabPageView <#tabPageView description#>
 */
-(void) didSendOfTabPageView:(WKTabPageView*)tabPageView;

// 选中
-(void) didSelectOfTabPageView:(WKTabPageView*)tabPageView index:(NSInteger)index;

@end

@interface WKTabPageView : UIView

@property(nonatomic,weak) id<WKTabPageViewDelegate> delegate;

// tabbarScrollView 左边距离
@property(nonatomic,assign) CGFloat tabbarScrollViewLeftSpace;
@property(nonatomic,strong) UIScrollView *tabbarScrollView;

@property(nonatomic,assign) BOOL preloadOff; // 是否关闭预加载

- (NSInteger)currentPage;


/**
 重新加载tabpageView
 */
-(void) reloadTabPageView;

@end



NS_ASSUME_NONNULL_END
