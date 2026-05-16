//
//  UIViewController+YJKeyBoard.h
//  一行代码解决iOS键盘遮挡问题

#import <UIKit/UIKit.h>

@interface UIViewController (YJKeyBoard)

//自动处理键盘遮挡方法
- (void)yj_addKeyBoardHandle;

/**
 根据键盘来移动的控件（可选项）
 默认是self.view改变origin.y来移动
 若设置为scrollView，则scrollView滚动
 */
@property (nonatomic, strong) UIView *yj_needScrollView;

//控件所移动的总距离（只读）
@property (nonatomic, assign, readonly) CGFloat yj_moveDistance;
//焦点所在的控件相对窗口的最低点（只读）
@property (nonatomic, assign, readonly) CGFloat yj_currentEditViewBottom;

@end
