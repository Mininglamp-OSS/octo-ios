//
//  WKRootNavigationController.m
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import "WKRootNavigationController.h"

@interface WKRootNavigationController ()<UINavigationControllerDelegate,UIGestureRecognizerDelegate>

@end

@implementation WKRootNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.delegate = self;
    self.navigationBar.hidden = YES;
    [self.navigationBar setTranslucent:NO];
    // iOS 26 Liquid Glass:
    //   即使 navigationBar.hidden = YES,系统仍会为 UINavigationBar 创建一个
    //   FloatingBarHostingView<FloatingBarContainer> 作为其 hosting 容器并保留在
    //   view hierarchy 顶部 (frame 一般为整个 self.view bounds)。view inspector
    //   里它显示透明,但内部挂着 Liquid Glass backdrop layer,会对下方像素做模糊
    //   采样,在 App 自绘的 WKNavigationBar 之外的区域 (如聊天详情第一条消息和
    //   nav bar 之间) 形成可见的"遮挡带"。
    //
    //   App 自己用 WKNavigationBar (普通 UIView) 全权接管头部,系统 nav bar 不
    //   需要任何材质。把 standardAppearance / scrollEdgeAppearance / compact*
    //   全部置为 transparent + clear color + 空 image,backdrop 渲染层跑空,
    //   FloatingBarHostingView 依然存在但不再吃下方像素。同套思路见 tabbar 的
    //   463cb8e。
    if (@available(iOS 26.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = [UIColor clearColor];
        appearance.shadowColor = [UIColor clearColor];
        appearance.backgroundImage = [UIImage new];
        appearance.shadowImage = [UIImage new];
        self.navigationBar.standardAppearance = appearance;
        self.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationBar.compactAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.navigationBar.compactScrollEdgeAppearance = appearance;
        }
        // 老 API 兜底,防系统某些路径回退到非透明
        self.navigationBar.barTintColor = [UIColor clearColor];
        [self.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.shadowImage = [UIImage new];
    }
   // self.navigationBar.hidden = NO;
    //去除导航栏下方的横线
//    [self.navigationBar setBackgroundImage:[[UIImage alloc]init]
//                                                  forBarMetrics:UIBarMetricsDefault];
//    [self.navigationBar setShadowImage:[[UIImage alloc]init]];

    __weak typeof(self) weakSelf = self;

    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {

        self.interactivePopGestureRecognizer.delegate = weakSelf;
    }
}


-(BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    if (self.navigationController.viewControllers.count == 1) {
        return NO;
    }else{
        return YES;
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated{

    if ([navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        navigationController.interactivePopGestureRecognizer.enabled = YES;
    }
    //使navigationcontroller中第一个控制器不响应右滑pop手势
    if (navigationController.viewControllers.count == 1) {
        navigationController.interactivePopGestureRecognizer.enabled = NO;
        navigationController.interactivePopGestureRecognizer.delegate = nil;
    }
}
- (UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleDefault;
}


-(void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.enabled = NO;
    }
    [super pushViewController:viewController animated:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
