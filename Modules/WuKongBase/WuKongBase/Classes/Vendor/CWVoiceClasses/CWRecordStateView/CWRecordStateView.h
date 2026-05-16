//
//  CWRecordStateView.h
//  QQVoiceDemo
//
//  Created by 陈旺 on 2017/9/2.
//  Copyright © 2017年 陈旺. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CWSington.h"

typedef NS_ENUM(NSInteger,CWRecordState) {
    CWRecordStateDefault = 0,       // 按住说话
    CWRecordStateClickRecord,       // 点击录音
    CWRecordStateTouchChangeVoice,  // 按住变声
    CWRecordStateListen ,           // 试听
    CWRecordStateCancel,            // 取消
    CWRecordStateSend,              // 发送
    CWRecordStatePrepare,           // 准备中
    CWRecordStateRecording,         // 录音中
    CWRecordStatePreparePlay,       // 准备播放
    CWRecordStatePlay               // 播放
} ;

#define WeakSelf(type)  __weak typeof(type) weak##type = type;

#define MaxRecordTime 60 // 最大录音秒长

@interface CWRecordStateView : UIView

@property (nonatomic,assign) CWRecordState recordState; // 录音状态

@property (nonatomic,copy) void(^playProgress)(CGFloat progress);

@property (nonatomic,copy) void(^recordDurationProgress)(NSInteger progress);

@property (nonatomic,assign, readonly) NSInteger recordDuration;      // 录音时长

// 开始录音
- (void)beginRecord;

// 结束录音
- (void)endRecord;

@end
