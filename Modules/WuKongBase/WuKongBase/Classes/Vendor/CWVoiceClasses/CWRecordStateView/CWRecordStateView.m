//
//  CWRecordStateView.m
//  QQVoiceDemo
//
//  Created by 陈旺 on 2017/9/2.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWRecordStateView.h"
#import "UIView+CWChat.h"
#import "CWRecorder.h"
#import "CWRecordModel.h"

#import "WuKongBase.h"

static CGFloat const levelWidth = 3.0;
static CGFloat const levelMargin = 2.0;

@interface CWRecordStateView ()

/**
 显示文字相关
 */
@property (nonatomic,weak) UILabel *titleLb; // 按住说话文字标签
@property (nonatomic,weak) UIActivityIndicatorView *activityView;

/**
 振幅界面相关
 */
@property (nonatomic,weak) UIView *levelContentView;        // 振幅所有视图的载体
@property (nonatomic,weak) UILabel *timeLabel;              // 录音时长标签
@property (nonatomic,weak) CAReplicatorLayer *replicatorL;  // 复制图层
@property (nonatomic,weak) CAShapeLayer *levelLayer;        // 振幅layer

@property (nonatomic,strong) NSMutableArray *currentLevels; // 当前振幅数组
@property (nonatomic,strong) NSMutableArray *allLevels;     // 所有收集到的振幅,预先保存，用于播放

@property (nonatomic,strong) UIBezierPath *levelPath;       // 画振幅的path

@property (nonatomic,strong) NSTimer *audioTimer;           // 录音时长/播放录音 计时器
@property (nonatomic,strong) CADisplayLink *levelTimer;     // 振幅计时器

@property (nonatomic,assign) NSInteger recordDuration;      // 录音时长

@property (nonatomic,strong) CADisplayLink *playTimer;      // 播放时振幅计时器


@end

@implementation CWRecordStateView
{
    NSInteger _allCount;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
//        self.backgroundColor = [UIColor yellowColor];
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    [self titleLb];
    [self activityView];
    [self updateLableFrame:self.titleLb];
    
    [self levelContentView];
    
}

#pragma mark - displayLink
- (void)startMeterTimer {
    [self stopMeterTimer]; 
    self.levelTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMeter)];

    if ([[UIDevice currentDevice].systemVersion floatValue] > 10.0) {
        self.levelTimer.preferredFramesPerSecond = 10;
    }else {
        self.levelTimer.frameInterval = 6;
    }
    [self.levelTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

// 停止定时器
- (void)stopMeterTimer {
    [self.levelTimer invalidate];
}

#pragma mark - audioTimer
- (void)startAudioTimer {
    [self.audioTimer invalidate];
    if (_recordState != CWRecordStatePlay) {
        _recordDuration = 0;
    }
    self.audioTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(addSeconed) userInfo:nil repeats:YES];
}

- (void)addSeconed {
    if (_recordState == CWRecordStatePlay ) {
        if (_recordDuration == [CWRecordModel shareInstance].duration) {
            [self.audioTimer invalidate];
            return;
        }
    }
    _recordDuration++;
    
    [self updateTimeLabel];
    
    if ( _recordDurationProgress ) {
        _recordDurationProgress(_recordDuration);
    }
}


- (void)updateTimeLabel {
    NSString *text = [self getTimeLabelTextWithDuration:_recordDuration];
    if ( _recordDuration >= MaxRecordTime ) {
        text = [self getTimeLabelTextWithDuration:6];
    }
    self.timeLabel.text = text;
}

- (NSString *)getTimeLabelTextWithDuration:(NSInteger)duration {
    NSString *text ;
    if (duration < 60) {
        text = [NSString stringWithFormat:@"0:%02zd",duration];
    }else {
        NSInteger minutes = duration / 60;
        NSInteger seconed = duration % 60;
        text = [NSString stringWithFormat:@"%zd:%02zd",minutes,seconed];
    }
    return text;
}

- (void)updateMeter {
    CGFloat level = [[CWRecorder shareInstance] levels];
//    NSLog(@"%f",[[CWRecorder shareInstance] levels]);
    [self.currentLevels removeLastObject];
    [self.currentLevels insertObject:@(level) atIndex:0];
    
    [self.allLevels addObject:@(level)];
//    NSLog(@"%@",self.allLevels);
    [self updateLevelLayer];
}

