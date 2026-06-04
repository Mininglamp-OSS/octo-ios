// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRichTextCaptionViewController.h
//  WuKongBase
//
//  图文混排 RichText=14 Phase 2（方案1）：相册选图后、发送前的 caption 确认页
//  （微信/TG 标准款）。展示已选图缩略图 + 一个文字框，用户可补一段描述，点「发送」把
//  图 + caption 打成单条 RichText(=14)。本页只负责「采集 caption + 确认/取消」，真正的
//  上传/打包/发送复用 #19 的 sendRichTextMixedImages: 能力，由调用方在 onSend 回调里发起。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 相册选图 → 发送前 caption 确认页。

 用法：调用方用已压缩的图片（与相册回调一致的 NSData 顺序）构造，present 出来；
 用户点「发送」回调 onSend(caption)（caption 已 trim，可能为空字符串=不加描述），点
 「取消」或下滑关闭回调 onCancel。两个回调都在主线程、且页面 dismiss 之后触发，互斥只走一个。
 */
@interface WKRichTextCaptionViewController : UIViewController

/**
 @param imageDatas 已压缩图片二进制（顺序即展示/发送顺序，与相册回调一致）
 @param initialCaption 预填到文字框的初始文本（承接输入框已有草稿；可为 nil）
 */
- (instancetype)initWithImageDatas:(NSArray<NSData *> *)imageDatas
                    initialCaption:(nullable NSString *)initialCaption;

/// 点「发送」回调：caption 已做首尾空白裁剪，调用方据此决定打 RichText(=14) 还是逐图发。
@property(nonatomic, copy, nullable) void (^onSend)(NSString *caption);

/// 点「取消」/下滑关闭回调：调用方据此把预填草稿恢复回输入框（文字绝不静默丢）。
@property(nonatomic, copy, nullable) void (^onCancel)(void);

@end

NS_ASSUME_NONNULL_END
