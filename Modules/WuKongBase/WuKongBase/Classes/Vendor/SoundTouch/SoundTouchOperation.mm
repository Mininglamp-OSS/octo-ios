/*
 ReadMe.strings
 
 Created by chuliangliang on 15-1-14.
 Copyright (c) 2014年 aikaola. All rights reserved.
 */

#import "SoundTouchOperation.h"
#include "SoundTouch.h"
#include "WaveHeader.h"
#import "CWFlieManager.h"
#import "CWRecordModel.h"

@interface SoundTouchOperation ()
@property (nonatomic, strong) NSData *voicefileData;
@end
@implementation SoundTouchOperation
- (id)initWithTarget:(id)tar action:(SEL)ac SoundTouchConfig:(MySountTouchConfig)soundConfig soundFile:(NSData *)file

{
    self = [super init];
    if (self) {
        target = tar;
        action = ac;
        MysoundConfig = soundConfig;
        self.voicefileData =file;
    }
    return self;
}


- (void)main {
        NSData *soundData = self.voicefileData;
        
        
        soundtouch::SoundTouch mSoundTouch;
        mSoundTouch.setSampleRate(MysoundConfig.sampleRate); //采样率
        mSoundTouch.setChannels(1);       //设置声音的声道
        mSoundTouch.setTempoChange(MysoundConfig.tempoChange);    //这个就是传说中的变速不变调
        mSoundTouch.setPitchSemiTones(MysoundConfig.pitch); //设置声音的pitch (集音高变化semi-tones相比原来的音调) //男: -8 女:8
        mSoundTouch.setRateChange(MysoundConfig.rate);     //设置声音的速率
        mSoundTouch.setSetting(SETTING_SEQUENCE_MS, 40);
        mSoundTouch.setSetting(SETTING_SEEKWINDOW_MS, 15); //寻找帧长
        mSoundTouch.setSetting(SETTING_OVERLAP_MS, 6);  //重叠帧长
        
        NSLog(@"tempoChangeValue:%d  pitchSemiTones:%d  rateChange:%d",MysoundConfig.tempoChange,MysoundConfig.pitch,MysoundConfig.rate);
        
        NSMutableData *soundTouchDatas = [[NSMutableData alloc] init];
        
        if (soundData != nil) {
            char *pcmData = (char *)soundData.bytes;
            NSUInteger pcmSize = soundData.length;
            NSUInteger nSamples = pcmSize / 2;
            mSoundTouch.putSamples((short *)pcmData, (unsigned int)nSamples);
            short *samples = new short[pcmSize];
            int numSamples = 0;
            do {
                memset(samples, 0, pcmSize);
                //short samples[nSamples];
                numSamples = mSoundTouch.receiveSamples(samples, (unsigned int)pcmSize);
                [soundTouchDatas appendBytes:samples length:numSamples*2];
                
            } while (numSamples > 0);
            delete [] samples;
        }
        
        
        NSMutableData *wavDatas = [[NSMutableData alloc] init];
        NSUInteger fileLength = soundTouchDatas.length;
        void *header = createWaveHeader((int)fileLength, 1, MysoundConfig.sampleRate, 16);
        [wavDatas appendBytes:header length:44];
        [wavDatas appendData:soundTouchDatas];
        
        
       
//        NSString *savewavfilepath = [self createSavePath];
        NSString *savewavfilepath = [CWFlieManager soundTouchSavePathWithFileName:[CWRecordModel shareInstance].path.lastPathComponent];
//        NSLog(@"SoundTouch 保存路径 : %@ ",savewavfilepath);
        BOOL isSave = [wavDatas writeToFile:savewavfilepath atomically:YES];
//        [soundTouchDatas release];
//        [wavDatas release];

        if (isSave && !self.isCancelled) {
            [target performSelectorOnMainThread:action withObject:savewavfilepath waitUntilDone:NO];
        }
    
}

////创建文件存储路径
//- (NSString *)createSavePath {
//    //文件名使用 "voiceFile+当前时间的时间戳"
//    NSString *fileName = [self createFileName];
//
//    NSString *documentDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//    NSString *wavfilepath = [NSString stringWithFormat:@"%@/SoundTouch",documentDir];
//
//    NSString *writeFilePath = [NSString stringWithFormat:@"%@/%@.wav",wavfilepath, fileName];
//    BOOL isExist =  [[NSFileManager defaultManager]fileExistsAtPath:writeFilePath];
//    if (isExist) {
//        //如果存在则移除 以防止 文件冲突
//        NSError *err = nil;
//        [[NSFileManager defaultManager]removeItemAtPath:writeFilePath error:&err];
//    }
//
//    BOOL isExistDic =  [[NSFileManager defaultManager]fileExistsAtPath:wavfilepath];
//    if (!isExistDic) {
//         [[NSFileManager defaultManager] createDirectoryAtPath:wavfilepath withIntermediateDirectories:YES attributes:nil error:nil];
//    }
//
//    return writeFilePath;
//}
//
//- (NSString *)createFileName {
//    NSString *fileName = [NSString stringWithFormat:@"voiceFile%lld",(long long)[NSDate timeIntervalSinceReferenceDate]];
//    return fileName;
//}
@end
