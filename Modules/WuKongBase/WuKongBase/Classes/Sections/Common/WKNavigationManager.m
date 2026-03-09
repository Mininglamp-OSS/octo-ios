//
//  WKNavigationManager.m
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import "WKNavigationManager.h"
#import "WKRootNavigationController.h"

@interface WKNavigationManager ()

@property(nonatomic,strong) Class rootNavigationControllerClass;

@end

@implementation WKNavigationManager


static WKNavigationManager *_instance = nil;

static UINavigationController *_rootNavigationController;



+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(void) setRootNavigationController:(Class)navigationControllerClass {
    self.rootNavigationControllerClass = navigationControllerClass;
}

-(void) setNavigationBarHidden:(BOOL)navigationBarHidden animated:(BOOL)animated{
    
    [_rootNavigationController setNavigationBarHidden:navigationBarHidden animated:animated];
}

-(void) resetRootViewController:(UIViewController*)viewController{
    if(self.rootNavigationControllerClass) {
        _rootNavigationController = [[self.rootNavigationControllerClass alloc] initWithRootViewController:viewController];
    }else{
        _rootNavigationController = [[WKRootNavigationController alloc] initWithRootViewController:viewController];
    }
    
    [UIApplication sharedApplication].delegate.window.rootViewController = _rootNavigationController;
}

-(UINavigationItem*) currentNavigationItem{
    UIViewController *topViewControllers = _rootNavigationController.topViewController;
    return  topViewControllers.navigationItem;
}

-(UIViewController*) topViewController{
    
    return [_rootNavigationController topViewController];
}

-(void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [_rootNavigationController pushViewController:viewController animated:animated];
}

-(void) replacePushViewController:(UIViewController*)viewController animated:(BOOL)animated {
   NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:_rootNavigationController.viewControllers];
    [viewControllers removeLastObject];
    [viewControllers addObject:viewController];
    [_rootNavigationController setViewControllers:viewControllers animated:animated];
}
-(void) replacePresentViewController:(UIViewController*)viewController animated:(BOOL)animated {
   NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:_rootNavigationController.viewControllers];
    [viewControllers removeLastObject];
    [_rootNavigationController setViewControllers:viewControllers animated:NO];
    [[self topViewController] presentViewController:viewController animated:animated completion:nil];
}
-(void)popViewControllerAnimated:(BOOL)animated {
    [_rootNavigationController popViewControllerAnimated:animated];
}

-(void) popToRootViewControllerAnimated:(BOOL)animated {
    [_rootNavigationController popToRootViewControllerAnimated:animated];
}

-(void) popToViewController:(UIViewController*)viewController animated:(BOOL)animated  {
    [_rootNavigationController popToViewController:viewController animated:animated];
    
}

-(void) popToViewControllerClass:(Class)viewControllerClass animated:(BOOL)animated {
   NSArray *vcs =  _rootNavigationController.viewControllers;
    if(vcs) {
        for (UIViewController *vc in vcs) {
            if([vc isKindOfClass:viewControllerClass]) {
                [self popToViewController:vc animated:animated];
                return;
            }
        }
    }
}

@end
