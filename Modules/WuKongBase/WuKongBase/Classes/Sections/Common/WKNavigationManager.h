//
//  WKNavigationManager.h
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKNavigationManager : NSObject

+ (WKNavigationManager *)shared;



/// 设置根导航栏
/// @param navigationControllerClass 根导航栏对象
-(void) setRootNavigationController:(Class)navigationControllerClass;
/**
 隐藏导航栏
 */
-(void) setNavigationBarHidden:(BOOL)navigationBarHidden animated:(BOOL)animated;

/**
 重置根目录
 
 @param viewController <#viewController description#>
 */
-(void) resetRootViewController:(UIViewController*)viewController;

// 获取顶部控制器
-(UIViewController*) topViewController;


/**
 获取当前UINavigationItem
 
 @return <#return value description#>
 */
-(UINavigationItem*) currentNavigationItem;


/**
 push view controller

 @param viewController <#viewController description#>
 @param animated <#animated description#>
 */
-(void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;


/// 替换当前并push
/// @param viewController <#viewController description#>
/// @param animated <#animated description#>
-(void) replacePushViewController:(UIViewController*)viewController animated:(BOOL)animated;

-(void) replacePresentViewController:(UIViewController*)viewController animated:(BOOL)animated;

-(void)popViewControllerAnimated:(BOOL)animated;

/// 退出到根实图
/// @param animated <#animated description#>
-(void) popToRootViewControllerAnimated:(BOOL)animated;

-(void) popToViewController:(UIViewController*)viewController animated:(BOOL)animated;

-(void) popToViewControllerClass:(Class)viewControllerClass animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
