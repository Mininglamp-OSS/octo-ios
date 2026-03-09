//
//  CWTalkBackView.h
//  QQVoiceDemo
//
//  Created by 陈旺 on 2017/10/4.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CWAudioPlayView.h"
@class CWTalkBackView;
@protocol CWTalkBackViewDelegate <NSObject>

-(void) talkBackViewSendRecord:(CWTalkBackView*) view second:(NSInteger)second;

@optional

- (void)beginRecord;

@end

//----------------------对讲界面---------------------------------//
@interface CWTalkBackView : UIView

@property(nonatomic,weak) id<CWTalkBackViewDelegate> delegate;

@property(nonatomic,weak) id<CWAudioPlayViewDelegate> playDelegate;

@end
