//
//  WKMediaManager.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
//

#import <Foundation/Foundation.h>
#import "WKMediaProto.h"
#import "WKMessage.h"
#import "WKTaskProto.h"
#import "WKTaskManager.h"
#import <CoreGraphics/CGBase.h>
#import <AVFoundation/AVFoundation.h>
#import "WKMessageFileDownloadTask.h"
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKMediaUploadStateProcessing = 0,
    WKMediaUploadStateSuccess = 1,
    WKMediaUploadStateFail = 2,
} WKMediaUploadState;

typedef enum : NSUInteger {
    WKMediaDownloadStateProcessing = 0,
    WKMediaDownloadStateSuccess = 1,
    WKMediaDownloadStateFail = 2,
} WKMediaDownloadState;

@interface WKFileInfo : NSObject

@property(nonatomic,copy) NSString *fid; // 文件唯一id
@property(nonatomic,copy) NSString *name; // 文件名
@property(nonatomic,assign) long size;  // 文件大小（单位byte）
@property(nonatomic,copy) NSString *url; // 文件路径

@end

/**
 多媒体委托
 */
@protocol WKMediaManagerDelegate <NSObject>


/**
 媒体文件数据更新

 @param media 媒体文件
 */
-(void) mediaManageUpdate:(id<WKMediaProto>)media;


@end


/**
 多媒体上传任务提供者
 */
typedef id<WKTaskProto>_Nonnull(^WKMediaUploadTaskProvider)(WKMessage* message);

/**
 多媒体下载任务提供者
 */
typedef id<WKTaskProto>_Nonnull(^WKMediaDownloadTaskProvider)(WKMessage* message);

// 音频播放完成block
typedef void(^WKAudioPlayerDidFinishBlock)(AVAudioPlayer *player,BOOL successFlag);

// 音频播放进度
typedef void (^WKAudioPlayerDidProgressBlock)(AVAudioPlayer *player);

@interface WKMediaManager : NSObject

+ (WKMediaManager *)shared;

@property(nonatomic,strong) WKTaskManager *taskManager;
/**
 添加媒体委托
 
 @param delegate <#delegate description#>
 */
-(void) addDelegate:(id<WKMediaManagerDelegate>) delegate;


/**
 移除媒体委托
 
 @param delegate <#delegate description#>
 */
-(void)removeDelegate:(id<WKMediaManagerDelegate>) delegate;



/**
 下载任务提供者
 */
@property(nonatomic,copy) WKMediaDownloadTaskProvider downloadTaskProvider;
/**
上传任务提供者
 */
@property(nonatomic,copy) WKMediaUploadTaskProvider uploadTaskProvider;

/**
 上传消息里的多媒体

 @param message 消息
 */
-(void) upload:(WKMessage*) message;


/**
 下载消息的多媒体文件

 @param message <#message description#>
 */
-(WKMessageFileDownloadTask*) download:(WKMessage*)message;


/**
 下载消息的多媒体文件

 @param message 消息对象
 @param callback 下载回调
 */
-(WKMessageFileDownloadTask*) download:(WKMessage*)message callback:(void(^ __nullable)(WKMediaDownloadState state,CGFloat progress,NSError * __nullable error))callback;

///**
// 获取上传进度
//
// @param message 消息
// @return <#return value description#>
// */
//-(CGFloat) getUploadProgress:(WKMessage*)message;
//
//
///**
// 获取下载进度
//
// @param message 消息
// @return <#return value description#>
// */
//-(CGFloat) getDowloadProgress:(WKMessage*)message;



/**
 将音频消息的副本转换为源文件

 @param message <#message description#>
 */
-(void) voiceMessageThumbToSource:(WKMessage*)message;

/**
 *  是否正在播放音频
 *
 */
- (BOOL)isAudioPlaying;

/**
 *  播放音频文件
 *
 *  @param filePath 文件路径
 */
-(void) playAudio:(NSString *)filePath playerDidFinish:(WKAudioPlayerDidFinishBlock)finishBlock progress:(WKAudioPlayerDidProgressBlock)progressBlock;

/**
 *  停止播放音频
 */
- (void)stopAudioPlay;

/**
 暂停播放
 */
-(void) pauseAudioPlay;

/**
  继续播放
 */
-(void) continuePlay;

// 获取所有消息缓存大小
-(long long) messageCacheSize;

-(void) cleanMessageCache;

@end

NS_ASSUME_NONNULL_END
