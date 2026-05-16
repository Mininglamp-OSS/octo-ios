//
//  WKMediaManager.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
//

#import "WKMediaManager.h"
#import "WKMediaProto.h"
#import "WKMultiMediaMessageContent.h"
#import "WKChatManager.h"
#import "WKSDK.h"
#import "WKMessageDB.h"
#import "WKTaskManager.h"
#import "WKMessageFileUploadTask.h"
#import "WKMediaMessageContent.h"
#import "WKMultiMediaMessageContent.h"
#import <AVFoundation/AVFoundation.h>
#import "WKMessageFileDownloadTask.h"
#import "WKVoiceContent.h"
#import "VoiceConverter.h"
#import "WKFileUtil.h"
#import "WKChatManagerInner.h"
@interface WKMediaManager ()<WKChatManagerDelegate,WKTaskManagerDelegate,AVAudioPlayerDelegate>
/**
 *  用来存储所有添加j过的delegate
 *  NSHashTable 与 NSMutableSet相似，但NSHashTable可以持有元素的弱引用，而且在对象被销毁后能正确地将其移除。
 */
@property (strong, nonatomic) NSHashTable  *delegates;
/**
 *  delegateLock 用于给delegate的操作加锁，防止多线程同时调用
 */
@property (strong, nonatomic) NSLock  *delegateLock;

// ------ 音频播放 ------
@property(nonatomic,strong) AVAudioPlayer *avAudioPlayer;   //播放器player
@property(nonatomic,copy) WKAudioPlayerDidFinishBlock  playerDidFinishBlock;
@property(nonatomic,copy) WKAudioPlayerDidProgressBlock playerDidProgressBlock;
@property(nonatomic,strong) NSTimer *playProgressTimer;

@end


@implementation WKMediaManager


static WKMediaManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKMediaManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.taskManager = [WKTaskManager new];
        self.taskManager.delegate = self;
    }
    return self;
}


#pragma mark - 上传相关

-(void) upload:(WKMessage*) message {
    if(![message.content conformsToProtocol:@protocol(WKMediaProto)] && ![message.content isKindOfClass:[WKMultiMediaMessageContent class]] ) {
        NSLog(@"消息没有实现WKMediaProto协议，不能上传多媒体文件！");
        return;
    }
    if(!self.uploadTaskProvider) {
        NSLog(@"请先设置上传任务提供者[uploadTaskProvider]！");
        return;
    }
    if(message.clientSeq == 0) {
         NSLog(@"消息没有clientSeq，请先保存消息，再调用上传！");
        return;
    }
    
    NSArray<id<WKMediaProto>> *mediaProtos = [self getMessageMedias:message];
    if(mediaProtos) {
        // 填充消息
        for (id<WKMediaProto> mediaProto in mediaProtos) {
            mediaProto.message = message;
        }
        
       // 将数据保存本地文件
       [self saveMediaDataToLocalPath:mediaProtos];
        // 添加上传任务
        id<WKTaskProto> uploadTask = self.uploadTaskProvider(message);
        [self.taskManager add:uploadTask];
       
        
    }else {
        NSLog(@"warn: 消息【%d】没有媒体文件！",message.clientSeq);
    }
}

-(void) saveMediaDataToLocalPath:(NSArray<id<WKMediaProto>>*)medias {
    for (id<WKMediaProto> mediaProto in medias) {
        // 保存数据到本地路径
        [mediaProto writeDataToLocalPath];
    }
}

#pragma mark - 下载相关

- (WKMessageFileDownloadTask*)download:(WKMessage *)message {
   return [self download:message callback:nil];
}

