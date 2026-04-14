//
//  WKHoldToTalkManager.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WKHoldToTalkManager;

@protocol WKHoldToTalkManagerDelegate <NSObject>

/// 转写完成，文字写入输入框
- (void)holdToTalkManager:(WKHoldToTalkManager *)manager didTranscribeText:(NSString *)text;

/// 发送原始语音消息
- (void)holdToTalkManager:(WKHoldToTalkManager *)manager sendVoiceData:(NSData *)data seconds:(NSInteger)seconds waveform:(nullable NSArray<NSNumber *> *)waveform;

/// 发送文字消息
- (void)holdToTalkManager:(WKHoldToTalkManager *)manager sendText:(NSString *)text;

/// 录音开始（通知外层停止其他音频）
- (void)holdToTalkManagerDidStartRecording:(WKHoldToTalkManager *)manager;

/// 录音结束
- (void)holdToTalkManagerDidStopRecording:(WKHoldToTalkManager *)manager;

/// 获取输入框当前文本（用于 context_text）
- (nullable NSString *)holdToTalkManagerCurrentInputText:(WKHoldToTalkManager *)manager;

/// 获取聊天上下文（用于 chat_context）
- (nullable NSString *)holdToTalkManagerChatContext:(WKHoldToTalkManager *)manager;

@end

@interface WKHoldToTalkManager : NSObject

@property (nonatomic, weak) id<WKHoldToTalkManagerDelegate> delegate;

/// 处理长按手势（由 holdToTalkBtn 的手势传入）
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture inWindow:(UIWindow *)window;

/// 取消正在进行的录音
- (void)cancelIfRecording;

@end

NS_ASSUME_NONNULL_END