- (void)updateLevelLayer {
    
    self.levelPath = [UIBezierPath bezierPath];
    
    CGFloat height = CGRectGetHeight(self.levelLayer.frame);
    for (int i = 0; i < self.currentLevels.count; i++) {
        CGFloat x = i * (levelWidth + levelMargin) + 5;
        CGFloat pathH = [self.currentLevels[i] floatValue] * height;
        CGFloat startY = height / 2.0 - pathH / 2.0;
        CGFloat endY = height / 2.0 + pathH / 2.0;
        [_levelPath moveToPoint:CGPointMake(x, startY)];
        [_levelPath addLineToPoint:CGPointMake(x, endY)];
    }
    
    self.levelLayer.path = _levelPath.CGPath;
    
}


#pragma mark - lazyLoad
- (NSMutableArray *)allLevels {
    if (_allLevels == nil) {
        _allLevels = [NSMutableArray array];
    }
    return _allLevels;
}

- (NSMutableArray *)currentLevels {
    if (_currentLevels == nil) {
        _currentLevels = [NSMutableArray arrayWithArray:@[@0.05,@0.05,@0.05,@0.05,@0.05,@0.05,@0.05,@0.05,@0.05,@0.05]];
    }
    return _currentLevels;
}

- (UIView *)levelContentView {
    if (_levelContentView == nil) {
        UIView *contentV = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:contentV];
        contentV.hidden = YES;
        _levelContentView = contentV;
        
        [self timeLabel];
        [self replicatorL];
        
    }
    return _levelContentView;
}

- (UILabel *)timeLabel {
    if (_timeLabel == nil) {
        UILabel *timeL = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, self.cw_height)];
        timeL.text = @"0:00";
        timeL.textAlignment = NSTextAlignmentCenter;
        timeL.font = [UIFont systemFontOfSize:17];
        timeL.textColor = UIColorFromRGBA(119, 119, 119, 1.0);
//        [timeL sizeToFit];
//        timeL.backgroundColor = [UIColor yellowColor];
        timeL.center = self.levelContentView.center;
        [self.levelContentView addSubview:timeL];
        _timeLabel = timeL;
    }
    return _timeLabel;
}

- (CAReplicatorLayer *)replicatorL {
    if (_replicatorL == nil) {
        CAReplicatorLayer *repL = [CAReplicatorLayer layer];
        repL.frame = self.layer.bounds;
        repL.instanceCount = 2;
        repL.instanceTransform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
        [self.levelContentView.layer addSublayer:repL];
        _replicatorL = repL;
        [self levelLayer];
    }
    return _replicatorL;
}

- (CAShapeLayer *)levelLayer {
    if (_levelLayer == nil) {
        CAShapeLayer *layer = [CAShapeLayer layer];
        layer.frame = CGRectMake(self.timeLabel.cw_right, 10, self.cw_width / 2.0 - 30, self.cw_height - 20);
//        layer.backgroundColor = [UIColor whiteColor].CGColor;
        layer.strokeColor = UIColorFromRGBA(253, 99, 9, 1.0).CGColor;
        layer.lineWidth = levelWidth;
        [self.replicatorL addSublayer:layer];
        _levelLayer = layer;
    }
    return _levelLayer;
}

- (UILabel *)titleLb {
    if (_titleLb == nil) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = LLang(@"按住说话");
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = UIColorFromRGBA(119, 119, 119, 1.0);
        [self addSubview:label];
//        [self updateLableFrame:label];
        _titleLb = label;
    }
    return _titleLb;
}

- (UIActivityIndicatorView *)activityView {
    if (_activityView == nil) {
        UIActivityIndicatorView *acView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
//        acView.frame = CGRectMake(0, 0, 15, 15);
        acView.hidesWhenStopped = YES;
        [self addSubview:acView];
        self.activityView = acView;
    }
    return _activityView;
}

// 更新label的frmae
- (void)updateLableFrame:(UILabel *)label {
    label.hidden = NO;
    [label sizeToFit];
    label.cw_centerX = self.cw_width / 2;
    label.cw_centerY = self.cw_height / 2;
//    [self.activityView sizeToFit];
    self.activityView.cw_right = label.cw_left - 5;
    self.activityView.cw_centerY = label.cw_centerY;
    self.activityView.transform = CGAffineTransformMakeScale(0.8, 0.8);
}

