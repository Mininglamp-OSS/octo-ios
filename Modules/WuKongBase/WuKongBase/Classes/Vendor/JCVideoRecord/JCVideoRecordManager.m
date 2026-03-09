//
//  JCVideoRecordManager.m
//  Pods
//
//  Created by zhengjiacheng on 2017/8/31.
//
//

#import "JCVideoRecordManager.h"
#import <WuKongBase/UIImage+WKResize.h>

#import "WuKongBase.h"

static const CGFloat KTimerInterval = 0.02;  //进度条timer
static const CGFloat KMaxRecordTime = 10;    //最大录制时间

@interface JCVideoRecordManager() <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;                //媒体（音、视频）捕获会话
@property (nonatomic, strong) AVCaptureDeviceInput *mediaDeviceInput;          //视频输入
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;          //音频输入
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;       //视频文件输出
@property (nonatomic ,strong) AVCaptureStillImageOutput *imageOutput; /// 图片文件输出
@property (nonatomic, strong) AVCaptureConnection *captureConnection;          //输入输出对象连接

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CGFloat recordTime;                              //录制时间

@property(nonatomic,assign) BOOL isTakePicture; // 是否是拍照
@end

@implementation JCVideoRecordManager

- (instancetype)init{
    self = [super init];
    if (self) {
        self.captureSession = [[AVCaptureSession alloc]init];
        self.movieFileOutput = [[AVCaptureMovieFileOutput alloc]init];
        AVCaptureStillImageOutput *tmpOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];//输出jpeg
        tmpOutput.outputSettings = outputSettings;
        self.imageOutput = tmpOutput;
        //后台播放音频时需要注意加以下代码，否则会获取音频设备失败
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVideoRecording error:nil];
        [[AVAudioSession sharedInstance] setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        [self prepareForRecord];
    }
    return self;
}



#pragma mark - 获取权限
+ (void)getCameraAuth:(void(^)(BOOL boolValue, NSString *tipText))isAuthorized{
    __weak typeof(self) instance = self;
    //获取视频权限
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                 completionHandler:^(BOOL granted) {
                                     if (granted) {
                                         [instance getCameraAuth:isAuthorized];
                                     }else{
                                         isAuthorized(NO, LLang(@"没有获得相机权限"));
                                     }
                                 }];
    }else if (authStatus == AVAuthorizationStatusAuthorized){
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            isAuthorized(granted, LLang(@"没有获得麦克风权限"));
        }];
    }else{
        isAuthorized(NO, LLang(@"没有获得相机权限"));
    }
}

#pragma mark - 摄像头视图层
- (AVCaptureVideoPreviewLayer *)preViewLayer{
    if (!_preViewLayer) {
        _preViewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        _preViewLayer.masksToBounds = YES;
        _preViewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _preViewLayer;
}

#pragma mark 视频输入
- (AVCaptureDeviceInput *)mediaDeviceInput{
    if (!_mediaDeviceInput) {
        __block AVCaptureDevice *backCamera  = nil;
        NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        [cameras enumerateObjectsUsingBlock:^(AVCaptureDevice *camera, NSUInteger idx, BOOL * _Nonnull stop) {
            if(camera.position == AVCaptureDevicePositionBack){
                backCamera = camera;
            }
        }];
        [self setExposureModeWithDevice:backCamera];
        _mediaDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:nil];
    }
    return _mediaDeviceInput;
}

#pragma mark 音频输入
- (AVCaptureDeviceInput *)audioDeviceInput{
    if (!_audioDeviceInput) {
        NSError *error;
        _audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    }
    return _audioDeviceInput;
}

#pragma mark - 输入输出对象连接
- (AVCaptureConnection *)captureConnection{
    if(!_captureConnection) {
        if(self.isTakePicture) {
            
        }
    }
    return _captureConnection = _captureConnection ? : [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
}

#pragma mark 配置曝光模式 设置持续曝光模式
- (void)setExposureModeWithDevice:(AVCaptureDevice *)device{
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    NSError *error = nil;
    [device lockForConfiguration:&error];
    if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]){
        [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }
    [device unlockForConfiguration];
}

#pragma mark 计时器相关
- (NSTimer *)timer{
    if (!_timer){
        _timer = [NSTimer scheduledTimerWithTimeInterval:KTimerInterval target:self selector:@selector(fire:) userInfo:nil repeats:YES];
    }
    return _timer;
}
- (void)fire:(NSTimer *)timer{
    self.recordTime += KTimerInterval;
    if ([self.delegate respondsToSelector:@selector(recordTimeCurrentTime:totalTime:)]) {
        [self.delegate recordTimeCurrentTime:self.recordTime totalTime:KMaxRecordTime];
    }
    if(_recordTime >= KMaxRecordTime){
        [self stopCurrentVideoRecording];
    }
}

- (void)startTimer{
    [self.timer invalidate];
    self.timer = nil;
    self.recordTime = 0;
    [self.timer fire];
}

