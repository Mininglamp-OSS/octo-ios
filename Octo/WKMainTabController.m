// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMainTabController.m
//  Octo
//
//  Created by tt on 2019/12/7.
//  Copyright 2026 MININGLAMP Technology and the OCTO contributors
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
    // 监听 viewConfigChange 通知（WKBaseVC 的 traitCollectionDidChange 会发这个）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onStyleChange) name:@"WK_NOTIFY_STYLE_CHANGE" object:nil];
    // 切语言时 tabbar item title 不会自动刷新, 必须监听 WKNOTIFY_LANG_CHANGE 重新走 LLang
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLangChange) name:WKNOTIFY_LANG_CHANGE object:nil];

    [self setupChildVC:WKConversationListVC.class title:LLang(@"消息")
                 image:[UIImage imageNamed:@"消息"]
         selectedImage:[UIImage imageNamed:@"消息1"]];

    [self setupChildVC:WKContactsVC.class title:LLang(@"上下文")
                 image:[UIImage imageNamed:@"上下文"]
         selectedImage:[UIImage imageNamed:@"上下文1"]];

    [self setupChildVC:WKMeVC.class title:LLang(@"我")
                 image:[UIImage imageNamed:@"我的"]
         selectedImage:[UIImage imageNamed:@"我的1"]];

    // 必须在 setupChildVC 之后，applySelectedTitleColor 要遍历 self.viewControllers
    [self updateTabBarAppearance];
}

- (void)onLangChange {
    // tab item 顺序 = setupChildVC 顺序: 消息 / 上下文 / 我
    NSArray<NSString *> *titleKeys = @[@"消息", @"上下文", @"我"];
    [self.viewControllers enumerateObjectsUsingBlock:^(UIViewController *vc, NSUInteger idx, BOOL *stop) {
        if (idx < titleKeys.count) {
            vc.tabBarItem.title = LLang(titleKeys[idx]);
        }
    }];
}


- (void)setupChildVC:(Class)vc title:(NSString *)title image:(UIImage *)image selectedImage:(UIImage *)selectedImage {
    UIViewController *vcInstall = [[vc alloc] init];
    vcInstall.tabBarItem = [[UITabBarItem alloc] initWithTitle:title
                                                        image:[image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                                                selectedImage:[selectedImage imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    [self addChildViewController:vcInstall];
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
    // iOS 26+ Liquid Glass：浮岛玻璃由系统在 tabbar 上方独立渲染。
    // 我们要做的是把底层 UITabBar 自身的"背景板"完全抹掉（透明），
    // 否则会看到一条贯穿全宽的浅灰色（默认 material）压在 Liquid Glass 之下。
    if (@available(iOS 26.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = [UIColor clearColor];
        appearance.shadowColor = [UIColor clearColor];
        appearance.backgroundImage = [UIImage new];
        appearance.shadowImage = [UIImage new];
        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
        // 老 API 也清一遍，防止系统某些路径回退
        self.tabBar.barTintColor = [UIColor clearColor];
        self.tabBar.backgroundImage = [UIImage new];
        self.tabBar.shadowImage = [UIImage new];

        UIColor *selectedTextColor = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:35.0/255.0 alpha:1.0];
        [self applySelectedTitleColor:selectedTextColor];
        return;
    }

    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        appearance.shadowColor = [UIColor clearColor];

        UIColor *selectedTextColor = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:35.0/255.0 alpha:1.0];
        NSDictionary *selectedAttrs = @{ NSForegroundColorAttributeName: selectedTextColor };
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs;
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs;
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs;

        self.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            self.tabBar.scrollEdgeAppearance = appearance;
        }
    }
    self.tabBar.translucent = YES;
}

- (void)applySelectedTitleColor:(UIColor *)color {
    NSDictionary *selectedAttrs = @{ NSForegroundColorAttributeName: color };
    for (UIViewController *vc in self.viewControllers) {
        [vc.tabBarItem setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
    }
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

