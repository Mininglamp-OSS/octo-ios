//
//  WKPhotoBrowser.h
//  WuKongBase
//
//  Created by tt on 2022/3/21.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKPhotoBrowser : NSObject

+ (WKPhotoBrowser *)shared;

-(void) showPreviewWithSender:(UIViewController*)vc  selectImageBlock:(void(^)(NSArray<UIImage *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock;

-(void) showPreviewWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock;

-(void) showPreviewWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock allowSelectVideo:(BOOL)allowSelectVideo;

-(void) showPhotoLibraryWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock allowSelectVideo:(BOOL)allowSelectVideo;

-(void) showPhotoLibraryWithSender:(UIViewController*)vc  selectCompressImageBlock:(void(^)(NSArray<NSData *>* _Nonnull images,NSArray<PHAsset *> * _Nonnull assets, BOOL isOriginal))selectImageBlock maxSelectCount:(NSInteger)maxCount allowSelectVideo:(BOOL)allowSelectVideo;
/**
 拍照
 */
-(void) takePhoto:(UIViewController*)vc doneBlock:(void(^)(UIImage *img,NSURL *url))doneBlock cancelBlock:(void(^)(void))cancelBlock;

/**
 提取文件路径
 */
+ (void) fetchAssetFilePathWithAsset:(PHAsset*)asset completion:(void(^)(NSString* filePath))completion;

/**
 导出兼容的视频
 */
-(void) exportVideo:(NSURL*)videoURL completion:(void(^)(NSString* filePath))completion;
@end

NS_ASSUME_NONNULL_END
