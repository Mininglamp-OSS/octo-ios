//
//  CWAudioPlayView.h
//  QQVoiceDemo
//
//  Created by 陈旺 on 2017/10/4.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>
@class CWAudioPlayView;
@protocol CWAudioPlayViewDelegate <NSObject>

-(void) audioPlayView:(CWAudioPlayView*)view second:(NSInteger)second;

@end

@interface CWAudioPlayView : UIView

@property (nonatomic,assign) CGFloat progressValue;

@property(nonatomic,weak) id<CWAudioPlayViewDelegate> delegate;

@end
