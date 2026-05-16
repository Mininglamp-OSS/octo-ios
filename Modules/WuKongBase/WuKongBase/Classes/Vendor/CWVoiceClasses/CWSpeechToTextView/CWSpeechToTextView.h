//
//  CWSpeechToTextView.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

@class CWSpeechToTextView;

@protocol CWSpeechToTextViewDelegate <NSObject>

/// 语音识别完成，直接发送识别的文本（拖到发送按钮时触发）
- (void)speechToTextView:(CWSpeechToTextView *)view didRecognizeText:(NSString *)text;

/// 语音识别完成，将文本输入到输入框（松手时触发）
- (void)speechToTextView:(CWSpeechToTextView *)view didRecognizeTextForInput:(NSString *)text;

@optional

/// 开始录音时调用（用于停止其他音频播放）
- (void)speechToTextViewDidBeginRecording:(CWSpeechToTextView *)view;

@end

@interface CWSpeechToTextView : UIView

@property (nonatomic, weak) id<CWSpeechToTextViewDelegate> delegate;

@end
