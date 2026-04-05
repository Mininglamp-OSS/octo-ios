//
//  WKVoiceInputViewDelegate.h
//  WuKongBase
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol WKVoiceInputViewDelegate <NSObject>

@optional

/// 转写完成，文本写入输入框
/// @param text 转写后的文本
/// @param shouldReplace YES=用 inputSetText: 替换输入框全部文本，NO=追加
- (void)voiceInputDidTranscribe:(NSString *)text shouldReplace:(BOOL)shouldReplace;

/// 请求插入文本到输入框
- (void)voiceInputInsertText:(NSString *)text;

/// 请求删除输入框光标前一个字符
- (void)voiceInputDeleteBackward;

/// 获取输入框当前文本（用于 context_text）
- (nullable NSString *)voiceInputCurrentText;

/// 获取输入框当前选区
- (NSRange)voiceInputSelectedRange;

/// 通知外层：录音开始了
- (void)voiceInputRecordingDidStart;

/// 通知外层：录音结束了
- (void)voiceInputRecordingDidStop;

@end

NS_ASSUME_NONNULL_END