#pragma mark - setter
- (void)setRecordState:(CWRecordState)recordState {
    
    self.levelContentView.hidden = YES;
    _recordState = recordState;
    [self.activityView stopAnimating];
    switch (recordState) {
        case CWRecordStateDefault:
            self.titleLb.text = LLang(@"按住说话");
            [self updateLableFrame:self.titleLb];
            break;
        case CWRecordStateClickRecord:
            self.titleLb.text = LLang(@"点击录音");
            [self updateLableFrame:self.titleLb];
            break;
        case CWRecordStateTouchChangeVoice:
            self.titleLb.text = LLang(@"按住变声");
            [self updateLableFrame:self.titleLb];
            break;
        case CWRecordStateListen:
            self.titleLb.text = LLang(@"松手试听");
            [self updateLableFrame:self.titleLb];
            break;
        case CWRecordStateCancel:
            self.titleLb.text = LLang(@"松手取消发送");
            [self updateLableFrame:self.titleLb];
            break;
        
        case CWRecordStateSend:
            
            break;
        case CWRecordStatePrepare:
            self.titleLb.text = LLang(@"准备中");
            [self updateLableFrame:self.titleLb];
            [self.activityView startAnimating];
        
            break;
        case CWRecordStateRecording:
            self.titleLb.hidden = YES;
            self.levelContentView.hidden = NO;
            break;
        case CWRecordStatePlay:
            self.titleLb.hidden = YES;
            self.levelContentView.hidden = NO;
            [self playAndMertering];
            break;
        case CWRecordStatePreparePlay:
            self.titleLb.hidden = YES;
            self.levelContentView.hidden = NO;
            [self preparePlay];
            break;
        default:
            break;
    }
}

#pragma mark recorde play
// 开始录音
- (void)beginRecord {
    
    self.levelContentView.hidden = NO;
    
    // 开始录音先把上一次录音的振幅删掉
    [self.allLevels removeAllObjects];
    self.currentLevels = nil;
    [self startMeterTimer];
    [self startAudioTimer];
}

// 结束录音
- (void)endRecord {
    NSLog(@"endRecord---------结束录音");
    NSLog(@"%@",self.allLevels);
    [CWRecordModel shareInstance].path = [CWRecorder shareInstance].recordPath;
    [CWRecordModel shareInstance].levels = [NSArray arrayWithArray:self.allLevels];
    [CWRecordModel shareInstance].duration = (NSTimeInterval)_recordDuration;

    _recordDuration = 0;
    [self updateTimeLabel];
    
    [self stopMeterTimer];
    [self.audioTimer invalidate];
    self.currentLevels = nil;
    self.levelContentView.hidden = YES;
}

// 准备播放
- (void)preparePlay {
    
    [self.playTimer invalidate];
    [self.audioTimer invalidate];
    
    [self.allLevels removeAllObjects];
    self.allLevels = [[CWRecordModel shareInstance].levels mutableCopy];
    [self.currentLevels removeAllObjects];
    
    /*
     * 当音频时间特别短时，self.allLevels.count 可能小于 10， 故做容错处理
     *     NSInteger checkValue = self.allLevels.count >= 10 ? ( self.allLevels.count - 10 ) : 0;
     *     for (NSInteger i = self.allLevels.count - 1 ; i >= checkValue ; i--) {
     *          // ...
     *     }
     
     原代码
     //    for (NSInteger i = self.allLevels.count - 1 ; i >= self.allLevels.count - 10 ; i--) {
     //         // ...
     //     }
     */
    NSInteger checkValue = self.allLevels.count >= 10 ? ( self.allLevels.count - 10 ) : 0;
    for (NSInteger i = self.allLevels.count - 1 ; i >= checkValue ; i--) {
        CGFloat l = 0.05;
        if (i >= 0) {
            l = [self.allLevels[i] floatValue];
        }
        [self.currentLevels addObject:@(l)];
    }
//    NSLog(@"%@-----%@",self.allLevels,self.currentLevels);
    _recordDuration = [CWRecordModel shareInstance].duration;
    
    [self updateLevelLayer];
    [self updateTimeLabel];
    
}

// 播放录音
- (void)playAndMertering {
    
    [self preparePlay];
    
    _recordDuration = 0;
    [self updateTimeLabel];
    
    [self startPlayTimer];
    [self startAudioTimer];
}


- (void)startPlayTimer {
    _allCount = self.allLevels.count;
    [self.playTimer invalidate];
    self.playTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updatePlayMeter)];
    
    if ([[UIDevice currentDevice].systemVersion floatValue] > 10.0) {
        self.playTimer.preferredFramesPerSecond = 10;
    }else {
        self.playTimer.frameInterval = 6;
    }
    [self.playTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)updatePlayMeter {
    
    CGFloat value = 1 - (CGFloat)self.allLevels.count / _allCount;
    
    if (value == 1) {
        [self.playTimer invalidate];
        [self.audioTimer invalidate];
    }
    
    if (_playProgress) {
        _playProgress(value);
    }
    
    if (value == 1)  return;

    CGFloat level = [self.allLevels.firstObject floatValue];
    [self.currentLevels removeLastObject];
    [self.currentLevels insertObject:@(level) atIndex:0];
    if ( self.allLevels.count ) {
        [self.allLevels removeObjectAtIndex:0];
    }
    [self updateLevelLayer];
//    NSLog(@"==============================================");
}

@end
