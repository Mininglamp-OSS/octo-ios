//
//  WKVideoRecordUtil.m
//  WuKongBase
//
//  Created by tt on 2020/11/13.
//

#import "WKVideoRecordUtil.h"
#import "JCVideoRecordView.h"
#import "WKNavigationManager.h"
#import "WKPhotoBrowser.h"
@implementation WKVideoRecordUtil

+(void) videoRecord:(void(^)(NSString *coverPath,NSString *videoPath))callback imgCallback:(void(^)(UIImage*img))imgCallback{
    
    UIViewController *vc = [[WKNavigationManager shared] topViewController];
    
    [[WKPhotoBrowser shared] takePhoto:vc doneBlock:^(UIImage * _Nonnull img, NSURL * _Nonnull videoURL) {
        if(img) {
            if(imgCallback) {
                imgCallback(img);
            }
        }else if(videoURL) {
            if(callback) {
                AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
                if(!asset) {
                    return;
                }
                UIImage *coverImg =  [WKVideoRecordUtil getVideoPreViewImage:asset];
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSData * coverImgData  = UIImageJPEGRepresentation(coverImg, 0.5f);
                NSString *tmpConverPath = [self getTmpCoverImgPath];
                [fileManager createFileAtPath:tmpConverPath contents:coverImgData attributes:nil];
                
                callback(tmpConverPath,videoURL.absoluteString);
                
            }
        }
    } cancelBlock:^{
        
    }];
    
   
//     JCVideoRecordView *recordView = [[JCVideoRecordView alloc]init];
//    
//    if(imgCallback && callback) {
//        recordView.mode = RecordModeAll;
//    }else if(imgCallback) {
//        recordView.mode = RecordModeTakePicture;
//    }else if(callback) {
//        recordView.mode = RecordModeVideo;
//    }
//    recordView.modalPresentationStyle = UIModalPresentationFullScreen;
//      recordView.videoBlock = ^(NSString* coverPath, NSString* videoPath) {
//          [vc dismissViewControllerAnimated:YES completion:nil];
//          if(callback) {
//              callback(coverPath,videoPath);
//          }
//          
//      };
//    recordView.takePictureBlock = ^(UIImage *img) {
//        [vc dismissViewControllerAnimated:YES completion:nil];
//        if(imgCallback) {
//            imgCallback(img);
//        }
//    };
//    [vc presentViewController:recordView animated:YES completion:nil];
}

+(NSString*) getTmpCoverImgPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *tmpPath = NSTemporaryDirectory();
  NSString *videoFileName = [NSString stringWithFormat:@"%@%@",[self uuidString],@".mp4"];
  NSString *videoDir = [tmpPath stringByAppendingPathComponent:@"video_tmp"] ;
    NSError *error;
    [fileManager createDirectoryAtPath:videoDir withIntermediateDirectories:YES attributes:nil error:&error];
    if(error!=nil) {
        NSLog(@"error----%@",error);
    }
    
   return  [videoDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",videoFileName]];
}

/**
 *  生成32位UUID
 */
+ (NSString *)uuidString{
    
    CFUUIDRef uuid_ref = CFUUIDCreate(NULL);
    CFStringRef uuid_string_ref= CFUUIDCreateString(NULL, uuid_ref);
    NSString *uuid = [NSString stringWithString:(__bridge NSString *)uuid_string_ref];
    CFRelease(uuid_ref);
    CFRelease(uuid_string_ref);
    
    //去除UUID ”-“
    NSString *UUID = [[uuid lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    
    NSLog(@"%@", UUID);
    
    return UUID;
}
// 获取视频第一帧
+ (UIImage*) getVideoPreViewImage:(AVURLAsset *)asset
{
    AVAssetImageGenerator *assetGen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    
    assetGen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [assetGen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *videoImage = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    return videoImage;
}

+(void) videoRecord:(void(^)(NSString *coverPath,NSString *videoPath))callback {
    [self videoRecord:callback imgCallback:nil];
}
@end
