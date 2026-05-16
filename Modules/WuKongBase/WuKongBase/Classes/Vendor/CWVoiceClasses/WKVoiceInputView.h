//
//  WKVoiceInputView.h
//  WuKongBase
//

#import <UIKit/UIKit.h>
#import "WKVoiceInputViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const WKVoiceInputCancelRecordingNotification;

typedef NS_ENUM(NSInteger, WKVoiceInputState) {
    WKVoiceInputStateIdle,
    WKVoiceInputStateRecording,
    WKVoiceInputStateCancelling,
    WKVoiceInputStateTranscribing,
};

@interface WKVoiceInputView : UIView

@property (nonatomic, weak) id<WKVoiceInputViewDelegate> delegate;
@property (nonatomic, assign, readonly) WKVoiceInputState state;
@property (nonatomic, assign) NSInteger maxDuration;  // 默认 60

/// 取消当前录音（页面消失、切换 Tab 时调用）
- (void)cancelIfRecording;

@end

NS_ASSUME_NONNULL_END
