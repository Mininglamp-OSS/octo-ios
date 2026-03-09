//
//  UIView+ATCommon.m
//  ATIMExample
//
//  Created by chenyisi on 15/11/14.
//  Copyright © 2015年 weiyunxin. All rights reserved.
//

#import "UIView+WKCommon.h"
#import "WKNavigationManager.h"
#import <objc/runtime.h>
#import "WKResource.h"
#import "WKApp.h"
static const void *HttpRequestHUDKey = &HttpRequestHUDKey;
@implementation UIView (WKCommon)

-(void) showMsg:(NSString*)msg{
    
    CSToastStyle * style = [[CSToastStyle alloc] initWithDefaultStyle];
 
    [style setMessageFont:[UIFont systemFontOfSize:15.0f]];
    
    [self makeToast:msg duration:1.0f position:CSToastPositionCenter  style:style];
}

-(void) makeActivity{
    
    [self makeToastActivity:CSToastPositionCenter];
}

-(MBProgressHUD*) showHUD{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self animated:YES];
    [self setHUD:hud];
    return hud;
}

- (MBProgressHUD *)HUD{
    return objc_getAssociatedObject(self, HttpRequestHUDKey);
}

- (void)setHUD:(MBProgressHUD *)HUD{
    objc_setAssociatedObject(self, HttpRequestHUDKey, HUD, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(MBProgressHUD*) showHUD:(NSString*)text{
    MBProgressHUD *hud  = [self showHUD];
    hud.label.text = text;
    [self setHUD:hud];
    return hud;
}
- (void)hideHud{
    [[self HUD] hideAnimated:YES];
}

-(void) switchHUDProgress:(CGFloat)progress {
    MBProgressHUD *hud = [self HUD];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.progress = progress;
}

-(void) switchHUDError:(NSString*)text {
    MBProgressHUD *hud = [self HUD];
    UIImage *image = [[self imageName:@"Common/Index/HudError"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    
    hud.customView = imageView;
    hud.mode = MBProgressHUDModeCustomView;
    hud.label.text = text;
    [hud hideAnimated:YES afterDelay:1.0f];
}
-(void) switchHUDSuccess:(NSString*)text {
    MBProgressHUD *hud = [self HUD];
    UIImage *image = [[self imageName:@"Common/Index/HudSuccess"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    
    hud.customView = imageView;
    hud.mode = MBProgressHUDModeCustomView;
    hud.label.text = text;
    [hud hideAnimated:YES afterDelay:1.0f];
}

-(MBProgressHUD*) showHUDWithHide:(NSString*)text{
    MBProgressHUD *hud  = [self showHUD];
    hud.label.text = text;
    hud.mode = MBProgressHUDModeText;
    [hud hideAnimated:YES afterDelay:1.0f];
    
    return hud;
}

-(MBProgressHUD*) showHUDWithDim{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self animated:YES];
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.2f];
    return hud;
}

-(void) hideActivity{
    [self hideToastActivity];
}

- (void) showPermissionSetting:(NSString *)alertMessage {
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"权限设置"
                                        message:alertMessage ?: @""
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *settingAction = [UIAlertAction
                                    actionWithTitle:@"前往设置"
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction *action) {
                            
                                        [[UIApplication sharedApplication]
                                         openURL:[NSURL URLWithString:
                                                  UIApplicationOpenSettingsURLString]];
                                    }];
    UIAlertAction *nextAction =
    [UIAlertAction actionWithTitle:@"下次再说"
                             style:UIAlertActionStyleCancel
                           handler:^(UIAlertAction *action) {
                            
                           }];
    [alert addAction:settingAction];
    [alert addAction:nextAction];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[WKNavigationManager shared] topViewController] presentViewController:alert animated:YES completion:nil];
    });
}
-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}
@end
