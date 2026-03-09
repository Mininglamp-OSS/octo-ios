//
//  ATShowAlertView.h
//  qiyunxin
//
//  Created by Mac on 2018/1/16.
//  Copyright © 2018年 aiti. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef void(^cancelAction)(void);
typedef void(^sureAction)(void);

@interface WKPermissionShowAlertView : NSObject
-(void)showAlertView:(UIViewController*)currentVC alertTitle:(NSString*)alertTitle alertMessage:(NSString*)alertMessage actionTitle:(NSString*)actionTitle actionSubTitle:(NSString*)subTitle;

-(void)showPermissionSetting:(NSString*)alertMessage;
//重新登录
-(void)showAlertLogout;
//相机权限
-(void)requesetVideoPermissionCompletion:(void(^)(BOOL permission))permission;
//相册权限
-(void)requestAuthorizationPhotoPermissionCompletion:(void(^)(BOOL permission))permission;
//语音权限
- (BOOL)requesetRecordPermission;
@property(nonatomic,strong)sureAction defaultlAction;
@property(nonatomic,strong)cancelAction  subTitleAction;
//当前的控制器
@property(nonatomic,weak)UIViewController * currentPresentVC;
+(BOOL)isSupportShow;
+(BOOL)isContentShow:(NSString*)showContent;
@end
