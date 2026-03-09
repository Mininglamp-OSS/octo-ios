//
//  WKProgressHUD.m
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import "WKProgressHUD.h"
#import <MBProgressHUD/MBProgressHUD.h>
 static MBProgressHUD *hud = nil;
@implementation WKProgressHUD

+ (instancetype)sharedView
{
    static WKProgressHUD *instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKProgressHUD alloc] init];
    });
    return instance;
}

+(void) show{
    [[WKProgressHUD sharedView] showInView:[UIApplication sharedApplication].keyWindow];
}

+(void) dismiss{
    if(hud) {
        [hud hideAnimated:YES];
    }
}


-(void) showInView:(UIView*)view{
    hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
}
@end
