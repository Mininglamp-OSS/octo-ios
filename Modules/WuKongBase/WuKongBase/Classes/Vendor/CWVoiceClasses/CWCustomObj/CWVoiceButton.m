// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  CWVoiceButton.m
//  QQVoiceDemo
//
//  Created by chavez on 2017/9/14.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWVoiceButton.h"
#import "UIView+CWChat.h"
#import "WKApp.h"
@implementation CWVoiceButton

+ (instancetype)buttonWithBackImageNor:(NSString *)backImageNor backImageSelected:(NSString *)backImageSelected imageNor:(NSString *)imageNor imageSelected:(NSString *)imageSelected frame:(CGRect)frame isMicPhone:(BOOL)isMicPhone{
    
    UIImage *normalImage = [self imageName:backImageNor]; //aio_voice_button_press
    UIImage *selectedImage = [self imageName:backImageSelected];
    CWVoiceButton *btn = [CWVoiceButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    btn.cw_size = normalImage.size;
    if (isMicPhone) {
        // 用 template 模式渲染背景图，通过 tintColor 统一改色为主题色
        UIImage *norTemplate = [normalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImage *selTemplate = [selectedImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [btn setBackgroundImage:norTemplate forState:UIControlStateNormal];
        [btn setBackgroundImage:selTemplate forState:UIControlStateSelected];
        btn.tintColor = [WKApp shared].config.themeColor;
    }
    btn.norImage = normalImage;
    btn.selectedImage = selectedImage;
    [btn setImage:[self imageName:imageNor] forState:UIControlStateNormal];
    [btn setImage:[self imageName:imageSelected] forState:UIControlStateSelected];
    btn.imageView.backgroundColor = [UIColor clearColor];
    if (!isMicPhone) {
        btn.backgroudLayer.contents = (__bridge id _Nullable)(normalImage.CGImage);
    }
    
    return btn;
}

+(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
}


- (CALayer *)backgroudLayer {
    if (_backgroudLayer == nil) {
        CALayer *layer = [[CALayer alloc] init];
        layer.frame = self.bounds;
        [self.layer insertSublayer:layer atIndex:0];
        _backgroudLayer = layer;
    }
    return _backgroudLayer;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    // 取消CALayer的隐式动画
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    UIImage *image = selected ? self.selectedImage : self.norImage;
    self.backgroudLayer.contents = (__bridge id _Nullable)(image.CGImage);
    [CATransaction commit];
    
}




- (BOOL)isHighlighted {
    return NO;
}


@end
