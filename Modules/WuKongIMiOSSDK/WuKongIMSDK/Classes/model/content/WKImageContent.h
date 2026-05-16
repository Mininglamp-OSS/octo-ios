//
//  WKImageMessageContent.h
//  WuKongIMSDK
//
//  Created by tt on 2020/1/13.
// 图片消息content

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "WKMediaMessageContent.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKImageContent : WKMediaMessageContent


@property(nonatomic,assign) CGFloat width; // 图片宽度
 
@property(nonatomic,assign) CGFloat height; // 图片高度

/*!
 初始化图片消息

 @param image   原始图片
 @return        图片消息对象
 */
+ (instancetype)initWithImage:(UIImage *)image;



/// 通过data初始化
/// @param data 图片数据
/// @param width 图片宽度
/// @param height 图片高度
+ (instancetype)initWithData:(NSData *)data width:(CGFloat)width height:(CGFloat)height;


/// 初始化
/// @param data 原图data
/// @param width 原图宽度
/// @param height 原图高度
/// @param thumbData 缩略图data （如果传了缩略图的data数据，sdk将不再生成缩略图数据）
+ (instancetype)initWithData:(NSData *)data width:(CGFloat)width height:(CGFloat)height thumbData:( nullable NSData*)thumbData;


/*!
 是否发送原图
 
 @discussion 在发送图片的时候，是否发送原图，默认值为NO。
 */
@property (nonatomic, getter=isFull) BOOL full;

/*!
 图片消息的缩略图
 */
@property (nonatomic, strong,nullable) UIImage *thumbnailImage;

@property (nonatomic, strong,readonly) NSData *thumbnailData;

/*!
 图片消息的原始图片信息
 */
@property (nonatomic, strong,readonly) UIImage *originalImage;

/*!
 图片消息的原始图片信息
 */
@property (nonatomic, strong, readonly) NSData *originalImageData;

-(void) releaseData;

@end

NS_ASSUME_NONNULL_END