-(WKMessageFileDownloadTask*) download:(WKMessage*)message callback:(void(^)(WKMediaDownloadState state,CGFloat progress,NSError *error))callback {
    
    id<WKTaskProto> downloadTask = self.downloadTaskProvider(message);
    if(!downloadTask) {
        NSLog(@"没有获取到下载任务，请设置下载任务提供者[[WKSDK shared].mediaManager setDownloadTaskProvider!");
        return nil;
    }
    if(![downloadTask isKindOfClass:[WKMessageFileDownloadTask class]]) {
        NSLog(@"任务需要继承WKMessageFileDownloadTask!");
        return nil;
    }
    WKMessageFileDownloadTask *messageDownloadTask = (WKMessageFileDownloadTask*)downloadTask;
     __weak typeof(messageDownloadTask) weakTask = messageDownloadTask;
    if(callback) {
        [downloadTask addListener:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if(weakTask.status == WKTaskStatusProgressing) {
                    callback(WKMediaDownloadStateProcessing,weakTask.progress,nil);
                }else if(weakTask.status == WKTaskStatusError){
                     callback(WKMediaDownloadStateFail,0,weakTask.error);
                }else {
                     callback(WKMediaDownloadStateSuccess,0,weakTask.error);
                }
            });
            
        } target:self];
    }
    // 将任务添加到队列里
    [self.taskManager add:downloadTask];
    return downloadTask;
}

#pragma mark - WKTaskManagerDelegate

-(void) taskProgress:(id<WKTaskProto>)task {
    if([task isKindOfClass:[WKMessageFileUploadTask class]]) {
        NSLog(@"上传进度->%0.2f",((WKMessageFileUploadTask*)task).progress);
    }else  if([task isKindOfClass:[WKMessageFileDownloadTask class]]) {
        NSLog(@"下载进度->%0.2f",((WKMessageFileDownloadTask*)task).progress);
    }
        
}

- (void)taskComplete:(id<WKTaskProto>)task {
    if(![self isMessageFileUploadTask:task]) {
        return;
    }
    WKMessageFileUploadTask *messageFileUploadTask = (WKMessageFileUploadTask*)task;
    WKMessage *message = messageFileUploadTask.message;
    if(task.status == WKTaskStatusSuccess) {
        // 更新消息状态为待发送
        message.status = WK_MESSAGE_WAITSEND;
        NSData *contentData =[message.content encode];
        [[WKMessageDB shared] updateMessageContent:contentData status:message.status extra:message.extra clientSeq:message.clientSeq];
        // 发送消息
        [[WKSDK shared].chatManager sendMessage:message];
    } else {
        message.status = WK_MESSAGE_FAIL;
        [[WKMessageDB shared] updateMessageStatus:message.status withClientSeq:message.clientSeq];
        // 通知上层消息更新
        [[WKSDK shared].chatManager callMessageUpdateDelegate:message];
    }
}

-(BOOL) isMessageFileUploadTask:(id<WKTaskProto>)task {
    if(!task || ![task isKindOfClass:[WKMessageFileUploadTask class]]) { // 非消息类文件上传不处理
        return false;
    }
    WKMessageFileUploadTask *messageFileUploadTask = (WKMessageFileUploadTask*)task;
    WKMessage *message = messageFileUploadTask.message;
    if(!message) {
        return false;
    }
    if(![message.content isKindOfClass:[WKMediaMessageContent class]] && ![ message.content isKindOfClass:[WKMultiMediaMessageContent class]]) {
        NSLog(@"不是多媒体content！请继承WKMediaMessageContent 或者 WKMultiMediaMessageContent");
        return false;
    }
    return true;
}


-(NSArray<id<WKMediaProto>>*) getMessageMedias:(WKMessage*)message {
     if([message.content isKindOfClass:[WKMultiMediaMessageContent class]]) {
         return ((WKMultiMediaMessageContent*)message.content).medias;
     }
    if([message.content conformsToProtocol:@protocol(WKMediaProto)] ) {
        return @[(id<WKMediaProto>)message.content];
    }
    return nil;
}

#pragma mark - 音频播放

-(void) voiceMessageThumbToSource:(WKMessage*)message {
    if(![message.content isKindOfClass:[WKVoiceContent class]]) {
        NSLog(@"不是音频消息不能转码！");
        return;
    }
    WKVoiceContent *voiceContent = (WKVoiceContent*)message.content;
    if(![[NSFileManager defaultManager] fileExistsAtPath:voiceContent.thumbPath]) {
        NSLog(@"音频不存在副本！不能转码！");
        return;
    }
    [VoiceConverter DecodeAmrToWav:voiceContent.thumbPath wavSavePath:voiceContent.localPath sampleRateType:Sample_Rate_8000];
}

- (BOOL)isAudioPlaying {
    return [_avAudioPlayer isPlaying];
}

