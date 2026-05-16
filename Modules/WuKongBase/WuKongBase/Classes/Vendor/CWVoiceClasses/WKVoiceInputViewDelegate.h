// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKVoiceInputViewDelegate.h
//  WuKongBase
//

#import <Foundation/Foundation.h>
#import <WuKongIMSDK/WuKongIMSDK.h>

@class WKInputMentionItem;

NS_ASSUME_NONNULL_BEGIN

@protocol WKVoiceInputViewDelegate <NSObject>

@optional

/// 转写完成，文本写入输入框
/// @param text 转写后的文本
/// @param shouldReplace YES=用 inputSetText: 替换输入框全部文本，NO=追加
- (void)voiceInputDidTranscribe:(NSString *)text shouldReplace:(BOOL)shouldReplace;

/// 转写完成（带 @mention 解析），文本写入输入框
/// @param text 转写后文本（@标记已格式化）
/// @param mentions 解析出的 mention 列表
/// @param shouldReplace YES=替换输入框全部文本
- (void)voiceInputDidTranscribe:(NSString *)text
                       mentions:(NSArray<WKInputMentionItem *> *)mentions
                  shouldReplace:(BOOL)shouldReplace;

/// 获取群成员列表（用于 @mention 匹配）
- (NSArray<WKChannelMember *> *)voiceInputChannelMembers;

/// 获取当前频道
- (nullable WKChannel *)voiceInputChannel;

/// 请求插入文本到输入框
- (void)voiceInputInsertText:(NSString *)text;

/// 请求删除输入框光标前一个字符
- (void)voiceInputDeleteBackward;

/// 获取输入框当前文本（用于 context_text）
- (nullable NSString *)voiceInputCurrentText;

/// 获取聊天上下文（用于 chat_context，最近几条消息带用户名）
- (nullable NSString *)voiceInputChatContext;

/// 获取输入框当前选区
- (NSRange)voiceInputSelectedRange;

/// 通知外层：录音开始了
- (void)voiceInputRecordingDidStart;

/// 通知外层：录音结束了
- (void)voiceInputRecordingDidStop;

/// 请求输入框显示光标
- (void)voiceInputRequestCursor;

@end

NS_ASSUME_NONNULL_END
