//
//  UIView+ATCommon.h
//  ATIMExample
//
//  Created by chenyisi on 15/11/14.
//  Copyright © 2015年 weiyunxin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Toast/UIView+Toast.h>
#import <MBProgressHUD/MBProgressHUD.h>

@interface UIView (WKCommon)

-(void) showMsg:(NSString*)msg;

-(void) makeActivity;

-(void) hideActivity;

-(MBProgressHUD*) showHUD;
-(MBProgressHUD*) showHUD:(NSString*)text;
-(MBProgressHUD*) showHUDWithDim;
-(MBProgressHUD*) showHUDWithHide:(NSString*)text;


/// 切换为错误模式（指定时间后消失）
/// @param text <#text description#>
-(void) switchHUDError:(NSString*)text;

/// 切换为成功模式（指定时间后消失）
/// @param text <#text description#>
-(void) switchHUDSuccess:(NSString*)text;


/// 切换为进度条模式
/// @param progress <#progress description#>
-(void) switchHUDProgress:(CGFloat)progress;

- (void)hideHud;


/**
 权限提醒

 @param alertMessage <#alertMessage description#>
 */
- (void) showPermissionSetting:(NSString *)alertMessage;
@end
