//
//  CWAudioPlayer.m
//  CWAudioTool
//
//  Created by chavez on 2017/9/26.
//  Copyright © 2017年 chavez. All rights reserved.
//

#import "CWAudioPlayer.h"

@interface CWAudioPlayer()

/** 音频播放器 */
@property (nonatomic ,strong) AVAudioPlayer *player;

@end

@implementation CWAudioPlayer

singtonImplement(CWAudioPlayer);

- (AVAudioPlayer *)playAudioWith:(NSString *)audioPath {
    [self stopCurrentAudio]; // 播放之前 先结束当前播放
    // 设置为扬声器播放
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    NSURL *url = [NSURL URLWithString:audioPath];
    if (url == nil) {
        url = [[NSBundle mainBundle] URLForResource:audioPath.lastPathComponent withExtension:nil];
    }
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    NSLog(@"准备播放...%@",url);
    [self.player prepareToPlay];
//    NSLog(@"播放...");
    [self.player play];
    return self.player;
}

- (void)resumeCurrentAudio {
    [self.player play];
}

- (void)pauseCurrentAudio {
    [self.player pause];
}

- (void)stopCurrentAudio {
    [self.player stop];
}

- (float)progress {
    return self.player.currentTime / self.player.duration;
}

@end
