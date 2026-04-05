//
//  CWSpeechToTextView.h
//  WuKongBase
//

#import <UIKit/UIKit.h>

@class CWSpeechToTextView;

@protocol CWSpeechToTextViewDelegate <NSObject>

/// 语音识别完成，发送识别的文本
- (void)speechToTextView:(CWSpeechToTextView *)view didRecognizeText:(NSString *)text;

@optional

/// 开始录音时调用（用于停止其他音频播放）
- (void)speechToTextViewDidBeginRecording:(CWSpeechToTextView *)view;

@end

@interface CWSpeechToTextView : UIView

@property (nonatomic, weak) id<CWSpeechToTextViewDelegate> delegate;

@end
