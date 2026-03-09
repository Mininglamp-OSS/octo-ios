//
//  CWRecorder.h
//  CWAudioTool
//
//  Created by chavez on 2017/9/26.
//  Copyright © 2017年 chavez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "CWSington.h"
#import "CWRecordProtocol.h"

#define CWDocumentPath [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]

typedef void(^Success)(BOOL ret);


@interface CWRecorder : NSObject

@property (nonatomic,copy, readonly) NSString *recordPath;
@property (nonatomic,weak) id<CWRecorderDelegate> delegate; // 代理
@property (nonatomic,assign) BOOL isRecording;
/**
 *  单例
 */
singtonInterface;

/**
 *  开始录音
 */
- (void)beginRecordWithRecordPath:(NSString *)recordPath;

/**
 *  结束录音
 */
- (void)endRecord;

/**
 *  暂停录音
 */
- (void)pauseRecord;

/**
 *  删除录音
 */
- (void)deleteRecord;

/**
 *  返回分贝值
 */
- (float)levels;

@end
