//
//  CWVoiceButton.h
//  QQVoiceDemo
//
//  Created by chavez on 2017/9/14.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CWVoiceButton : UIButton

@property (nonatomic,weak) CALayer *backgroudLayer;

@property (nonatomic,strong) UIImage *norImage;
@property (nonatomic,strong) UIImage *selectedImage;


+ (instancetype)buttonWithBackImageNor:(NSString *)backImageNor backImageSelected:(NSString *)backImageSelected imageNor:(NSString *)imageNor imageSelected:(NSString *)imageSelected frame:(CGRect)frame isMicPhone:(BOOL)isMicPhone;


@end
