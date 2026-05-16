//
//  JCVideoRecordView.h
//  Pods
//
//  Created by zhengjiacheng on 2017/8/31.
//
//

typedef enum : NSUInteger {
    RecordModeAll,
    RecordModeVideo,
    RecordModeTakePicture,
} RecordMode;

#import <Foundation/Foundation.h>
#import "JCVideoRecordManager.h"
//typedef void(^JCVideoRecordViewDismissBlock)(void);
//typedef void(^JCVideoRecordViewCompletionBlock)(NSURL *fileUrl);
typedef void(^smallVideoBlock)(NSString *coverImagePath,NSString *videoPath);
typedef void(^takePictureBlock)(UIImage *img);

@interface JCVideoRecordView : UIViewController

@property(nonatomic,copy)smallVideoBlock videoBlock;
@property(nonatomic,copy)takePictureBlock takePictureBlock;
@property(nonatomic,strong) NSURL *VIDEO_OUTPUTFILE;

@property(nonatomic,assign) RecordMode mode; // 录制模式


//@property (nonatomic, copy) JCVideoRecordViewDismissBlock cancelBlock;
//@property (nonatomic, copy) JCVideoRecordViewCompletionBlock completionBlock;
//- (void)present;
// 获取视频第一帧
- (UIImage*) getVideoPreViewImage:(NSURL *)path;
@end
