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
// 封面图 (strong - 浏览器在 setYb_cellData: 中读取后才会拷给 imageView, 期间需要保活;
// 历史上是 weak 但当时无消费方, 不构成行为变更)
@property(nonatomic,strong) UIImage *coverImage;

@property(nonatomic,copy) downloadProgressBlock progress;

/// 自定义业务数据 (与 YBIBImageData.extraData 同语义)。
/// 例: 搜索结果浏览器把当前命中项放在 extraData[@"channelHistoryItem"] 里, 供 toolbar
/// 在「定位到聊天位置」时取回上下文使用。
@property(nonatomic,strong,nullable) id extraData;

@end

NS_ASSUME_NONNULL_END
