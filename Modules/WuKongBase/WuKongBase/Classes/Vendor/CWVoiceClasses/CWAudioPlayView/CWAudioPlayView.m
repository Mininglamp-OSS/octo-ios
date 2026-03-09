//
//  CWAudioPlayView.m
//  QQVoiceDemo
//
//  Created by 陈旺 on 2017/10/4.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWAudioPlayView.h"
#import "UIView+CWChat.h"
#import "CWRecordStateView.h"
#import "CWAudioPlayer.h"
#import "CWRecordModel.h"
#import "CWRecorder.h"
#import "CWVoiceView.h"
#import "WKResource.h"
#import "WuKongBase.h"
@interface CWAudioPlayView ()

@property (nonatomic, weak) CWRecordStateView *stateView;

@property (nonatomic, weak) UIButton *playButton;   // 播放按钮
@property (nonatomic, weak) UIButton *cancelButton; // 取消按钮
@property (nonatomic, weak) UIButton *sendButton;   // 发送按钮


@end



@implementation CWAudioPlayView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
//        _progressValue = 0.8;
        [self setupSubViews];
    }
    return self;
}

- (void)setupSubViews {
    
    self.backgroundColor = WKApp.shared.config.backgroundColor;
    [self stateView];
    [self playButton];
    [self setupSendButtonAndCancelButton];
    [self listenProgress]; // 监听进度
}

#pragma mark - subviews
- (UIButton *)playButton {
    if (_playButton == nil) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setImage:[self imageName:@"Conversation/VoiceRecord/aio_record_play_nor"] forState:UIControlStateNormal];
        [btn setImage:[self imageName:@"Conversation/VoiceRecord/aio_record_play_press"] forState:UIControlStateHighlighted];
        [btn setImage:[self imageName:@"Conversation/VoiceRecord/aio_record_stop_nor"] forState:UIControlStateSelected];
        UIImage *image = [self imageName:@"Conversation/VoiceRecord/aio_voice_button_nor"];
        btn.frame = CGRectMake(0, 0, image.size.width, image.size.height);
        btn.center = CGPointMake(self.center.x, self.stateView.cw_bottom + image.size.width / 2);
        [btn addTarget:self action:@selector(playRecord) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        _playButton = btn;
    }
    return _playButton;
}

- (CWRecordStateView *)stateView {
    if (_stateView == nil) {
        CWRecordStateView *stateView = [[CWRecordStateView alloc] initWithFrame:CGRectMake(0, 10, self.cw_width, 50)];
        [self addSubview:stateView];
        stateView.recordState = CWRecordStatePreparePlay;
        _stateView = stateView;
    }
    return  _stateView;
}

- (void)setupSendButtonAndCancelButton {
    CGFloat height = 40;
    UIButton *cancelBtn = [self buttonWithFrame:CGRectMake(0, self.cw_height - height, self.cw_width / 2.0, height) title:LLang(@"取消") titleColor:kSelectBackGroudColor font:[UIFont systemFontOfSize:18] backImageNor:@"Conversation/VoiceRecord/aio_record_cancel_button" backImageHighled:@"Conversation/VoiceRecord/aio_record_cancel_button_press" sel:@selector(btnClick:)];
    [self addSubview:cancelBtn];
    self.cancelButton = cancelBtn;
    
    UIButton *sendBtn = [self buttonWithFrame:CGRectMake(self.cw_width / 2.0, self.cw_height - height, self.cw_width / 2.0, height) title:LLang(@"发送") titleColor:kSelectBackGroudColor font:[UIFont systemFontOfSize:18] backImageNor:@"Conversation/VoiceRecord/aio_record_send_button" backImageHighled:@"Conversation/VoiceRecord/aio_record_send_button_press" sel:@selector(btnClick:)];
    [self addSubview:sendBtn];
    self.sendButton = sendBtn;
    
}

- (UIButton *)buttonWithFrame:(CGRect)frame title:(NSString *)title titleColor:(UIColor *)titleColor font:(UIFont *)font backImageNor:(NSString *)backImageNor backImageHighled:(NSString *)backImageHighled sel:(SEL)sel{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:titleColor forState:UIControlStateNormal];
    btn.titleLabel.font = font;
    UIImage *newImageNor = [[self imageName:backImageNor] stretchableImageWithLeftCapWidth:2 topCapHeight:2];
    UIImage *newImageHighled = [[self imageName:backImageHighled] stretchableImageWithLeftCapWidth:2 topCapHeight:2];
    [btn setBackgroundImage:newImageNor forState:UIControlStateNormal];
    [btn setBackgroundImage:newImageHighled forState:UIControlStateHighlighted];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

#pragma mark - play/stop
- (void)playRecord {
    self.playButton.selected = !self.playButton.selected;
    if (self.playButton.selected) {
        self.stateView.recordState = CWRecordStatePlay;
        [[CWAudioPlayer shareInstance] playAudioWith:[CWRecordModel shareInstance].path];
    }else {
        [self stopPlay];
    }
}

- (void)stopPlay {
    self.playButton.selected = NO;
    self.stateView.recordState = CWRecordStatePreparePlay;
    [[CWAudioPlayer shareInstance] stopCurrentAudio];
    _progressValue = 0;
    [self setNeedsDisplay];
    [self layoutIfNeeded];
}

- (void)btnClick:(UIButton *)btn {
//    NSLog(@"%@",btn.titleLabel.text);
    
    [self stopPlay];
    if (btn == self.sendButton) { // 发送
        if(_delegate&&[_delegate respondsToSelector:@selector(audioPlayView:second:)]) {
            [_delegate audioPlayView:self second:self.stateView.recordDuration];
        }
    }else {
        NSLog(@"取消发送并删除录音");
        [[CWRecorder shareInstance] deleteRecord];
    }
    [(CWVoiceView *)self.superview.superview.superview setState:CWVoiceStateDefault];
    [self removeFromSuperview];
}

#pragma mark 监听环形进度条更新
- (void)listenProgress {
    __weak typeof(self) weakSelf = self;
    self.stateView.playProgress = ^(CGFloat progress) {
        if (progress == 1) {
            progress = 0;
            [weakSelf stopPlay];
        }
        self->_progressValue = progress;
        [weakSelf setNeedsDisplay];
        [weakSelf layoutIfNeeded];
    };
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    UIImage *image = [self imageName:@"Conversation/VoiceRecord/aio_voice_button_nor"];
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSetLineWidth(ctx, 2.0f);
    
    CGContextSetStrokeColorWithColor(ctx, [UIColorFromRGBA(214, 219, 222, 1.0) CGColor]);
    CGContextAddArc(ctx, self.center.x, self.stateView.cw_bottom + image.size.width / 2, image.size.width / 2, 0, M_PI * 2, 0);
    CGContextStrokePath(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, [kSelectBackGroudColor CGColor]);
    CGFloat startAngle = -M_PI_2;
    CGFloat angle = self.progressValue * M_PI * 2;
    CGFloat endAngle = startAngle + angle;
    CGContextAddArc(ctx, self.center.x, self.stateView.cw_bottom + image.size.width / 2, image.size.width / 2, startAngle, endAngle, 0);
    CGContextStrokePath(ctx);
    
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
