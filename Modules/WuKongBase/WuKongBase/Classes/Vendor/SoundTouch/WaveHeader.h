//
//  WaveHeader.h
//  PCM2Wave
//
//  Created by hejinlai on 13-6-18.
//  Copyright (c) 2013年 yunzhisheng. All rights reserved.
//

#ifndef PCM2Wave_WaveHeader_h
#define PCM2Wave_WaveHeader_h

void *createWaveHeader(int fileLength, short channel, int sampleRate, short bitPerSample);

#endif
