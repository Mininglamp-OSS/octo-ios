//
//  CWVoiceChangePlayView.m
//  QQVoiceDemo
//
//  Created by chavez on 2017/10/11.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import "CWVoiceChangePlayView.h"
#import "UIView+CWChat.h"
#import "CWVoiceChangePlayCell.h"
#import "CWAudioPlayer.h"
#import "CWRecordModel.h"
#import "CWVoiceView.h"
#import "CWRecorder.h"
#import "CWFlieManager.h"
#import "WKApp.h"
@interface CWVoiceChangePlayView()

@property (nonatomic, weak) UIButton *cancelButton; // 取消按钮
@property (nonatomic, weak) UIButton *sendButton;   // 发送按钮

@property (nonatomic,strong) CADisplayLink *playTimer;      // 播放时振幅计时器

@property (nonatomic,weak) CWVoiceChangePlayCell *playingView;

@property (nonatomic,strong) NSMutableArray *imageNames;

@property (nonatomic,weak) UIScrollView *contentScrollView;


@end

@implementation CWVoiceChangePlayView

#pragma mark - lazyLoad
- (NSMutableArray *)imageNames {
    if (_imageNames == nil) {
        _imageNames = [NSMutableArray array];
        for (int i = 0; i < 6; i++) {
            [_imageNames addObject:[NSString stringWithFormat:@"Conversation/VoiceRecord/aio_voiceChange_effect_%d",i]];
        }
    }
    return _imageNames;
}


- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (void)setupSubviews {
    [self setupContentScrollView];
    [self setupSendButtonAndCancelButton];
}
#pragma mark - setupUI
- (void)setupContentScrollView {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    scrollView.backgroundColor = [UIColor whiteColor];
    scrollView.bounces = YES;
    scrollView.cw_height = scrollView.cw_height - 40;
    scrollView.showsVerticalScrollIndicator = NO;
    [self addSubview:scrollView];
    self.contentScrollView = scrollView;
    
    NSArray *titles = @[@"原声",@"萝莉",@"大叔",@"惊悚",@"空灵",@"搞怪"];
    CGFloat width = self.cw_width / 4;
    CGFloat height = width + 10;
    __weak typeof(self) weakSelf = self;
    for (int i = 0; i < self.imageNames.count; i++) {
        CWVoiceChangePlayCell *cell = [[CWVoiceChangePlayCell alloc] initWithFrame:CGRectMake(i%4 * width, i / 4 * height, width, height)];
        cell.center = scrollView.center;
        cell.imageName = self.imageNames[i];
        cell.title = titles[i];
        [self.contentScrollView addSubview:cell];
        [UIView animateWithDuration:0.25 animations:^{
            cell.frame = CGRectMake(i%4 * width, i / 4 * height, width, height);
        } completion:^(BOOL finished) {
            cell.frame = CGRectMake(i%4 * width, i / 4 * height, width, height);
        }];
        cell.playRecordBlock = ^(CWVoiceChangePlayCell *cellBlock) {
            [weakSelf.playTimer invalidate];
            if (weakSelf.playingView != cellBlock) {
                [weakSelf.playingView endPlay];
            }
            [cellBlock playingRecord];
            weakSelf.playingView = cellBlock;
            [weakSelf startPlayTimer];
        };
        cell.endPlayBlock = ^(CWVoiceChangePlayCell *cellBlock) {
            [weakSelf.playTimer invalidate];
            [cellBlock endPlay];
        };
        if (i == self.imageNames.count - 1) {
            CGFloat h = i / 4 * height;
            if (h < self.cw_height - self.cancelButton.cw_height) h = self.cw_height - self.cancelButton.cw_height + 1;
            self.contentScrollView.contentSize = CGSizeMake(0, h);
        }
    }
    
}


- (void)setupSendButtonAndCancelButton {
    CGFloat height = 40;
    UIButton *cancelBtn = [self buttonWithFrame:CGRectMake(0, self.cw_height - height, self.cw_width / 2.0, height) title:@"取消" titleColor:kSelectBackGroudColor font:[UIFont systemFontOfSize:18] backImageNor:@"Conversation/VoiceRecord/aio_record_cancel_button" backImageHighled:@"Conversation/VoiceRecord/aio_record_cancel_button_press" sel:@selector(btnClick:)];
    [self addSubview:cancelBtn];
    self.cancelButton = cancelBtn;
    
    UIButton *sendBtn = [self buttonWithFrame:CGRectMake(self.cw_width / 2.0, self.cw_height - height, self.cw_width / 2.0, height) title:@"发送" titleColor:kSelectBackGroudColor font:[UIFont systemFontOfSize:18] backImageNor:@"Conversation/VoiceRecord/aio_record_send_button" backImageHighled:@"Conversation/VoiceRecord/aio_record_send_button_press" sel:@selector(btnClick:)];
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

#pragma mark - playTimer
- (void)startPlayTimer {
//    _allCount = self.allLevels.count;
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
    [self.playingView updateLevels];
}

- (void)stopPlay {
    [[CWAudioPlayer shareInstance] stopCurrentAudio];
}

- (void)btnClick:(UIButton *)btn {
    //    NSLog(@"%@",btn.titleLabel.text);
    
    [self stopPlay];
    if (btn == self.sendButton) { // 发送
        NSLog(@"发送...path: %@",self.playingView.voicePath);
        if(self.delegate && [self.delegate respondsToSelector:@selector(voiceChangePlayView:voicePath:second:)]) {
            [self.delegate voiceChangePlayView:self voicePath:self.playingView.voicePath second:[CWRecordModel shareInstance].duration];
        }
    }else {
        NSLog(@"取消发送并删除录音/删除变声文件");
        [[CWRecorder shareInstance] deleteRecord];
        [CWFlieManager removeFile:[CWFlieManager soundTouchSavePathWithFileName:self.playingView.voicePath.lastPathComponent]];
    }
    
    [(CWVoiceView *)self.superview.superview.superview setState:CWVoiceStateDefault];
    [UIView transitionWithView:self duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [self removeFromSuperview];
    } completion:nil];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end
