//
//  WKVoiceInputService.m
//  WuKongBase
//

#import "WKVoiceInputService.h"
#import "WKAPIClient.h"
#import "WKApp.h"

static const NSTimeInterval kConfigCacheTTL = 300.0;  // 5 分钟缓存
static const NSTimeInterval kTranscribeTimeout = 30.0;

@interface WKVoiceInputService ()
@property (nonatomic, strong, nullable) WKVoiceInputConfig *cachedConfig;
@property (nonatomic, assign) NSTimeInterval cachedAt;
@end

@implementation WKVoiceInputConfig
@end

@implementation WKVoiceInputResult
@end

@implementation WKVoiceInputService

+ (instancetype)shared {
    static WKVoiceInputService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKVoiceInputService alloc] init];
    });
    return instance;
}

- (void)fetchConfigWithCompletion:(void(^)(WKVoiceInputConfig *, NSError *))completion {
    // 检查缓存
    if (self.cachedConfig &&
        ([[NSDate date] timeIntervalSince1970] - self.cachedAt) < kConfigCacheTTL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(self.cachedConfig, nil);
        });
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[WKAPIClient sharedClient] GET:@"voice/config" parameters:nil].then(^(NSDictionary *resp) {
        WKVoiceInputConfig *config = [[WKVoiceInputConfig alloc] init];
        config.enabled = [resp[@"enabled"] boolValue];
        config.maxDuration = [resp[@"max_duration"] integerValue];
        if (config.maxDuration <= 0) config.maxDuration = 60;

        weakSelf.cachedConfig = config;
        weakSelf.cachedAt = [[NSDate date] timeIntervalSince1970];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(config, nil);
        });
    }).catch(^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, error);
        });
    });
}

- (void)prefetchConfig {
    [self fetchConfigWithCompletion:nil];
}

- (void)clearConfigCache {
    self.cachedConfig = nil;
    self.cachedAt = 0;
}

- (void)transcribeAudio:(NSData *)audioData
            contextText:(NSString *)contextText
            chatContext:(NSString *)chatContext
             completion:(void(^)(WKVoiceInputResult *, NSError *))completion {

    // 检查文件大小（max 5MB）
    if (audioData.length > 5 * 1024 * 1024) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"WKVoiceInput"
                                                code:413
                                            userInfo:@{NSLocalizedDescriptionKey: @"Audio file too large"}]);
        }
        return;
    }

    // 组装表单文本字段
    NSMutableDictionary *formFields = [NSMutableDictionary dictionary];
    if (contextText.length > 0) {
        formFields[@"context_text"] = contextText;
    }
    if (chatContext.length > 0) {
        formFields[@"chat_context"] = chatContext;
    }

    NSLog(@"[VoiceInput] ===== 语音转写请求 =====");
    NSLog(@"[VoiceInput] context_text: %@", contextText ?: @"(nil)");
    NSLog(@"[VoiceInput] chat_context: %@", chatContext ?: @"(nil)");
    NSLog(@"[VoiceInput] audio size: %lu bytes", (unsigned long)audioData.length);

    [[WKAPIClient sharedClient] fileUpload:@"voice/transcribe"
                                formFields:formFields
                                  fileData:audioData
                                  fileName:@"recording.m4a"
                                 fileField:@"audio"
                                  mimeType:@"audio/mp4"
                                   timeout:kTranscribeTimeout
                          completeCallback:^(id responseObject, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"[VoiceInput] ===== 转写失败 =====");
                NSLog(@"[VoiceInput] error: %@", error.localizedDescription);
                if (completion) completion(nil, error);
                return;
            }

            NSLog(@"[VoiceInput] ===== 转写结果 =====");
            NSLog(@"[VoiceInput] status: %@", responseObject[@"status"]);
            NSLog(@"[VoiceInput] text: %@", responseObject[@"text"] ?: @"(nil)");
            NSLog(@"[VoiceInput] model: %@", responseObject[@"model"] ?: @"(nil)");

            // 检查响应 status 字段
            NSInteger status = [responseObject[@"status"] integerValue];
            if (status != 200) {
                NSString *msg = responseObject[@"msg"] ?: @"transcription failed";
                NSError *apiError = [NSError errorWithDomain:@"WKVoiceInput"
                                                       code:status
                                                   userInfo:@{NSLocalizedDescriptionKey: msg}];
                if (completion) completion(nil, apiError);
                return;
            }

            WKVoiceInputResult *result = [[WKVoiceInputResult alloc] init];
            result.text = responseObject[@"text"] ?: @"";
            result.model = responseObject[@"model"] ?: @"";
            if (completion) completion(result, nil);
        });
    }];
}

@end
