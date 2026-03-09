//
//  CWVoiceChangePlayCell.m
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWVoiceChangePlayCell.h"
#import "UIView+CWChat.h"
#import "CWRecordModel.h"
#import "CWAudioPlayer.h"
#import "SoundTouchOperation.h"
#import "WKApp.h"
static CGFloat const levelWidth = 3.0;
static CGFloat const levelMargin = 2.0;

@interface CWVoiceChangePlayCell ()

@property (nonatomic,weak) UIButton *playButton;
@property (nonatomic,weak) UIButton *titleButton;
@property (nonatomic,strong) NSMutableArray *currentLevels; // 当前振幅数组
@property (nonatomic,strong) NSMutableArray *allLevels;     // 所有收集到的振幅,预先保存，用于播放
@property (nonatomic,assign) NSInteger recordDuration;      // 录音时长
@property (nonatomic,weak) CAShapeLayer *levelLayer;        // 振幅layer
@property (nonatomic,strong) UIBezierPath *levelPath;       // 画振幅的path
@property (nonatomic,weak) UILabel *timeLabel;              // 录音时长标签
@property (nonatomic,assign) CGFloat progressValue;
@property (nonatomic,weak) CAShapeLayer *circleLayer;        // 环形进度条
@property (nonatomic,strong) NSDictionary *pitchDict;
@end


@implementation CWVoiceChangePlayCell
{
    NSInteger _allCount; // 记录所有振幅的总个数
    NSInteger _callNumbel;    // 记录定时器方法调用多少次，根据这个来算秒数(每秒10次)
    NSOperationQueue *_soundTouchQueue;
    CGFloat _tempoValue;
    CGFloat _pitchValue;
    CGFloat _rateValue;
}

#pragma mark - lazyLoad
- (NSDictionary *)pitchDict {
    if (_pitchDict == nil) {
        _pitchDict = @{@"原声":@0,
                       @"萝莉":@12,
                       @"大叔":@-7,
                       @"惊悚":@-12,
                       @"空灵":@3,
                       @"搞怪":@7,
                       };
    }
    return _pitchDict;
}

- (NSMutableArray *)allLevels {
    if (_allLevels == nil) {
        _allLevels = [NSMutableArray array];
    }
    return _allLevels;
}

- (NSMutableArray *)currentLevels {
    if (_currentLevels == nil) {
        _currentLevels = [NSMutableArray arrayWithArray:@[@0.05,@0.05,@0.05,@0.05,@0.05,@0.05]];
    }
    return _currentLevels;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initSoundTouchQueue];
        [self setupSubviews];
        _voicePath = [CWRecordModel shareInstance].path;
    }
    return self;
}

- (void)initSoundTouchQueue {
    _soundTouchQueue = [[NSOperationQueue alloc] init];
    _soundTouchQueue.maxConcurrentOperationCount = 1;
}

- (void)setupSubviews {
    self.backgroundColor = [UIColor whiteColor];
    [self setupPlayButton];
    [self setupTitleButton];
//    [self timeLabel];
}

- (void)layoutSubviews {
    self.playButton.center = CGPointMake(self.cw_width / 2.0, self.cw_height / 2.0 - 10);
    self.titleButton.cw_centerX = self.cw_width / 2.0;
    self.titleButton.cw_centerY = (self.cw_height - self.playButton.cw_bottom) / 2 + self.playButton.cw_bottom;
}

#pragma mark - setupUI
- (void)setupPlayButton {
    UIImage *image = [self imageName:@"Conversation/VoiceRecord/aio_voiceChange_effect_0"];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundImage:image forState:UIControlStateNormal];
    [button setImage:nil forState:UIControlStateNormal];
    [button setImage:[self imageName:@"Conversation/VoiceRecord/aio_voiceChange_effect_selected"] forState:UIControlStateSelected];
    [button setImage:[self imageName:@"Conversation/VoiceRecord/aio_voiceChange_effect_pressed"] forState:UIControlStateHighlighted];
    button.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    button.center = CGPointMake(self.cw_width / 2.0, self.cw_height / 2.0 - 10);
    [button addTarget:self action:@selector(playAudio) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:button];
    self.playButton = button;
}

