//
//  SwipeTableCell.h
//  WuKongBase
//
//  Created by tt on 2021/8/10.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>
#import "SwipeButton.h"
#import "SwipeView.h"


typedef NS_ENUM(NSUInteger, SwipeTableCellStyle)
{
    SwipeTableCellStyleRightToLeft = 0, /**< 右滑*/
    SwipeTableCellStyleLeftToRight , /**< 左滑*/
    SwipeTableCellStyleBoth, /**< 左滑、右滑都有*/
};

@protocol SwipeTableViewCellDelegate <NSObject>

@required
/**
 *  设置cell的滑动按钮的样式 左滑、右滑、左滑右滑都有
 *
 *  @param indexPath cell的位置
 */
- (SwipeTableCellStyle)tableView:(UITableView *)tableView styleOfSwipeButtonForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 *  左滑cell时显示的button
 *
 *  @param indexPath cell的位置
 */
- (NSArray<SwipeButton *> *)tableView:(UITableView *)tableView leftSwipeButtonsAtIndexPath:(NSIndexPath *)indexPath;

/**
 *  右滑cell时显示的button
 *
 *  @param indexPath cell的位置
 */
- (NSArray<SwipeButton *> *)tableView:(UITableView *)tableView rightSwipeButtonsAtIndexPath:(NSIndexPath *)indexPath;

@optional
/**
 *  当滑动手势结束后，点击cell是否隐藏swipeView，即cell自动回复到最初状态。默认YES
 */
- (BOOL)tableView:(UITableView *)tableView hiddenSwipeViewWhenTapCellAtIndexpath:(NSIndexPath *)indexPath;

/**
 *  设置swipeView的弹出样式
 */
- (SwipeViewTransfromMode)tableView:(UITableView *)tableView swipeViewTransformModeAtIndexPath:(NSIndexPath *)indexPath;

@end




@class SwipeTableViewDelegate;
@interface SwipeTableCell : UITableViewCell

@property (nonatomic, weak) id<SwipeTableViewCellDelegate> swipeDelegate;
@property (nonatomic, assign) BOOL isAllowMultipleSwipe; /**< 是否允许多个cell同时滑动*/
@property (nonatomic, assign) CGFloat swipeThreshold;/**< 当结束滑动手势时，显示或隐藏按钮的临界值 范围:0-1，默认0.5*/

@property (nonatomic, assign) SwipeViewTransfromMode transformMode; /**< swipeView的弹出效果*/
@property (nonatomic, assign) BOOL hideSwipeViewWhenScrollCell; /**< 滚动cell时是否隐藏swipeView 默认YES*/
@property (nonatomic, assign) BOOL isRefreshButton;
@property (nonatomic, assign) BOOL enableSwipe;                 //是否支持滑动手势

- (void)refreshButtonsWithTitle:(NSString *)title;

@property (nonatomic, strong) UIView *swipeOverlayView; /**< 滑动时覆盖在cell上*/
- (void)hiddenSwipeAnimationAtCell:(BOOL)isAnimation;
@end
