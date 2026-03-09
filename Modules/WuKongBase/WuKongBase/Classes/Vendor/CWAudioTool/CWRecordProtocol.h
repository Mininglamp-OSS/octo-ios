//
//  CWRecordProcotol.h
//  CWAudioTool
//
//  Created by chavez on 2017/9/28.
//  Copyright © 2017年 chavez. All rights reserved.
//

#import <UIKit/UIKit.h>


@protocol CWRecorderDelegate <NSObject>

/**
 * 准备中
 */
- (void)recorderPrepare;

/**
 * 录音中
 */
- (void)recorderRecording;

/**
 * 录音失败
 */
- (void)recorderFailed:(NSString *)failedMessage;

@end

