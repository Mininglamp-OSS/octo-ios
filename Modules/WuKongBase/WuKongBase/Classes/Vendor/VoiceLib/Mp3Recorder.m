#import "Mp3Recorder.h"
@interface Mp3Recorder()<AVAudioRecorderDelegate>
@property (nonatomic, strong) AVAudioSession *session;
@property (nonatomic, strong) NSString *path;
@end
@implementation Mp3Recorder
#pragma mark - Init Methods
- (id)initWithDelegate:(id<Mp3RecorderDelegate>)delegate
{
    if (self = [super init]) {
        _delegate = delegate;
        _path = [self mp3Path];
    }
    return self;
}
- (void)setRecorder
{
    _recorder = nil;
    NSError *recorderSetupError = nil;
    NSURL *url = [NSURL fileURLWithPath:[self cafPath]];
    NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
    [settings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey: AVFormatIDKey];
    [settings setValue :[NSNumber numberWithFloat:8000.0] forKey: AVSampleRateKey];
      [settings setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    [settings setValue :[NSNumber numberWithInt:1] forKey: AVNumberOfChannelsKey];
    [settings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
    _recorder = [[AVAudioRecorder alloc] initWithURL:url
                                            settings:settings
                                               error:&recorderSetupError];
    if (recorderSetupError) {
        NSLog(@"%@",recorderSetupError);
    }
    _recorder.meteringEnabled = YES;
    _recorder.delegate = self;
    [_recorder prepareToRecord];
}
- (void)setSesstion{
    _session = [AVAudioSession sharedInstance];
    NSError *sessionError;
    [_session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
    if(_session == nil)
        NSLog(@"Error creating session: %@", [sessionError description]);
    else
        [_session setActive:YES error:nil];
}
#pragma mark - Public Methods
- (void)setSavePath:(NSString *)path{
    self.path = path;
}
- (void)startRecord{
    [self setSesstion];
    [self setRecorder];
    [_recorder record];
}
- (void)stopRecord{
    double cTime = _recorder.currentTime;
    _voiceTime = cTime;
    [_recorder stop];
    if (cTime > 1) {
        [self audi_Deal];
    }else {
#warning 暂时注释掉  打开的话 录音到最大值的时候APP会崩溃
        if ([_delegate respondsToSelector:@selector(failRecord)]) {
            [_delegate failRecord];
        }
    }
}
- (void)cancelRecord{
    [_recorder stop];
    [_recorder deleteRecording];
}
- (void)deleteMp3Cache{
    [self deleteFileWithPath:[self mp3Path]];
}
- (void)deleteAmrCache{
    [self deleteFileWithPath:[self amrPath]];
}
- (void)deleteCafCache{
    [self deleteFileWithPath:[self cafPath]];
}
- (void)deleteFileWithPath:(NSString *)path{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager removeItemAtPath:path error:nil]){
        NSLog(@"删除以前的文件");
    }
}
#pragma mark - Convert Utils
-(void) audi_Deal{
     NSString *cafFilePath = [self cafPath];
    if (_delegate && [_delegate respondsToSelector:@selector(beginConvert)]) {
        [_delegate beginConvert];
    }
    NSError  *error;
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategorySoloAmbient error: &error];
    if (_delegate && [_delegate respondsToSelector:@selector(endConvertWithData)]) {
        [_delegate endConvertWithData];
    }
       [self deleteCafCache];    
}
#pragma mark - Path Utils

-(NSString*) doucmentPath{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}
- (NSString *)cafPath
{
    NSString *cafPath = [[self doucmentPath] stringByAppendingPathComponent:@"tmp.wav"];
    return cafPath;
}
-(NSString*)amrPath{
    NSString *mp3Path = [[self doucmentPath] stringByAppendingPathComponent:@"amr.caf"];
    return mp3Path;
}
- (NSString *)mp3Path
{
    NSString *mp3Path = [[self doucmentPath] stringByAppendingPathComponent:@"mp3.caf"];
    return mp3Path;
}
@end
