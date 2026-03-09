//
//  WKVoicePanel.m
//  WuKongBase
//
//  Created by tt on 2020/1/15.
//

#import "WKVoicePanel.h"
#import "Mp3Recorder.h"
#import "CWVoiceView.h"
#import "CWFlieManager.h"
#import "CWRecorder.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import "CWRecordModel.h"

#define MAXWaveformNum 30

@interface WKVoicePanel ()<CWTalkBackViewDelegate,CWAudioPlayViewDelegate,CWRecordViewDelegate,CWVoiceChangePlayViewDelegate>
@property(nonatomic,strong) CWVoiceView *voiceView;
@end

@implementation WKVoicePanel

-(instancetype) initWithContext:(id<WKConversationContext>)context {
    self = [super initWithContext:context];
    if (self) {
        [self setBackgroundColor:[WKApp shared].config.backgroundColor];
    }
    return self;
}
-(void) layoutPanel:(CGFloat)height {
    [super layoutPanel:height];
    if(!_voiceView) {
        _voiceView = [[CWVoiceView alloc] initWithFrame:CGRectMake(0, 0,WKScreenWidth, height)];
        _voiceView.talkBackViewDelegate = self;
        _voiceView.playViewDelegate = self;
        _voiceView.voiceChangePlayDelegate = self;
        _voiceView.voiceRecordViewDelegate = self;
        [_voiceView setupSubViews];
        [_voiceView setBackgroundColor:[WKApp shared].config.backgroundColor];
        [self.contentView addSubview:_voiceView];
    }
    
    _voiceView.frame = self.contentView.bounds;
}

#pragma mark - CWTalkBackViewDelegate

- (void)beginRecord{
    [self.context startRecordingVoiceMessage];
}

-(void) talkBackViewSendRecord:(CWTalkBackView*) view second:(NSInteger)second {
    NSData *voiceData = [[NSData alloc] initWithContentsOfFile:[CWRecorder shareInstance].recordPath];
    if(voiceData) {
        [self sendVoiceMessage:voiceData second:second waveform:[CWRecordModel shareInstance].levels];
        [CWFlieManager removeFile:[CWRecorder shareInstance].recordPath];
    }
}

#pragma mark - CWAudioPlayViewDelegate
- (void)audioPlayView:(CWAudioPlayView *)view second:(NSInteger)second {
     NSData *voiceData = [[NSData alloc] initWithContentsOfFile:[CWRecordModel shareInstance].path];
    if(voiceData) {
        [self sendVoiceMessage:voiceData second:second waveform:[CWRecordModel shareInstance].levels];
        [CWFlieManager removeFile:[CWRecordModel shareInstance].path];
    }
}

#pragma mark - CWVoiceChangePlayViewDelegate

- (void)voiceChangePlayView:(CWVoiceChangePlayView *)view voicePath:(NSString *)path  second:(NSInteger)second {
    NSData *voiceData = [[NSData alloc] initWithContentsOfFile:path];
    if(voiceData) {
        [self sendVoiceMessage:voiceData second:second waveform:[CWRecordModel shareInstance].levels];
        [CWFlieManager removeFile:path];
    }
}

-(void) sendVoiceMessage:(NSData*)voiceData second:(NSInteger)second waveform:(NSArray<NSNumber*>*)waveform{
    if(second<=0) {
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"说话时间太短")];
        return;
    }
    NSData *waveforms = [self cutAudioWaveform:waveform];
    [self.context sendMessage:[WKVoiceContent initWithData:voiceData second:(int)second waveform:waveforms]];
}

-(NSData*) cutAudioWaveform:(NSArray<NSNumber*>*)waveform {
    NSMutableData *filteredSamplesMA = [[NSMutableData alloc]init];
    CGFloat width =  200.0f;
    CGFloat height = 50.0f;
    NSInteger sampleCount = waveform.count;
    NSUInteger binSize = waveform.count / (width * 0.1);
    if(binSize==0) {
        for (NSNumber *wf in waveform) {
            uint8_t v = (uint8_t)(MAX(wf.floatValue * 100.0f, 255));
            [filteredSamplesMA appendBytes:&v length:1];
        }
        return filteredSamplesMA;
    }
    //以binSize为一个样本。每个样本中取一个最大数。也就是在固定范围取一个最大的数据保存，达到缩减目的
    SInt16 maxSample = 0; //sint16两个字节的空间
    for (NSUInteger i= 0; i < sampleCount; i += binSize) {
        uint8_t sampleBin[binSize];
        for (NSUInteger j = 0; j < binSize; j++) {
            if(i+j < waveform.count){
                sampleBin[j] = (uint8_t)(MIN(waveform[i+j].floatValue * 100.0f, 255));
            }
        }
        //选取样本数据中最大的一个数据
        uint8_t value = [self maxValueInArray:sampleBin ofSize:binSize];
        //保存数据
        [filteredSamplesMA appendBytes:&value length:1];
        //将所有数据中的最大数据保存，作为一个参考。可以根据情况对所有数据进行“缩放”
        if (value > maxSample) {
            maxSample = value;
        }
    }
//    //计算比例因子
//    CGFloat scaleFactor = (height * 0.5)/maxSample;
//    //对所有数据进行“缩放”
//    for (NSUInteger i = 0; i < filteredSamplesMA.count; i++) {
//
//        filteredSamplesMA[i] = @([filteredSamplesMA[i] integerValue] * scaleFactor);
//    }
    
    return filteredSamplesMA;
}
//比较大小的方法，返回最大值
- (uint8_t)maxValueInArray:(uint8_t[])values ofSize:(NSUInteger)size {
    uint8_t maxvalue = 0;
    for (int i = 0; i < size; i++) {
        
        if (abs(values[i] > maxvalue)) {
            
            maxvalue = values[i];
        }
    }
    return maxvalue;
}

@end