- (void)setupTitleButton {
    UIImage *image = [self imageName:@"Conversation/VoiceRecord/aio_voiceChange_text_select"];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setBackgroundImage:nil forState:UIControlStateNormal];
    [button setBackgroundImage:image forState:UIControlStateSelected];
    [button setTitle:@"原声" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
    button.frame = CGRectMake(0, self.playButton.cw_bottom + 5, image.size.width, image.size.height);
    button.cw_centerX = self.cw_width / 2.0;
    button.cw_centerY = (self.cw_height - self.playButton.cw_bottom) / 2 + self.playButton.cw_bottom;
    [self addSubview:button];
    self.titleButton = button;
}

- (UILabel *)timeLabel {
    if (_timeLabel == nil) {
        UILabel *timeL = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.cw_width, 20)];
        timeL.text = @"0:00";
        timeL.textAlignment = NSTextAlignmentCenter;
        timeL.font = [UIFont systemFontOfSize:12];
        timeL.textColor = [UIColor whiteColor];
        timeL.cw_top = self.playButton.cw_centerY + 5;
        timeL.hidden = YES;
        [self addSubview:timeL];
        _timeLabel = timeL;
    }
    return _timeLabel;
}

- (CAShapeLayer *)levelLayer {
    if (_levelLayer == nil) {
        CGFloat width = 6 * levelWidth + 5 * levelMargin;
        CAShapeLayer *layer = [CAShapeLayer layer];
        layer.frame = CGRectMake(self.playButton.cw_centerX - width / 2, self.playButton.cw_centerY - 20, width, 20);
        layer.strokeColor = [UIColor whiteColor].CGColor;
        layer.lineWidth = levelWidth;
        [self.layer addSublayer:layer];
        _levelLayer = layer;
    }
    return _levelLayer;
}

- (CAShapeLayer *)circleLayer {
    if (_circleLayer == nil) {
        CAShapeLayer *layer = [CAShapeLayer layer];
        layer.frame = self.playButton.frame;
        layer.strokeColor = [UIColorFromRGBA(20, 120, 211, 1.0) CGColor];
//        layer.strokeColor = [[UIColor blueColor] CGColor];
        layer.fillColor = [UIColor clearColor].CGColor;
        layer.lineWidth = 1.5;
//        layer.backgroundColor = [UIColor redColor].CGColor;
        [self.layer addSublayer:layer];
        _circleLayer = layer;
    }
    return _circleLayer;
}

#pragma mark - setter
- (void)setTitle:(NSString *)title {
    _title = title;
    [self.titleButton setTitle:title forState:UIControlStateNormal];
    [self.playButton setBackgroundImage:[self imageName:_imageName] forState:UIControlStateNormal];
}

- (void)setProgressValue:(CGFloat)progressValue {
    _progressValue = progressValue;
    [self updateCircleLayer];
//    [self setNeedsDisplay];
//    [self layoutIfNeeded];
}

#pragma mark - 按钮点击
- (void)playAudio {
    
    self.titleButton.selected = !self.playButton.selected;
    self.playButton.selected = !self.playButton.selected;
//    NSLog(@"按钮点击。。。。%zd",self.playButton.selected);
    __weak typeof(self) weakSelf = self;
    if (self.playButton.selected) {
        if (_playRecordBlock) _playRecordBlock(weakSelf);
    }else {
        if (_endPlayBlock) _endPlayBlock(weakSelf);
    }
    
}

#pragma mark - 变声功能
- (void)playAudioWithPath:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    MySountTouchConfig config;
    config.sampleRate = 11025;
    config.tempoChange = 0;        // -50 - 100
    config.pitch = [self.pitchDict[self.title] intValue]; // -12 - 12
    config.rate = 0;    // -50 - 100
    
    SoundTouchOperation *sdop = [[SoundTouchOperation alloc] initWithTarget:self
                                                                     action:@selector(playVoiceChange:)
                                                           SoundTouchConfig:config soundFile:data];
    [_soundTouchQueue cancelAllOperations];
    [_soundTouchQueue addOperation:sdop];
}

- (void)playVoiceChange:(NSString *)path {
    [[CWAudioPlayer shareInstance] playAudioWith:path];
    self.voicePath = path;
}

