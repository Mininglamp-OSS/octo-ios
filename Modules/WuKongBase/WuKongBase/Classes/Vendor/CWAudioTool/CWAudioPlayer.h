//
//  CWAudioPlayer.h
//  CWAudioTool
//
//  Created by chavez on 2017/9/26.
//  Copyright © 2017年 chavez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "CWSington.h"

@interface CWAudioPlayer : NSObject

/**
 *  单例
 */
singtonInterface;

/**
 播放音频

 @param audioPath 音频的本地路径
 @return 音频播放器
 */
- (AVAudioPlayer *)playAudioWith:(NSString *)audioPath;

/**
 恢复播放音频
 */
- (void)resumeCurrentAudio;

/**
 暂停播放
 */
- (void)pauseCurrentAudio;

/**
 停止播放
 */
- (void)stopCurrentAudio;


/**
 播放进度
 */
@property (nonatomic, assign, readonly) float progress;

@end
