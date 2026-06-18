//
//  WKMoreItemClickEvent.h
//  WuKongBase
//
//  Created by tt on 2020/1/12.
//

#import <Foundation/Foundation.h>
#import "WKPanel.h"
#import "WKConversationContext.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMoreItemClickEvent : NSObject

+ (WKMoreItemClickEvent *)shared;
/**
  图片
 */
-(void) onPhotoItemPressed:(id<WKConversationContext>)context;


/**
 拍照
 */
-(void) onCameraIPressed:(id<WKConversationContext>)context;

/**
 文件
 */
-(void) onFileItemPressed:(id<WKConversationContext>)context;

/**
 待发送图片栏的纯图发送（用于 caption 为空场景，以及语音消息后的图片发送伴随路径）。
 内含 count==assetCount 原子性闸门：选了 N 张就必须发齐 N 张，否则整条可见失败。
 */
-(void) sendAlbumImageDatas:(NSArray<NSData *> *)imageDatas
                 assetCount:(NSUInteger)assetCount
                    context:(id<WKConversationContext>)context;

/**
 待发送图片栏「+」按钮触发：再次拉相册（全屏库，无 sheet 预览），按 remaining 限张数，
 不允许选视频（保持 pending 栏纯图语义）；选完通过 appendBlock 回调把已压缩图片回传。
 */
-(void) addMorePendingImagesForContext:(id<WKConversationContext>)context
                             remaining:(NSInteger)remaining
                           appendBlock:(void(^)(NSArray<NSData *> *images))appendBlock;

@end

NS_ASSUME_NONNULL_END