// 准备播放
- (void)preparePlayAudio {
    _callNumbel = 0;
    
    _recordDuration = 0;
    [self updateTimeLabel];
    
    _progressValue = 0;
    self.levelLayer.hidden = NO;
    self.timeLabel.hidden = NO;
    self.allLevels = [[CWRecordModel shareInstance].levels mutableCopy];
    [self.currentLevels removeAllObjects];
    _allCount = self.allLevels.count;
    for (NSInteger i = self.allLevels.count - 1 ; i >= self.allLevels.count - 6 ; i--) {
        CGFloat l = 0.05;
        if (i >= 0) {
            l = [self.allLevels[i] floatValue];
        }
        [self.currentLevels addObject:@(l)];
    }

}

#pragma mark - 公有方法
- (void)playingRecord {
//    NSLog(@"playingRecord");
    
    [self preparePlayAudio];

    // 播放音频
    if ([self.title isEqualToString:@"原声"]) {
        [self playVoiceChange:[CWRecordModel shareInstance].path];
    }else {
        [self playAudioWithPath:[CWRecordModel shareInstance].path];
    }
    
}

- (void)updateLevels {
//    NSLog(@"updateLevels:::::::::%zd",self.allLevels.count);
    
    CGFloat value = 1 - (CGFloat)self.allLevels.count / _allCount;
    
    if (value == 1 || self.allLevels.count == 0) {
        __weak typeof(self) weakSelf = self;
        if (_endPlayBlock) {
            _endPlayBlock(weakSelf);
        }
        return;
    }
    
    // 振幅更新
    [self updateLevelLayer];
    // 圆形进度条更新
    self.progressValue = value;
    
    _callNumbel++;
    // 刷新10次增加一秒
    if (_callNumbel % 10 == 0) [self addSeconed];
}

- (void)endPlay {
    // 取消layer的隐式动画
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.levelLayer.hidden = YES;
    [CATransaction commit];
    
    self.timeLabel.hidden = YES;
    self.playButton.selected = NO;
    self.titleButton.selected = NO;
    
    [[CWAudioPlayer shareInstance] stopCurrentAudio]; // 停止播放音频
    
    self.progressValue = 0;
}

#pragma mark - 私有方法
- (void)addSeconed {
    if (_recordDuration == [CWRecordModel shareInstance].duration) {
//        [self.audioTimer invalidate];
        return;
    }
    _recordDuration++;
    
    [self updateTimeLabel];
}

- (void)updateTimeLabel {
    NSString *text ;
    if (_recordDuration < 60) {
        text = [NSString stringWithFormat:@"0:%02zd",_recordDuration];
    }else {
        NSInteger minutes = _recordDuration / 60;
        NSInteger seconed = _recordDuration % 60;
        text = [NSString stringWithFormat:@"%zd:%02zd",minutes,seconed];
    }
    self.timeLabel.text = text;
}

- (void)updateLevelLayer {
    CGFloat level = [self.allLevels.firstObject floatValue];
    [self.currentLevels removeLastObject];
    [self.currentLevels insertObject:@(level) atIndex:0];
    [self.allLevels removeObjectAtIndex:0];
    
    self.levelPath = [UIBezierPath bezierPath];
    CGFloat height = CGRectGetHeight(self.levelLayer.frame);
    for (int i = 0; i < self.currentLevels.count; i++) {
        CGFloat x = i * (levelWidth + levelMargin) + levelWidth / 2.0;
        CGFloat pathH = [self.currentLevels[i] floatValue] * height;
        CGFloat startY = height / 2.0 - pathH / 2.0;
        CGFloat endY = height / 2.0 + pathH / 2.0;
        [_levelPath moveToPoint:CGPointMake(x, startY)];
        [_levelPath addLineToPoint:CGPointMake(x, endY)];
    }
    
    self.levelLayer.path = _levelPath.CGPath;
}

- (void)updateCircleLayer {
//    NSLog(@"==========================%f",_progressValue);
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat width = CGRectGetWidth(self.circleLayer.frame);
    CGFloat startAngle = -M_PI_2;
    CGFloat angle = _progressValue * M_PI * 2;
    CGFloat endAngle = startAngle + angle;
    [path addArcWithCenter:CGPointMake(width / 2.0, width / 2.0) radius:width / 2.0 - 1.0 startAngle:startAngle endAngle:endAngle clockwise:YES];
    self.circleLayer.path = path.CGPath;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
