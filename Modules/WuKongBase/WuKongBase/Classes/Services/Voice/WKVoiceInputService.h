// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKVoiceInputService.h
//  WuKongBase
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKVoiceInputConfig : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger maxDuration;
@end

@interface WKVoiceInputResult : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *model;
@end

@interface WKVoiceInputService : NSObject

+ (instancetype)shared;

/// 已缓存的配置（可能为 nil，需先调用 prefetchConfig 或 fetchConfigWithCompletion:）
@property (nonatomic, strong, readonly, nullable) WKVoiceInputConfig *cachedConfig;

/// 获取语音输入配置（带缓存，5 分钟 TTL）
/// 回调保证在主线程执行
/// @param completion 完成回调，可为 nil（prefetchConfig 场景）
- (void)fetchConfigWithCompletion:(nullable void(^)(WKVoiceInputConfig * _Nullable config,
                                                     NSError * _Nullable error))completion;

/// 预取配置（进入会话页时调用，无需等待结果）
- (void)prefetchConfig;

/// 清除配置缓存
- (void)clearConfigCache;

/// 预取语音上下文（录音开始时调用，异步获取不阻塞）
- (void)prefetchVoiceContext;

/// 获取已缓存的语音上下文（录音结束时调用，如果预取完成则直接返回）
/// @param completion 回调，context 为 nil 表示无上下文或未就绪
- (void)getVoiceContextWithCompletion:(void(^)(NSString * _Nullable context))completion;

/// 清除语音上下文缓存（切换 Space 时调用）
- (void)clearVoiceContextCache;

/// 语音转写（m4a/AAC 格式）
/// @param audioData        音频数据（m4a/AAC 格式）
/// @param contextText      输入框已有文本（可选）
/// @param chatContext      最近聊天记录（可选）
/// @param personalContext  个人纠错上下文（可选）
/// @param memberContext    聊天成员名（可选）
- (void)transcribeAudio:(NSData *)audioData
            contextText:(nullable NSString *)contextText
            chatContext:(nullable NSString *)chatContext
        personalContext:(nullable NSString *)personalContext
          memberContext:(nullable NSString *)memberContext
             completion:(void(^)(WKVoiceInputResult * _Nullable result,
                                 NSError * _Nullable error))completion;

/// 语音转写（WAV/PCM 格式）
- (void)transcribeWavAudio:(NSData *)audioData
               contextText:(nullable NSString *)contextText
               chatContext:(nullable NSString *)chatContext
           personalContext:(nullable NSString *)personalContext
             memberContext:(nullable NSString *)memberContext
                completion:(void(^)(WKVoiceInputResult * _Nullable result,
                                    NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
