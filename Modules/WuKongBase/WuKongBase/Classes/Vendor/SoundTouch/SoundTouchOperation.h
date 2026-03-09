/*
 ReadMe.strings
 
 Created by chuliangliang on 15-1-14.
 Copyright (c) 2014年 aikaola. All rights reserved.
 */

 #import <Foundation/Foundation.h>
typedef struct  sountTouchConfig {
    int sampleRate;     //采样率 <这里使用8000 原因: 录音是采样率:8000>
    int tempoChange;    //速度 <变速不变调>
    int pitch;          // 音调
    int rate;           //声音速率
} MySountTouchConfig;


@interface SoundTouchOperation : NSOperation
{
    id target;
    SEL action;
    MySountTouchConfig MysoundConfig;
}
- (id)initWithTarget:(id)tar action:(SEL)ac SoundTouchConfig:(MySountTouchConfig)soundConfig soundFile:(NSData *)file;
@end
