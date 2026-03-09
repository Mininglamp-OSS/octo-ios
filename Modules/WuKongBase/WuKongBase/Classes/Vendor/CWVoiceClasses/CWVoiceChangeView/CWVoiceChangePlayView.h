//
//  CWVoiceChangePlayView.h
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>
@class CWVoiceChangePlayView;
@protocol CWVoiceChangePlayViewDelegate <NSObject>


-(void) voiceChangePlayView:(CWVoiceChangePlayView*)view voicePath:(NSString*)path second:(NSInteger)second;

@end

@interface CWVoiceChangePlayView : UIView

@property (nonatomic,weak) id<CWVoiceChangePlayViewDelegate> delegate;

@end
