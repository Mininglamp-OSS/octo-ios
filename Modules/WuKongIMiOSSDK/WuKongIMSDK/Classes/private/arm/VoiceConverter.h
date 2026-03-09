//
//  VoiceConverter.h
//  Jeans
//
//  Created by Jeans Huang on 12-7-22.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "NarrowBandWavToAmr.h"
#import "WidthBandWavToAmr.h"

//声音采样率
typedef NS_ENUM(NSInteger,Sample_Rate)
{
    Sample_Rate_16000 = 0,        //16K(默认)
    Sample_Rate_8000 = 1,         //8K
    Sample_Rate_44100 = 2,        //44K
};



@interface VoiceConverter : NSObject

/**
 *  转换wav到amr
 *
 *  @param aWavPath  wav文件路径
 *  @param aSavePath amr保存路径
 *
 *  @return 0失败 1成功
 */
+ (int)EncodeWavToAmr:(NSString *)aWavPath amrSavePath:(NSString *)aSavePath sampleRateType:(Sample_Rate)sampleRateType;

/**
 *  转换amr到wav
 *
 *  @param aAmrPath  amr文件路径
 *  @param aSavePath wav保存路径
 *
 *  @return 0失败 1成功
 */
+ (int)DecodeAmrToWav:(NSString *)aAmrPath wavSavePath:(NSString *)aSavePath sampleRateType:(Sample_Rate)sampleRateType;

+ (NSDictionary*)GetAudioRecorderSettingDictWithSampleRateType:(Sample_Rate)sampleRateType;

@end