-(void) playAudio:(NSString *)filePath playerDidFinish:(WKAudioPlayerDidFinishBlock)finishBlock progress:(WKAudioPlayerDidProgressBlock)progressBlock{
    //初始化音频类 并且添加播放文件
    _playerDidFinishBlock=finishBlock;
    _playerDidProgressBlock = progressBlock;
    
    //默认情况下扬声器播放
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    NSError *error;
    _avAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath] error:&error];
    if(error) {
        NSLog(@"音频文件错误！->%@",error);
        return;
    }
    _avAudioPlayer.meteringEnabled = YES;
    
    //设置代理
    _avAudioPlayer.delegate = self;
    
    [self handleNotification:YES];
    
    if(self.playProgressTimer) {
        [self.playProgressTimer invalidate];
        self.playProgressTimer = nil;
    }
    self.playProgressTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(updatePlayProgress) userInfo:nil repeats:YES];
    
    [[NSRunLoop mainRunLoop] addTimer:self.playProgressTimer forMode:NSRunLoopCommonModes];

    
    //预播放
    [_avAudioPlayer prepareToPlay];
    //播放
    [_avAudioPlayer play];
}

-(void) updatePlayProgress {
    
    if(self.playerDidProgressBlock) {
        self.playerDidProgressBlock(self.avAudioPlayer);
    }
}

- (void)stopAudioPlay {
    if(self.playProgressTimer) {
        [self.playProgressTimer invalidate];
        self.playProgressTimer = nil;
    }
    _avAudioPlayer.currentTime = 0;  //当前播放时间设置为0
    [_avAudioPlayer stop];
}

-(void) pauseAudioPlay {
    [_avAudioPlayer pause];
}

-(void) continuePlay {
    [_avAudioPlayer play];
}

- (void) handleNotification:(BOOL)state {
    [[UIDevice currentDevice] setProximityMonitoringEnabled:state]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应
    
    if(state)//添加监听
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(sensorStateChange:) name:@"UIDeviceProximityStateDidChangeNotification"
                                                   object:nil];
    else//移除监听
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
}
//处理监听触发事件
-(void)sensorStateChange:(NSNotificationCenter *)notification {
    //如果此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出，并将屏幕变暗（省电啊）
    if ([[UIDevice currentDevice] proximityState] == YES)
    {
        NSLog(@"Device is close to user");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    }
    else
    {
        NSLog(@"Device is not close to user");
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    if(self.playProgressTimer) {
        [self.playProgressTimer invalidate];
        self.playProgressTimer = nil;
    }
    [self handleNotification:NO];
    if(_playerDidFinishBlock){
        _playerDidFinishBlock(player,flag);
    }
    
}

#pragma mark - 声明委托

- (NSLock *)delegateLock {
    if (_delegateLock == nil) {
        _delegateLock = [[NSLock alloc] init];
    }
    return _delegateLock;
}

-(void) addDelegate:(id<WKMediaManagerDelegate>) delegate{
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates addObject:delegate];
    [self.delegateLock unlock];
}
- (void)removeDelegate:(id<WKMediaManagerDelegate>) delegate {
    [self.delegateLock lock];//防止多线程同时调用
    [self.delegates removeObject:delegate];
    [self.delegateLock unlock];
}

-(long long) messageCacheSize {
    NSString *folderPath = [WKSDK shared].options.messageFileRootDir;
    NSFileManager* manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:folderPath]) return 0;
    
    NSEnumerator *childFilesEnumerator = [[manager subpathsAtPath:folderPath] objectEnumerator];
    
    NSString* fileName;
    
    long long folderSize = 0;
    
    while ((fileName = [childFilesEnumerator nextObject]) != nil){
        
        NSString* fileAbsolutePath = [folderPath stringByAppendingPathComponent:fileName];
        
        folderSize += [self fileSizeAtPath:fileAbsolutePath];
        
    }
    return folderSize;
}

-(void) cleanMessageCache {
    NSString *folderPath = [WKSDK shared].options.messageFileRootDir;
    NSFileManager* manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:folderPath]) return;
    
    [WKFileUtil removeFileOfPath:folderPath];
}

- (long long) fileSizeAtPath:(NSString*)filePath{

    NSFileManager* manager = [NSFileManager defaultManager];
    
    if ([manager fileExistsAtPath:filePath]){
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

@end
