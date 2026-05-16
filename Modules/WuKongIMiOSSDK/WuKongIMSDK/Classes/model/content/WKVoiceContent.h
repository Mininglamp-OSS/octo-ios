//
//  WKVoiceContent.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/16.
//

#import <Foundation/Foundation.h>
#import "WKMediaMessageContent.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKVoiceContent : WKMediaMessageContent


/**
 初始化

 @param voiceData 音频数据
 @param second 音频秒长
 @param waveform  音频波浪数据 （可选参数）
 @return <#return value description#>
 */
+ (instancetype)initWithData:(NSData *)voiceData second:(int)second waveform:(NSData*)waveform;


// 音频数据
@property(nonatomic,strong) NSData *voiceData;

// 音频长度（单位秒）
@property(nonatomic,assign) NSInteger second;
// 音频波浪数据 （可选参数）
@property(nonatomic,strong)  NSData *waveform;

@end

NS_ASSUME_NONNULL_END
