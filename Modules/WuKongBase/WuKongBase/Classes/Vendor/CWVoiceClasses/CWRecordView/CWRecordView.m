//
//  CWRecordView.m
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWRecordView.h"
#import "CWAudioPlayView.h"
#import "CWRecordStateView.h"
#import "CWVoiceButton.h"
#import "UIView+CWChat.h"
#import "CWRecorder.h"
#import "CWVoiceView.h"
#import "CWFlieManager.h"
#import "WKResource.h"
//----------------------录音界面---------------------------------//
@interface CWRecordView ()<CWRecorderDelegate>
@property (nonatomic, weak) CWRecordStateView *stateView;
@property (nonatomic, weak) CWVoiceButton *recordButton;    // 录音按钮
@property (nonatomic, weak) CWAudioPlayView *playView;   // 播放界面

@end


@implementation CWRecordView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    [self stateView];
    [self recordButton];
}

#pragma mark - subViews
- (CWAudioPlayView *)playView {
    if (_playView == nil) {
        CWAudioPlayView *view = [[CWAudioPlayView alloc] initWithFrame:self.bounds];
        view.delegate = self.playViewDelegate;
        [self addSubview:view];
        _playView = view;
    }
    return _playView;
}

- (CWRecordStateView *)stateView {
    if (_stateView == nil) {
        CWRecordStateView *stateView = [[CWRecordStateView alloc] initWithFrame:CGRectMake(0, 10, self.cw_width, 50)];
        stateView.recordState = CWRecordStateClickRecord;
        WeakSelf(self)
        stateView.recordDurationProgress = ^(NSInteger progress) {
            [weakself handleRecordDurationCallback:progress];
        };
        [self addSubview:stateView];
        _stateView = stateView;
    }
    return  _stateView;
}

- (CWVoiceButton *)recordButton {
    if (_recordButton == nil) {
        CWVoiceButton *btn = [CWVoiceButton buttonWithBackImageNor:@"Conversation/VoiceRecord/aio_record_being_button" backImageSelected:@"Conversation/VoiceRecord/aio_record_being_button" imageNor:@"Conversation/VoiceRecord/aio_record_start_nor" imageSelected:@"Conversation/VoiceRecord/aio_record_stop_nor" frame:CGRectMake(0, self.stateView.cw_bottom, 0, 0) isMicPhone:YES];
        // 松开手指
        [btn addTarget:self action:@selector(startRecorde:) forControlEvents:UIControlEventTouchUpInside];
        
        btn.cw_centerX = self.cw_width / 2.0;
        [self addSubview:btn];
        _recordButton = btn;
    }
    return _recordButton;
}

- (void)startRecorde:(CWVoiceButton *)btn {
    if ([self.recordViewDelegate respondsToSelector:@selector(beginRecord)]) {
        [self.recordViewDelegate beginRecord];
    }
    // 设置状态 隐藏小圆点和三个标签
    [(CWVoiceView *)self.superview.superview setState:CWVoiceStateRecord];
    btn.selected = !btn.selected;
    if (btn.selected) {
        [CWRecorder shareInstance].delegate = self;
        NSString *filePath = [CWFlieManager filePath];
//        NSString *path = [CWDocumentPath stringByAppendingPathComponent:@"test.wav"];
        //        @"/Users/chavez/Desktop/test.wav"
        [[CWRecorder shareInstance] beginRecordWithRecordPath:filePath];
    }else {
        
        [[CWRecorder shareInstance] endRecord];
        [self.stateView endRecord];
        self.stateView.recordState = CWRecordStateClickRecord;
        self.playView = nil;
        [self playView];
    }
    
}

#pragma mark - CWRecorderDelegate
- (void)recorderPrepare {
    //    NSLog(@"准备中......");
    self.stateView.recordState = CWRecordStatePrepare;
}

- (void)recorderRecording {
    self.stateView.recordState = CWRecordStateRecording;
    // 设置状态view开始录音
    [self.stateView beginRecord];
}

- (void)recorderFailed:(NSString *)failedMessage {
    self.stateView.recordState = CWRecordStateClickRecord;
    NSLog(@"失败：%@",failedMessage);
}

#pragma mark -
- (void)handleRecordDurationCallback:(NSInteger)recordDuration {
    NSLog(@"recordDuration -- %@", @(recordDuration));
    if ( recordDuration >= MaxRecordTime ) {
        [self startRecorde:_recordButton];
    }
}
-(UIImage*) imageName:(NSString*)name {
    return [[WKResource shared] imageNamed:name inClass:self.class];
}
@end
