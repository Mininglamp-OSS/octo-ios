// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConversationPendingImageBar.h
//  WuKongBase
//
//  聊天输入框上方的「待发送图片」横向缩略图带（替代旧的全屏 caption 编辑页）。
//  - 每张缩略图右上有 × 删除；末尾的 + cell 触发 onAddTapped 加更多图（9 张总上限）。
//  - 点击缩略图触发 onPreviewAtIndex 由调用方拉起 YBImageBrowser 之类的全屏浏览。
//  - 内容增减后回调 onContentSizeChanged 让 input panel 重新算高度 + 跟随键盘动画。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationPendingImageBar : UIView

/// 当前已选图片二进制（顺序保持，与发送顺序一致）。
@property(nonatomic, strong, readonly) NSArray<NSData *> *imageDatas;

/// 等价于 imageDatas.count；快路径。
@property(nonatomic, assign, readonly) NSUInteger imageCount;

/// 用户点 + cell 时回调；调用方负责再次拉起相册并通过 appendImageDatas: 写回。
@property(nonatomic, copy, nullable) void (^onAddTapped)(void);

/// 用户点某张缩略图时回调；index 与 imageDatas 对齐。
@property(nonatomic, copy, nullable) void (^onPreviewAtIndex)(NSInteger index);

/// 内容（图片数 / 是否非空）变化后调用，调用方据此 re-layout 输入面板高度。
@property(nonatomic, copy, nullable) void (^onContentSizeChanged)(void);

/// 替换全部图片。线程安全：内部主线程 hop。
- (void)setImageDatas:(NSArray<NSData *> *)datas;

/// 追加；超过 9 张硬上限的部分被丢弃并 HUD 提示。
- (void)appendImageDatas:(NSArray<NSData *> *)datas;

/// 删除指定下标；越界被忽略。
- (void)removeImageDataAtIndex:(NSInteger)index;

/// 清空。
- (void)clear;

/// 推荐高度（视图 height = 这个，imageCount==0 时调用方应当把 lim_height 设 0 隐藏）。
+ (CGFloat)preferredHeight;

/// 触发主题色 / 暗黑模式刷新（input panel layout 时配合 [WKApp shared].config.style 调用）。
- (void)refreshTheme;

@end

NS_ASSUME_NONNULL_END
