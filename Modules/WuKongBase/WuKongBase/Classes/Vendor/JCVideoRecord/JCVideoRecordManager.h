//
//  JCVideoRecordManager.h
//  Pods
//
//  Created by zhengjiacheng on 2017/8/31.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "UIView+WK.h"
@protocol JCVideoRecordManagerDelegate <NSObject>
//录制结束
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;

//录制时间
- (void)recordTimeCurrentTime:(CGFloat)currentTime totalTime:(CGFloat)totalTime;
@end

@interface JCVideoRecordManager : NSObject
@property (nonatomic, weak) id<JCVideoRecordManagerDelegate> delegate;
//摄像头视图层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preViewLayer;

// 准备录制
- (void)prepareForRecord;

// 开始录制
- (void)startRecordToFile:(NSURL *)outPutFile;

// 停止录制
- (void)stopCurrentVideoRecording;

// 切换摄像头
- (void)switchCamera;

// 设置对焦
- (void)setFoucusWithPoint:(CGPoint)point;

//压缩视频
- (void)compressVideo:(NSURL *)inputFileURL complete:(void(^)(BOOL success, NSURL* outputUrl))complete;

+ (CGFloat)getfileSize:(NSString *)filePath;

+ (void)getCameraAuth:(void(^)(BOOL boolValue, NSString *tipText))isAuthorized;

// 缓存路径
//- (NSURL*)cacheFilePath:(BOOL)input;

@property(nonatomic,strong)NSURL * videoPath;

/**
 *  拍照
 *
 *  @param block
 */
- (void)takePhotoWithImageBlock:(void (^)(UIImage *orgImg))block;


@end




