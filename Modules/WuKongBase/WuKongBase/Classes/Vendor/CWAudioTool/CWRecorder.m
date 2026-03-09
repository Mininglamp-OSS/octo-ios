//
//  CWRecorder.m
//  CWAudioTool
//
//  Created by chavez on 2017/9/26.
//  Copyright © 2017年 chavez. All rights reserved.
//

#import "CWRecorder.h"
#define ALPHA 0.02f                 // 音频振幅调解相对值 (越小振幅就越高)
#import "WKRNNoise.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
@interface CWRecorder ()

@property (nonatomic, copy) Success block;

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;

@end

@implementation CWRecorder

singtonImplement(CWRecorder);

- (BOOL)initAudioRecorder
{
    // 0. 设置录音会话
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    // 1. 确定录音存放的位置
    NSURL *url = [NSURL URLWithString:self.recordPath];
    
    // 2. 设置录音参数
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    // 设置编码格式
    [recordSettings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey: AVFormatIDKey];
    // 采样率
    [recordSettings setValue :[NSNumber numberWithFloat:8000] forKey: AVSampleRateKey];
    // 通道数
    [recordSettings setValue :[NSNumber numberWithInt:1] forKey: AVNumberOfChannelsKey];
     [recordSettings setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    //音频质量,采样质量
    [recordSettings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
    
    // 3. 创建录音对象
    NSError *error = nil;
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSettings error:&error];
    _audioRecorder.meteringEnabled = YES;
    if (error) {
        NSLog(@"%@",error);
        return NO;
    }
    return YES;
}

- (void)beginRecordWithRecordPath:(NSString *)recordPath {
    NSLog(@"------%@",recordPath);
    _isRecording = YES;
    _recordPath = recordPath;
//    NSLog(@"创建中...");
    if (self.delegate && [self.delegate respondsToSelector:@selector(recorderPrepare)]) {
        [self.delegate recorderPrepare];
    }
    if (![self initAudioRecorder]) { // 初始化录音机
        NSLog(@"录音机创建失败...");
        if (self.delegate && [self.delegate respondsToSelector:@selector(recorderFailed:)]) {
            [self.delegate recorderFailed:@"录音器创建失败"];
        }
        return;
    };
//    NSLog(@"创建完成...");
    [self micPhonePermissions:^(BOOL ishave) {
        if (ishave) {
            [self startRecording];
        }else {
            [self showPermissionsAlert];
//            NSLog(@"麦克风未开启权限");
        }
    }];
}

- (void)startRecording {
//    NSLog(@"startRecording...");
    if (!_isRecording) {
        return;
    }
//    NSLog(@"初始化...");
    if (![self.audioRecorder prepareToRecord]) {
        NSLog(@"初始化录音机失败");
        if (self.delegate && [self.delegate respondsToSelector:@selector(recorderFailed:)]) {
            [self.delegate recorderFailed:@"录音器初始化失败"];
        }
        return;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(recorderRecording)]) {
        [self.delegate recorderRecording];
    }
    [self.audioRecorder record];
    
    
}

- (void)endRecord {
    _isRecording = NO;
    [self.audioRecorder stop];
//    NSLog(@"recordForNoNoise----1>%@",self.recordPath);
//    NSString *recordForNoNoise = [NSString stringWithFormat:@"%@_nonoise",self.recordPath];
//    
//    NSError *error = [WKRNNoise.shared rnnoiseProcess:self.recordPath saveFilePath:recordForNoNoise];
//    if(!error) {
//        NSLog(@"recordForNoNoise----2>%@",recordForNoNoise);
//        [WKFileUtil removeFileOfPath:self.recordPath];
//        [WKFileUtil moveFileFromPath:recordForNoNoise toPath:self.recordPath];
//    }
    
    
}

- (void)pauseRecord {
    [self.audioRecorder pause];
}

- (void)deleteRecord {
    _isRecording = NO;
    [self.audioRecorder stop];
    [self.audioRecorder deleteRecording];
}

- (float)levels {
    [self.audioRecorder updateMeters];
    double aveChannel = pow(10, (ALPHA * [self.audioRecorder averagePowerForChannel:0]));
    if (aveChannel <= 0.05f) aveChannel = 0.05f;
    
    if (aveChannel >= 1.0f) aveChannel = 1.0f;
    
    return aveChannel;
    
}

// 判断麦克风权限
- (void)micPhonePermissions:(void (^)(BOOL ishave))block  {
    __block BOOL ret = NO;
    AVAudioSession *avSession = [AVAudioSession sharedInstance];
    if ([avSession respondsToSelector:@selector(requestRecordPermission:)]) {
        [avSession requestRecordPermission:^(BOOL available) {
            if (available) ret = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block) block(ret);
            });
        }];
    }
}

- (void)showPermissionsAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法录音" message:@"请在“设置-隐私-麦克风”中允许访问麦克风。" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:action];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