- (void)stopTimer{
    [self.timer invalidate];
    self.timer = nil;
}

#pragma mark 准备录制
- (void)prepareForRecord{
    [self.captureSession beginConfiguration];
    
    
    //视频采集质量
    [self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720] ? [self.captureSession setSessionPreset:AVCaptureSessionPreset1280x720] : nil;
    
    //添加input
    [self.captureSession canAddInput:self.mediaDeviceInput] ? [self.captureSession addInput:self.mediaDeviceInput] : nil;
    [self.captureSession canAddInput:self.audioDeviceInput] ? [self.captureSession addInput:self.audioDeviceInput] : nil;
    
    //添加output
    [self.captureSession canAddOutput:self.movieFileOutput] ? [self.captureSession addOutput:self.movieFileOutput] : nil;
    [self.captureSession canAddOutput:self.imageOutput] ? [self.captureSession addOutput:self.imageOutput] : nil;
    
    [self.captureSession commitConfiguration];
    
    // 防抖功能
    if ([self.captureConnection isVideoStabilizationSupported] && self.captureConnection.activeVideoStabilizationMode == AVCaptureVideoStabilizationModeOff){
        self.captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo].videoMirrored = NO;
    
    
    [self.captureSession startRunning];
}

#pragma mark 切换摄像头
- (void)switchCamera{
    [_captureSession beginConfiguration];
    [_captureSession removeInput:_mediaDeviceInput];
    AVCaptureDevice *swithToDevice = [self switchCameraDevice];
    [swithToDevice lockForConfiguration:nil];
    [self setExposureModeWithDevice:swithToDevice];
    self.mediaDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:swithToDevice error:nil];
    [_captureSession addInput:_mediaDeviceInput];
    [_captureSession commitConfiguration];
}

#pragma mark 获取切换时的摄像头
- (AVCaptureDevice *)switchCameraDevice{
    AVCaptureDevice *currentDevice = [self.mediaDeviceInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    BOOL isUnspecifiedOrFront = (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition ==AVCaptureDevicePositionFront );
    AVCaptureDevicePosition swithToPosition = isUnspecifiedOrFront ? AVCaptureDevicePositionBack:AVCaptureDevicePositionFront;
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    __block AVCaptureDevice *swithCameraDevice = nil;
    if (isUnspecifiedOrFront) {
        _captureConnection.videoMirrored = YES;
    }else{
        _captureConnection.videoMirrored = YES;
    }
    [cameras enumerateObjectsUsingBlock:^(AVCaptureDevice *camera, NSUInteger idx, BOOL * _Nonnull stop) {
        if (camera.position == swithToPosition){
            swithCameraDevice = camera;
            *stop = YES;
        };
    }];
    return swithCameraDevice;
}

/**
 *  拍照
 *
 *  @param block
 */
- (void)takePhotoWithImageBlock:(void (^)(UIImage *orgImg))block {
    self.isTakePicture = true;
    AVCaptureConnection *videoConnection = [self findVideoConnection];
     if (!videoConnection) {
         NSLog(@"你的设备没有照相机");
     }
    __weak typeof(self) weakSelf = self;
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *originImage = [[UIImage alloc] initWithData:imageData];
        CGFloat squareLength = weakSelf.preViewLayer.bounds.size.width;
        CGFloat previewLayerH =  weakSelf.preViewLayer.bounds.size.height;
        CGSize size = CGSizeMake(squareLength*2, previewLayerH*2);
        originImage = [originImage resizedImageWithContentMode:UIViewContentModeScaleAspectFill bounds:size interpolationQuality:kCGInterpolationHigh];
        if(block) {
            block(originImage);
        }
    }];
}

/**
   *  查找摄像头连接设备
  *
 *
   */
 - (AVCaptureConnection *)findVideoConnection
 {
       AVCaptureConnection *videoConnection = nil;
       for (AVCaptureConnection *connection in _imageOutput.connections) {
           for (AVCaptureInputPort *port in connection.inputPorts) {
               if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                   videoConnection = connection;
                   break;
               }
           }
           if (videoConnection) {
               break;
           }
       }
       return videoConnection;
 }

#pragma mark 开始录制
- (void)startRecordToFile:(NSURL *)outPutFile{
    
    if (!self.captureConnection) {
        return;
    }
    
    if ([self.movieFileOutput isRecording]) {
        return;
    }
    if ([self.captureConnection isVideoOrientationSupported]){
        self.captureConnection.videoOrientation =[self.preViewLayer connection].videoOrientation;
    }
    if (@available(iOS 11.0, *)) {
        @try{
        NSMutableDictionary* dic = [NSMutableDictionary dictionary];
        dic[(id)AVVideoCodecKey] = AVVideoCodecH264;
        
        [self.movieFileOutput setOutputSettings:dic forConnection:self.captureConnection];
        [self.movieFileOutput outputSettingsForConnection:self.captureConnection];
        }@catch(NSException * e){
            NSLog(@"当前抛出的异常---%@",e);
        }
    }
    
    [_movieFileOutput startRecordingToOutputFileURL:outPutFile recordingDelegate:self];
}

