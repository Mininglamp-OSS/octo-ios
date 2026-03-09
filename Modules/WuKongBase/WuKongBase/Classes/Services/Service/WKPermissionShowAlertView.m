
//
//  ATShowAlertView.m
//  qiyunxin
//
//  Created by Mac on 2018/1/16.
//  Copyright © 2018年 aiti. All rights reserved.
//

#import "WKPermissionShowAlertView.h"
#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <AssetsLibrary/ALAssetRepresentation.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "WuKongBase.h"
@implementation WKPermissionShowAlertView
-(void)showAlertView:(UIViewController*)currentVC alertTitle:(NSString*)alertTitle alertMessage:(NSString*)alertMessage actionTitle:(NSString*)actionTitle actionSubTitle:(NSString*)subTitle{
    //显示提示框
    //过时
    //    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Title" message:@"message" delegate:self cancelButtonTitle:@"cancel" otherButtonTitles:@"ok", nil];
    //    [alert show];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:alertTitle?:@""
                                                                   message:alertMessage?:@""
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:actionTitle?:@"" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (self.defaultlAction) {
                                                                  self.defaultlAction();
                                                              }
                                                          }];
    [alert addAction:defaultAction];
    if (subTitle) {
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:subTitle?:@"" style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * action) {
                                                                 if (self.subTitleAction) {
                                                                     self.subTitleAction();                                                                 }
                                                             }];
        [alert addAction:cancelAction];

        
    }
    dispatch_async(dispatch_get_main_queue(), ^{
    [currentVC presentViewController:alert animated:YES completion:nil];
  });
}
-(void)showPermissionSetting:(NSString*)alertMessage{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:LLang(@"权限设置")
                                                                   message:alertMessage?:@""
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction* settingAction = [UIAlertAction actionWithTitle:LLang(@"前往设置") style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              if (self.defaultlAction) {
                                                                  self.defaultlAction();
                                                              }
                                                             [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                                                          }];
    
        UIAlertAction* nextAction = [UIAlertAction actionWithTitle:LLang(@"下次再说") style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * action) {
                                                                 if (self.subTitleAction) {
                                                                     self.subTitleAction();
                                                                 }
                                                             }];
    
      [alert addAction:settingAction];
       [alert addAction:nextAction];
    if (self.currentPresentVC) {
        dispatch_async(dispatch_get_main_queue(), ^{

        [self.currentPresentVC presentViewController:alert animated:YES completion:nil];
        });

        return;
    }
//    dispatch_async(dispatch_get_main_queue(), ^{
//    [[[[[UIApplication sharedApplication] delegate] window] theCurrentViewController] presentViewController:alert animated:YES completion:nil];
//          });
}
#pragma mark-----相机权限
-(void)requesetVideoPermissionCompletion:(void(^)(BOOL permission))permission{
    
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        //没有权限
        permission(granted);
        if (!granted) {
            NSLog(@"没视频权限！！！");
            [self showPermissionSetting:LLang(@"请在iPhone的“设置-隐私”选项中，允许访问你的相册")];
        }
    } ];
    
}
#pragma mark---相册权限
-(void)requestAuthorizationPhotoPermissionCompletion:(void(^)(BOOL permission))permission{
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized)
        {
         NSLog(@"Authorized");
            permission(YES);
        }
        else{
            NSLog(@"Denied or Restricted");
            permission(NO);
            [self showPermissionSetting:LLang(@"请在iPhone的“设置-隐私”选项中，允许访问你的相册")];

        }
        
    }];
    
    
}

#pragma mark-----语音权限获取
- (BOOL)requesetRecordPermission
{
    __block BOOL bCanRecord = YES;
    //    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending)
    //    {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
        [audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            if (granted) {
                bCanRecord = YES;
            } else {
                bCanRecord = NO;
                [self showPermissionSetting:LLang(@"请在iPhone的“设置-隐私”选项中，允许访问你的麦克风")];
            }
        }];
    }
    //    }
    
    return bCanRecord;
}

//+(BOOL)isSupportShow{
//    ATShowAlertView * showAlertView = [[ATShowAlertView alloc]init];
//    [showAlertView showAlertView: [[UIApplication sharedApplication].keyWindow theCurrentViewController] alertTitle:@"" alertMessage:L(@"暂不支持") actionTitle:L(sure) actionSubTitle:nil];
//    return NO;
//}
//+(BOOL)isContentShow:(NSString*)showContent{
//    ATShowAlertView * showAlertView = [[ATShowAlertView alloc]init];
//    [showAlertView showAlertView: [[UIApplication sharedApplication].keyWindow theCurrentViewController] alertTitle:@"" alertMessage:showContent actionTitle:L(sure) actionSubTitle:nil];
//    return NO;
//}
@end
