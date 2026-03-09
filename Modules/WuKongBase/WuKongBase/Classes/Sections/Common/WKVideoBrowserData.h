//
//  WKVideoBrowserData.h
//  WuKongSmallVideo
//
//  Created by tt on 2020/4/30.
//

#import <Foundation/Foundation.h>
#import <YBImageBrowser/YBImageBrowser.h>
#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN

typedef void(^downloadCallback)(void(^downCompleteBlock)(NSString *videoPath,NSError *error));

typedef void(^downloadProgressBlock)(CGFloat progress);


@interface WKVideoBrowserData : NSObject<YBIBDataProtocol>

@property(nonatomic,copy) NSString *videoPath; // 视频保存到本地的路径


@property(nonatomic,copy) downloadCallback download;
// 封面图
@property(nonatomic,weak) UIImage *coverImage;

@property(nonatomic,copy) downloadProgressBlock progress;



@end

NS_ASSUME_NONNULL_END
