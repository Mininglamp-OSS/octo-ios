// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKRichTextCaptionViewController.h
//  WuKongBase
//
//  图文混排 RichText=14 Phase 2（方案1）：相册选图后、发送前的 caption 确认页
//  （微信/TG 标准款）。展示已选图缩略图 + 一个文字框，用户可补一段描述，点「发送」把
//  图 + caption 打成单条 RichText(=14)。本页只负责「采集 caption + 确认/取消 + @人 +
//  删图」，真正的上传/打包/发送复用 #19 的 sendRichTextMixedImages: 能力，由调用方在
//  onSend 回调里发起。
//
//  Phase 3 增量（bug fix 一批）：
//  - 删图：每张缩略图右上 × 按钮；删到 0 张通过 finalImages.count == 0 回传调用方降级。
//  - @ 人/AI：输入框 '@' 触发 + caption bar 的 "@" 按钮兜底，弹 WKRichTextMentionPickerVC
//    选成员；选中插入 "@<name> " 并累积 WKInputMentionItem 入 mentions 列表，
//    调用方在 onSend 里把 mentions 映射成 WKMentionedInfo + entities 挂到 RichText 上。
//

#import <UIKit/UIKit.h>

@class WKChannel;
@class WKInputMentionItem;

NS_ASSUME_NONNULL_BEGIN

@interface WKRichTextCaptionViewController : UIViewController

/// @param imageDatas    已压缩图片二进制（顺序即展示/发送顺序，与相册回调一致）
/// @param initialCaption 预填到文字框的初始文本（承接输入框已有草稿；可为 nil）
/// @param channel       当前会话 channel；用于 @ 人选择器拉成员列表。DM 时只会出 @所有AI。
- (instancetype)initWithImageDatas:(NSArray<NSData *> *)imageDatas
                    initialCaption:(nullable NSString *)initialCaption
                           channel:(nullable WKChannel *)channel;

/// 点「发送」回调；caption 已 trim。
/// finalImages = 当前用户删图后剩余的图片二进制（顺序保持）；finalImages.count == 0 时调用方
/// 应当走「发纯文本」降级（caption 为空则啥都不发）。mentions = 用户在 caption 里 @ 选中的
/// 成员（含 sentinel: uid="all" / "__ais__"）；调用方负责映射成 mentionedInfo + entities。
@property(nonatomic, copy, nullable) void (^onSend)(NSArray<NSData *> *finalImages,
                                                     NSString *caption,
                                                     NSArray<WKInputMentionItem *> *mentions);

/// 点「取消」/下滑关闭回调：调用方据此把预填草稿恢复回输入框（文字绝不静默丢）。
@property(nonatomic, copy, nullable) void (^onCancel)(void);

@end

NS_ASSUME_NONNULL_END
