//
//  JCRecordPlayerView.h
//  Pods
//
//  Created by zhengjiacheng on 2017/8/31.
//
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
//#import "UIView+JCAddition.h"
typedef void(^JCRecordPlayerViewCancelBlock)(void);
typedef void(^JCRecordPlayerViewConfirmBlock)(void);

@interface JCRecordPlayerView : UIView
@property (nonatomic, copy) JCRecordPlayerViewCancelBlock cancelBlock;
@property (nonatomic, copy) JCRecordPlayerViewConfirmBlock confirmBlock;
@property (nonatomic, strong) NSURL *playUrl;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *confirmButton;

@property(nonatomic,strong) UIImage *img; // 图片
@end
