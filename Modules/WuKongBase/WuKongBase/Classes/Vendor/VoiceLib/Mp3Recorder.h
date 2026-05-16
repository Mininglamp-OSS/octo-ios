#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@protocol Mp3RecorderDelegate <NSObject>
- (void)failRecord;
- (void)beginConvert;
- (void)endConvertWithData;
@end
@interface Mp3Recorder : NSObject
@property (nonatomic, weak) id<Mp3RecorderDelegate> delegate;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property(nonatomic)double voiceTime;
- (id)initWithDelegate:(id<Mp3RecorderDelegate>)delegate;
- (void)startRecord;
- (void)stopRecord;
- (void)cancelRecord;

- (NSString *)cafPath;
@end
