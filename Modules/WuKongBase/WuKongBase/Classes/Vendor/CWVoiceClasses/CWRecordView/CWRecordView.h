//
//  CWRecordView.h
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CWAudioPlayView.h"
//----------------------录音界面---------------------------------//

@protocol CWRecordViewDelegate <NSObject>

@optional
- (void)beginRecord;

@end

@interface CWRecordView : UIView

@property(nonatomic,weak) id<CWAudioPlayViewDelegate> playViewDelegate;

@property (nonatomic,weak) id <CWRecordViewDelegate> recordViewDelegate;

@end
