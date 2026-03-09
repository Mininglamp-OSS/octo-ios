//
//  WKBaseVC.m
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import "WKBaseVC.h"
#import "UIBarButtonItem+WK.h"
#import "WKResource.h"
#import "WKApp.h"
#import "WKConstant.h"
#import "UIView+WK.h"
#import "WKNavTitleView.h"
#import "WKNavigationManager.h"
#import "WKLogs.h"
#import "WuKongBase.h"


@implementation WKFinishButton

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    
    if(enabled) {
        self.alpha = 1.0f;
    }else{
        self.alpha = 0.5f;
    }
}

@end

@interface WKBaseVC ()


@end

@implementation WKBaseVC


-(instancetype) initWithViewModel:(WKBaseVM*)vm{
    self = [super init];
    if (!self) return nil;
    self.baseVM = vm;
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self langTitle];
    [self.view setBackgroundColor:[WKApp shared].config.backgroundColor];
//    [self.navigationController.navigationBar setTranslucent:NO];
    [self.view addSubview:self.navigationBar];
    
    if ([self.navigationController.viewControllers count] >= 2 ) {
        [self setupNavBack];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(langChange) name:WKNOTIFY_LANG_CHANGE object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moduleChange) name:WKNOTIFY_MODULE_CHANGE object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)dealloc
{
    WKLogDebug(@"%s",__func__);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_LANG_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:WKNOTIFY_MODULE_CHANGE object:nil];
}

-(void) langChange {
    [self viewConfigChange:WKViewConfigChangeTypeLang];
}
-(void) moduleChange {
    [self viewConfigChange:WKViewConfigChangeTypeModule];
}

- (WKNavigationBar *)navigationBar {
    if(!_navigationBar) {
        _navigationBar = [[WKNavigationBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f,WKScreenWidth, self.largeTitle?[WKApp shared].config.navHeight+15.0f:[WKApp shared].config.navHeight)];
        _navigationBar.largeTitle = self.largeTitle;
        __weak typeof(self) weakSelf = self;
        [_navigationBar setBackgroundColor:[WKApp shared].config.navBackgroudColor];
        _navigationBar.onBack = ^{
            [weakSelf backPressed];
        };
        [WKApp.shared.config setThemeStyleNavigation:_navigationBar];
    }
    return _navigationBar;
}
- (void)setTitle:(NSString *)title {
    [super setTitle:title];
    self.navigationBar.title = title;

}

-(NSString*) langTitle {
    return nil;
}

-(void) backPressed {
    [[WKNavigationManager shared] popViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
//    [self.navigationController.navigationBar setHidden:NO];
    [self.navigationController.navigationBar setBarTintColor:[WKApp shared].config.backgroundColor];
}


-(void) setupNavBack {
    [self.navigationBar setShowBackButton:YES];
}

- (void)leftBarButtonAction:(id)sender {
    UIViewController *v =
    [self.navigationController popViewControllerAnimated:YES];
    if (v == nil) {
        [self.view endEditing:YES];
        dispatch_after(
                       dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           [self dismissViewControllerAnimated:YES completion:NULL];
                       });
    }
}

-(UIImage*) getImageWithName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

-(CGFloat) getNavBottom {
    CGRect rectNav = self.navigationController.navigationBar.frame;
    return rectNav.origin.y + rectNav.size.height;
}

- (void)setRightView:(UIView *)rightView {
    self.navigationBar.rightView = rightView;
}

-(CGRect) visibleRect {
    
    return CGRectMake(0.0f, self.navigationBar.lim_bottom, self.view.lim_width, self.view.lim_height - self.navigationBar.lim_bottom);
}

- (WKFinishButton *)finishBtn {
    if(!_finishBtn) {
        _finishBtn = [[WKFinishButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 60.0f, 30.0f)];
        [_finishBtn setTitle:LLangC(@"完成",[WKBaseVC class]) forState:UIControlStateNormal];
        _finishBtn.layer.masksToBounds = YES;
        _finishBtn.layer.cornerRadius = 4.0f;
        _finishBtn.backgroundColor = [WKApp shared].config.themeColor;
        [[_finishBtn titleLabel] setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    }
    return _finishBtn;
}



-(void) viewConfigChange:(WKViewConfigChangeType)type {
    if(type == WKViewConfigChangeTypeStyle) {
        [self.view setBackgroundColor:[WKApp shared].config.backgroundColor];
        [self.navigationBar setBackgroundColor:[WKApp shared].config.navBackgroudColor];
        if([WKApp shared].config.style == WKSystemStyleDark) {
            self.navigationBar.style = WKNavigationBarStyleDark;
        }else {
            self.navigationBar.style = WKNavigationBarStyleDefault;
        }
    }
    [WKApp.shared.config setThemeStyleNavigation:self.navigationBar];
   
}

#pragma mark - UITraitEnvironment

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle mode = UITraitCollection.currentTraitCollection.userInterfaceStyle;
        if (mode == UIUserInterfaceStyleDark) {
            WKLogDebug(@"深色模式");
        } else if (mode == UIUserInterfaceStyleLight) {
            WKLogDebug(@"浅色模式");
        } else {
            WKLogDebug(@"未知模式");
        }
    }
    [self viewConfigChange:WKViewConfigChangeTypeStyle];
}

@end
