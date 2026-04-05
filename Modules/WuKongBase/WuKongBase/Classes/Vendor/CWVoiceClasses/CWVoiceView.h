//
//  CWVoiceView.h
//  QQVoiceDemo
//
//  Created by 陈旺 on 2017/9/2.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CWTalkBackView.h"
#import "CWAudioPlayView.h"
#import "CWVoiceChangePlayView.h"
#import "CWSpeechToTextView.h"
#import "WKVoiceInputViewDelegate.h"

typedef NS_ENUM(NSInteger,CWVoiceState) {
    CWVoiceStateDefault = 0, // 默认状态
    CWVoiceStateRecord,      // 录音
    CWVoiceStatePlay         // 播放
} ;

@class WKVoiceInputView;

@interface CWVoiceView : UIView

@property (nonatomic,assign) CWVoiceState state;

@property (nonatomic,assign) BOOL voiceInputEnabled; // 是否启用语音输入 tab

@property(nonatomic,weak) id<CWTalkBackViewDelegate> talkBackViewDelegate;
@property(nonatomic,weak) id<CWAudioPlayViewDelegate> playViewDelegate;
@property (nonatomic,weak) id<CWVoiceChangePlayViewDelegate> voiceChangePlayDelegate;
@property (nonatomic,weak) id<CWSpeechToTextViewDelegate> speechToTextDelegate;
@property (nonatomic,weak) id<WKVoiceInputViewDelegate> voiceInputDelegate;

- (void)setupSubViews;
- (void)cancelVoiceInputIfRecording;

@end
