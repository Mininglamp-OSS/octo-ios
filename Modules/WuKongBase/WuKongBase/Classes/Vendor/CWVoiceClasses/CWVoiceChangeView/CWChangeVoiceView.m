//
//  CWChangeVoiceView.m
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWChangeVoiceView.h"
#import "CWRecordStateView.h"
#import "CWVoiceButton.h"
#import "UIView+CWChat.h"
#import "CWRecorder.h"
#import "CWVoiceView.h"
#import "CWVoiceChangePlayView.h"
#import "CWFlieManager.h"
#import "WKApp.h"
//----------------------变声界面---------------------------------//

@interface CWChangeVoiceView()<CWRecorderDelegate>
@property (nonatomic, weak) CWRecordStateView *stateView;
@property (nonatomic, weak) UIButton *voiceChangeBtn;    // 录音按钮
@property (nonatomic,weak) CWVoiceChangePlayView *playView;

@property (nonatomic,assign) BOOL isRecordMaxTime;

@end

@implementation CWChangeVoiceView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    _isRecordMaxTime = NO;

    [self stateView];
    [self voiceChangeBtn];
//    [self playView];
}

#pragma mark - subviews
- (CWVoiceChangePlayView *)playView {
    if (_playView == nil) {
        CWVoiceChangePlayView *playView = [[CWVoiceChangePlayView alloc] initWithFrame:self.bounds];
        playView.delegate = self.delegate;
        [(CWVoiceView *)self.superview.superview setState:CWVoiceStatePlay];
        [UIView transitionWithView:self duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self addSubview:playView];
        } completion:nil];
        self.playView = playView;
    }
    return _playView;
}

- (CWRecordStateView *)stateView {
    if (_stateView == nil) {
        CWRecordStateView *stateView = [[CWRecordStateView alloc] initWithFrame:CGRectMake(0, 10, self.cw_width, 50)];
        stateView.recordState = CWRecordStateTouchChangeVoice;
        WeakSelf(self)
        stateView.recordDurationProgress = ^(NSInteger progress) {
            [weakself handleRecordDurationCallback:progress];
        };
        [self addSubview:stateView];
        _stateView = stateView;
    }
    return  _stateView;
}

- (UIButton *)voiceChangeBtn {
    if (_voiceChangeBtn == nil) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setImage:[self imageName:@"Conversation/VoiceRecord/aio_voiceChange_icon"] forState:UIControlStateNormal];
        btn.frame = CGRectMake(0, self.stateView.cw_bottom, btn.currentImage.size.width, btn.currentImage.size.height);
        // 手指按下
        [btn addTarget:self action:@selector(startRecorde:) forControlEvents:UIControlEventTouchDown];
        // 松开手指
        [btn addTarget:self action:@selector(endRecord:) forControlEvents:UIControlEventTouchUpInside];
        [btn addTarget:self action:@selector(endRecord:) forControlEvents:UIControlEventTouchUpOutside];
        
        btn.cw_centerX = self.cw_width / 2.0;
        [self addSubview:btn];
        _voiceChangeBtn = btn;
    }
    return _voiceChangeBtn;
}


#pragma mark - button events
- (void)startRecorde:(UIButton *)btn {
    
    btn.enabled = NO;
    NSTimeInterval t = 0.3;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(t * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        btn.enabled = YES;
    });
    
    [CWRecorder shareInstance].delegate = self;
    // 设置状态 隐藏小圆点和三个标签
    [(CWVoiceView *)self.superview.superview setState:CWVoiceStateRecord];
    [self animationMicBtn:^(BOOL finished) {
//        NSString *path = [CWDocumentPath stringByAppendingPathComponent:@"test.wav"];
        //        @"/Users/chavez/Desktop/test.wav"
        NSString *filePath = [CWFlieManager filePath];

        [[CWRecorder shareInstance] beginRecordWithRecordPath:filePath];
    }];

}

- (void)endRecord:(UIButton *)btn {
    NSInteger duration = self.stateView.recordDuration;
    NSLog(@"duration --- %@", @(duration));
    
    if ( _isRecordMaxTime ) {
        _isRecordMaxTime = NO;
        return;
    }
    
    NSTimeInterval t = 0;
    if (![CWRecorder shareInstance].isRecording) {
        t = 0.3;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(t * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        self.stateView.recordState = CWRecordStateTouchChangeVoice; // 切换状态为按住变声
        [[CWRecorder shareInstance] endRecord];  // 停止录音
        [self.stateView endRecord];    // stateview的动画停止
        // 设置状态 显示小圆点和三个标签
        [(CWVoiceView *)self.superview.superview setState:CWVoiceStateDefault];
        if (t == 0) {
            NSLog(@"跳转到变声界面");
            self.playView = nil;
            [self playView];
        }else {
            NSLog(@"录音时间太短");
            [CWFlieManager removeFile:[CWRecorder shareInstance].recordPath];
        }
    });
    
}

#pragma mark - button animation
- (void)animationMicBtn:(void(^)(BOOL finished))completion {
    [UIView animateWithDuration:0.10 animations:^{
        self.voiceChangeBtn.transform = CGAffineTransformMakeScale(1.1, 1.1);
    } completion:^(BOOL finished) {
        
        [UIView animateWithDuration:0.05 animations:^{
            self.voiceChangeBtn.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            if (completion) {
                completion(finished);
            }
        }];
        
    }];
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
    self.stateView.recordState = CWRecordStateTouchChangeVoice;
    NSLog(@"失败：%@",failedMessage);
}

#pragma mark -
- (void)handleRecordDurationCallback:(NSInteger)recordDuration {
    if ( recordDuration >= MaxRecordTime ) {
        
        self.stateView.recordState = CWRecordStateTouchChangeVoice; // 切换状态为按住变声
        [[CWRecorder shareInstance] endRecord];  // 停止录音
        [self.stateView endRecord];    // stateview的动画停止
        // 设置状态 显示小圆点和三个标签
        [(CWVoiceView *)self.superview.superview setState:CWVoiceStateDefault];
        
        NSLog(@"跳转到变声界面");
        self.playView = nil;
        [self playView];
        
        _isRecordMaxTime = YES;
    }
}
-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
