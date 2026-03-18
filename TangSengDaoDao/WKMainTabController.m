//
//  WKMainTabController.m
//  TangSengDaoDao
//
//  Created by tt on 2019/12/7.
//  Copyright © 2019 xinbida. All rights reserved.
//

#import "WKMainTabController.h"
#import <WuKongBase/WuKongBase.h>
#import <Lottie/Lottie.h>
#import <CoreImage/CoreImage.h>
#import "WKConversationListVC.h"
#import "WKContactsVC.h"
#import "WKMeVC.h"
@interface WKMainTabController ()<UITabBarControllerDelegate>

@property(nonatomic,strong) LOTAnimationView *currentLOTAnimationView;

@end

@implementation WKMainTabController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
    // Do any additional setup after loading the view.
    [self.tabBar setBarTintColor:[UIColor whiteColor]];
    
    [[UITabBar appearance] setShadowImage:[[UIImage alloc]init]];
    [[UITabBar appearance] setBackgroundImage:[[UIImage alloc]init]];
    if (@available(iOS 13.0, *)) {
        [self.tabBar setBarTintColor:[UIColor systemBackgroundColor]];
        [self.tabBar setBackgroundColor:[UIColor systemBackgroundColor]];
    } else {
        [self.tabBar setBarTintColor:[UIColor whiteColor]];
        [self.tabBar setBackgroundColor:[UIColor whiteColor]];
    }
   
    self.tabBar.tintColor = [WKApp shared].config.themeColor;

    [self setupChildVC:WKConversationListVC.class title:@"" andImage:@"HomeTab" andSelectImage:@"HomeTabSelected"];
    [self setupChildVC:WKContactsVC.class title:@"" andImage:@"ContactsTab" andSelectImage:@"ContactsTabSelected"];
    [self setupChildVC:WKMeVC.class title:@"" andImage:@"MeTab" andSelectImage:@"MeTabSelected"];

}

/// 色相旋转：将图片从橘色调转为紫色调，保留透明度和亮度层次
- (UIImage *)hueRotateImage:(UIImage *)image angle:(CGFloat)angleInRadians {
    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    if (!ciImage) return image;
    CIFilter *filter = [CIFilter filterWithName:@"CIHueAdjust"];
    [filter setValue:ciImage forKey:kCIInputImageKey];
    [filter setValue:@(angleInRadians) forKey:@"inputAngle"];
    CIImage *output = filter.outputImage;
    if (!output) return image;
    CIContext *ctx = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [ctx createCGImage:output fromRect:output.extent];
    if (!cgImage) return image;
    UIImage *result = [UIImage imageWithCGImage:cgImage scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cgImage);
    return result;
}

- (void)setupChildVC:(Class)vc title:(NSString *)title andImage:(NSString * )image andSelectImage:(NSString *)selectImage{

    UIViewController * vcInstall = [[vc alloc] init];
    vcInstall.tabBarItem.title = title;

    // 橘色 ≈ 30°，紫色 ≈ 270°，色相旋转约 240° = 4.19 弧度
    CGFloat hueShift = 240.0 * M_PI / 180.0;

    // 未选中：色相旋转后整体降低透明度
    UIImage *unselectedImg = [self hueRotateImage:[UIImage imageNamed:image] angle:hueShift];
    UIGraphicsBeginImageContextWithOptions(unselectedImg.size, NO, unselectedImg.scale);
    [unselectedImg drawInRect:CGRectMake(0, 0, unselectedImg.size.width, unselectedImg.size.height) blendMode:kCGBlendModeNormal alpha:1.0];
    UIImage *fadedImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    vcInstall.tabBarItem.image = [fadedImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

    // 选中：色相旋转，保留原图所有透明度和亮度层次
    UIImage *selectedImg = [self hueRotateImage:[UIImage imageNamed:selectImage] angle:hueShift];
    vcInstall.tabBarItem.selectedImage = [selectedImg imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];

    vcInstall.tabBarItem.imageInsets = UIEdgeInsetsMake(6, 0, -6, 0);
    [self addChildViewController:vcInstall];
}

-(void) dealloc {
    WKLogDebug(@"WKMainTabController dealloc");
}

#pragma mark - UITabBarControllerDelegate

static UIImpactFeedbackGenerator *impactFeedBack;
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    
    if(!impactFeedBack) {
        impactFeedBack = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    [impactFeedBack prepare];
    [impactFeedBack impactOccurred];
}

@end