#pragma mark  停止录制
- (void)stopCurrentVideoRecording{
    if (self.movieFileOutput.isRecording) {
        [self stopTimer];
        [_movieFileOutput stopRecording];
        
    }
}

#pragma mark 设置对焦
- (void)setFoucusWithPoint:(CGPoint)point{
    CGPoint cameraPoint= [self.preViewLayer captureDevicePointOfInterestForPoint:point];
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposureMode:AVCaptureExposureModeContinuousAutoExposure atPoint:cameraPoint];
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        //聚焦
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
        //聚焦位置
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        //曝光模式
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
        //曝光点位置
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}
#pragma mark - 改变设备属性方法
- (void)changeDeviceProperty:(void (^)(id obj))propertyChange
{
    AVCaptureDevice *captureDevice = [self.mediaDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        
    }
}

#pragma mark - AVCaptureFileOutputRecordignDelegate method

// 录制开始
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    [self startTimer];
}

//// 录制结束
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    [self stopTimer];
    if (self.delegate && [self.delegate respondsToSelector:@selector(captureOutput:didFinishRecordingToOutputFileAtURL:fromConnections:error:)]) {
        [self.delegate captureOutput:captureOutput didFinishRecordingToOutputFileAtURL:outputFileURL fromConnections:connections error:error];
    }
    [self.captureSession stopRunning];
}

#pragma mark - 压缩视频
- (void)compressVideo:(NSURL *)inputFileURL complete:(void(^)(BOOL success, NSURL* outputUrl))complete{
    NSURL *outPutUrl = self.videoPath;
    [self convertVideoQuailtyWithInputURL:inputFileURL outputURL:outPutUrl completeHandler:^(AVAssetExportSession *exportSession) {
        complete(exportSession.status == AVAssetExportSessionStatusCompleted, outPutUrl);
    }];
}
- (void)convertVideoQuailtyWithInputURL:(NSURL*)inputURL
                              outputURL:(NSURL*)outputURL
                        completeHandler:(void (^)(AVAssetExportSession*))handler{
    
    
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPreset1280x720];
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse= YES;
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        handler(exportSession);
    }];
}

#pragma mark 获取文件大小
+ (CGFloat)getfileSize:(NSString *)filePath{
    NSFileManager *fm = [NSFileManager defaultManager];
    filePath = [filePath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    CGFloat fileSize = 0;
    if ([fm fileExistsAtPath:filePath]) {
        fileSize = [[fm attributesOfItemAtPath:filePath error:nil] fileSize];
        NSLog(@"视频大小 - - - - - %fM,--------- %fKB",fileSize / (1024.0 * 1024.0),fileSize / 1024.0);
    }
    return fileSize/1024/1024;
}

#pragma mark 视频缓存目录
//- (NSURL*)cacheFilePath:(BOOL)input{
//  [ATSessionUtil smallVideoPath];
//    NSString * pathName = self.seessionId ? self.seessionId:@"dynamic";
//    _VIDEO_OUTPUTFILE = [NSURL fileURLWithPath:[[ATSessionUtil smallVideoSessionPath:pathName] stringByAppendingPathComponent:self.videoFileName]];
//    return _VIDEO_OUTPUTFILE;
//
//
////    NSString *cacheDirectory = [self getCacheDirWithCreate:YES];
////    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
////    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
////    [formatter setDateFormat:@"HHmmss"];
////    NSDate *NowDate = [NSDate dateWithTimeIntervalSince1970:now];
////    ;
////    NSString *timeStr = [formatter stringFromDate:NowDate];
////    NSString *put = input ? @"input" : @"output";
////    NSString *path = input ? @"mov" : @"mp4";
////    NSString *fileName = [NSString stringWithFormat:@"video_%@_%@.%@",timeStr,put,path];
////    return [cacheDirectory stringByAppendingFormat:@"/%@", fileName];
//}

+ (NSString *) getCacheDirWithCreate:(BOOL)isCreate {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths objectAtIndex:0];
    dir = [dir stringByAppendingPathComponent:@"Caches"];
    dir = [dir stringByAppendingPathComponent:@"cache"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = YES;
    if (![fm fileExistsAtPath:dir isDirectory:&isDir]) {
        // 不存在
        if (isCreate) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
            return dir;
        }else {
            return @"";
        }
    }else{
        // 存在
        return dir;
    }
}

- (void)dealloc{
    [self.timer invalidate];
    self.timer = nil;
    self.recordTime = 0;
    [self stopCurrentVideoRecording];
    [self.captureSession stopRunning];
    [self.preViewLayer removeFromSuperlayer];
}

@end
