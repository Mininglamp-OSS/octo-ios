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
    [self updateTabBarAppearance];
    self.tabBar.tintColor = [WKApp shared].config.themeColor;
    // 监听 viewConfigChange 通知（WKBaseVC 的 traitCollectionDidChange 会发这个）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStyleChange) name:@"WK_NOTIFY_STYLE_CHANGE" object:nil];

    UIColor *normalColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    UIColor *selectedColor = [WKApp shared].config.themeColor;

    [self setupChildVC:WKConversationListVC.class title:LLang(@"消息")
                 image:[self drawMessageIconWithColor:normalColor filled:NO]
         selectedImage:[self drawMessageIconWithColor:selectedColor filled:YES]];

    [self setupChildVC:WKContactsVC.class title:LLang(@"通讯录")
                 image:[self drawContactsIconWithColor:normalColor filled:NO]
         selectedImage:[self drawContactsIconWithColor:selectedColor filled:YES]];

    [self setupChildVC:WKMeVC.class title:LLang(@"我")
                 image:[self drawMeIconWithColor:normalColor filled:NO]
         selectedImage:[self drawMeIconWithColor:selectedColor filled:YES]];

}


- (void)setupChildVC:(Class)vc title:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage {
    UIViewController *vcInstall = [[vc alloc] init];
    vcInstall.tabBarItem = [[UITabBarItem alloc] initWithTitle:title
                                                        image:[image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                                                selectedImage:[selectedImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    [self addChildViewController:vcInstall];
}

#pragma mark - Tab Bar Icon Drawing

- (UIImage *)drawMessageIconWithColor:(UIColor *)color filled:(BOOL)filled {
    CGSize size = CGSizeMake(26, 26);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIBezierPath *bubble = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 3, 22, 16) cornerRadius:4];
    // 小尾巴
    UIBezierPath *tail = [UIBezierPath bezierPath];
    [tail moveToPoint:CGPointMake(7, 19)];
    [tail addLineToPoint:CGPointMake(5, 23)];
    [tail addLineToPoint:CGPointMake(12, 19)];
    [bubble appendPath:tail];

    if (filled) {
        CGContextSetFillColorWithColor(ctx, color.CGColor);
        [bubble fill];
    } else {
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        CGContextSetLineWidth(ctx, 1.5);
        [bubble stroke];
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)drawContactsIconWithColor:(UIColor *)color filled:(BOOL)filled {
    CGSize size = CGSizeMake(28, 26);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    if (filled) {
        CGContextSetFillColorWithColor(ctx, color.CGColor);
        // 前面的人（左）
        CGContextFillEllipseInRect(ctx, CGRectMake(6, 4, 9, 9));
        UIBezierPath *body1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 17, 17, 8) cornerRadius:4];
        [body1 fill];
        // 后面的人（右）
        CGContextFillEllipseInRect(ctx, CGRectMake(16, 5, 7.5, 7.5));
        UIBezierPath *body2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(14, 16, 13, 7) cornerRadius:3.5];
        [body2 fill];
    } else {
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        // 前面的人（左）
        CGContextStrokeEllipseInRect(ctx, CGRectMake(6, 4, 9, 9));
        UIBezierPath *body1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 17, 17, 8) cornerRadius:4];
        [body1 stroke];
        // 后面的人（右）
        CGContextStrokeEllipseInRect(ctx, CGRectMake(16, 5, 7.5, 7.5));
        UIBezierPath *body2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(14, 16, 13, 7) cornerRadius:3.5];
        [body2 stroke];
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)drawMeIconWithColor:(UIColor *)color filled:(BOOL)filled {
    CGSize size = CGSizeMake(26, 26);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1.5);

    if (filled) {
        CGContextSetFillColorWithColor(ctx, color.CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(7.5, 3, 11, 11));
        UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 17, 20, 8) cornerRadius:4];
        [body fill];
    } else {
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(7.5, 3, 11, 11));
        UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 17, 20, 8) cornerRadius:4];
        [body stroke];
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self onStyleChange];
}

- (void)onStyleChange {
    [self updateTabBarAppearance];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateTabBarAppearance {
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        appearance.shadowColor = [UIColor clearColor];
        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
    }
    self.tabBar.translucent = NO;
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
