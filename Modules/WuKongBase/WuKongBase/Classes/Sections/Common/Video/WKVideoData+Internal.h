//
//  YBIBVideoData+Internal.h
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2019/7/11.
//  Copyright © 2019 杨波. All rights reserved.
//

#import "WKVideoData.h"

NS_ASSUME_NONNULL_BEGIN

@class WKVideoData;

@protocol WKVideoDataDelegate <NSObject>
@required

- (void)yb_startLoadingAVAssetFromPHAssetForData:(WKVideoData *)data;

- (void)yb_finishLoadingAVAssetFromPHAssetForData:(WKVideoData *)data;

- (void)yb_startLoadingFirstFrameForData:(WKVideoData *)data;

- (void)yb_finishLoadingFirstFrameForData:(WKVideoData *)data;

- (void)yb_videoData:(WKVideoData *)data downloadingWithProgress:(CGFloat)progress;

- (void)yb_finishDownloadingForData:(WKVideoData *)data;

- (void)yb_videoData:(WKVideoData *)data readyForThumbImage:(UIImage *)image;

- (void)yb_videoData:(WKVideoData *)data readyForAVAsset:(AVAsset *)asset;

- (void)yb_videoIsInvalidForData:(WKVideoData *)data;

@end

@interface WKVideoData ()

@property (nonatomic, assign, getter=isLoadingAVAssetFromPHAsset) BOOL loadingAVAssetFromPHAsset;

@property (nonatomic, assign, getter=isLoadingFirstFrame) BOOL loadingFirstFrame;

@property (nonatomic, assign, getter=isDownloading) BOOL downloading;

@property (nonatomic, weak) id<WKVideoDataDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
