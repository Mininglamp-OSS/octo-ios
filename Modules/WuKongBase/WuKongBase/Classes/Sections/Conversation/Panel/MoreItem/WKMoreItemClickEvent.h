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
 同上, onFailure 在原子性闸门 (count != assetCount) 或空 NSData 兜底命中时触发,
 给调用方一个恢复 pending bar 的机会 —— 这两条 bail-out 都发生在任何 sendMessage:
 之前, 没有 failed bubble 留在 chat, 不传 onFailure 等于丢图。onFailure 由 main
 queue dispatch_async 内同步调用 (与 HUD 同步触发), 用于撤销 _commitPendingWithCaption
 的同步清 bar。
 */
-(void) sendAlbumImageDatas:(NSArray<NSData *> *)imageDatas
                 assetCount:(NSUInteger)assetCount
                    context:(id<WKConversationContext>)context
                  onFailure:(void(^_Nullable)(void))onFailure;

/**
 待发送图片栏「+」按钮触发：再次拉相册（全屏库，无 sheet 预览），按 remaining 限张数，
 不允许选视频（保持 pending 栏纯图语义）；选完通过 appendBlock 回调把已压缩图片回传。
 */
-(void) addMorePendingImagesForContext:(id<WKConversationContext>)context
                             remaining:(NSInteger)remaining
                           appendBlock:(void(^)(NSArray<NSData *> *images))appendBlock;

@end

NS_ASSUME_NONNULL_END
