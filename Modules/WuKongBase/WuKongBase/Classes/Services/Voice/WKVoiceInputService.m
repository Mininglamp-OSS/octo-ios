//
//  WKVoiceInputService.m
//  WuKongBase
//

#import "WKVoiceInputService.h"
#import "WKAPIClient.h"
#import "WKApp.h"

static const NSTimeInterval kConfigCacheTTL = 300.0;  // 5 分钟缓存
static const NSTimeInterval kVoiceContextCacheTTL = 300.0; // 5 分钟缓存
static const NSTimeInterval kVoiceContextTimeout = 3.0; // 3 秒超时
static const NSTimeInterval kTranscribeTimeout = 30.0;

@interface WKVoiceInputService ()
@property (nonatomic, strong, nullable) WKVoiceInputConfig *cachedConfig;
@property (nonatomic, assign) NSTimeInterval cachedAt;
// voice context
@property (nonatomic, copy, nullable) NSString *cachedVoiceContext;
@property (nonatomic, assign) BOOL cachedVoiceContextHasValue;
@property (nonatomic, assign) NSTimeInterval voiceContextCachedAt;
@property (nonatomic, copy, nullable) NSString *voiceContextSpaceId;
@property (nonatomic, assign) BOOL voiceContextInflight;
@property (nonatomic, strong, nullable) NSMutableArray *voiceContextPendingCallbacks;
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

#pragma mark - Voice Context

- (void)prefetchVoiceContext {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentSpaceId"];
    if (!spaceId || spaceId.length == 0) return;

    // 检查缓存是否有效
    if (self.cachedVoiceContextHasValue &&
        [self.voiceContextSpaceId isEqualToString:spaceId] &&
        ([[NSDate date] timeIntervalSince1970] - self.voiceContextCachedAt) < kVoiceContextCacheTTL) {
        NSLog(@"[VoiceContext] 使用缓存 context (spaceId=%@)", spaceId);
        return;
    }

    // 防重复请求
    if (self.voiceContextInflight && [self.voiceContextSpaceId isEqualToString:spaceId]) {
        NSLog(@"[VoiceContext] 请求进行中，跳过重复请求");
        return;
    }

    self.voiceContextInflight = YES;
    self.voiceContextSpaceId = spaceId;
    NSLog(@"[VoiceContext] 开始预取 (spaceId=%@)", spaceId);

    NSString *path = [NSString stringWithFormat:@"voice/context?space_id=%@", spaceId];

    // 带超时的请求
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kVoiceContextTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.voiceContextInflight && [weakSelf.voiceContextSpaceId isEqualToString:spaceId]) {
            NSLog(@"[VoiceContext] 请求超时");
            weakSelf.voiceContextInflight = NO;
            [weakSelf flushVoiceContextCallbacks:nil];
        }
    });

    [[WKAPIClient sharedClient] GET:path parameters:nil].then(^(NSDictionary *resp) {
        NSLog(@"[VoiceContext] 预取完成: has_context=%@, context=%@",
              resp[@"has_context"], resp[@"context"] ?: @"(nil)");
        weakSelf.voiceContextInflight = NO;
        BOOL hasContext = [resp[@"has_context"] boolValue];
        NSString *context = resp[@"context"];
        if (hasContext && context && ![context isKindOfClass:[NSNull class]] && context.length > 0) {
            weakSelf.cachedVoiceContext = context;
        } else {
            weakSelf.cachedVoiceContext = nil;
        }
        weakSelf.cachedVoiceContextHasValue = YES;
        weakSelf.voiceContextCachedAt = [[NSDate date] timeIntervalSince1970];
        [weakSelf flushVoiceContextCallbacks:weakSelf.cachedVoiceContext];
    }).catch(^(NSError *error) {
        NSLog(@"[VoiceContext] 预取失败: %@", error.localizedDescription);
        weakSelf.voiceContextInflight = NO;
        weakSelf.cachedVoiceContext = nil;
        weakSelf.cachedVoiceContextHasValue = NO;
        [weakSelf flushVoiceContextCallbacks:nil];
    });
}

- (void)getVoiceContextWithCompletion:(void(^)(NSString *context))completion {
    if (!completion) return;

    // 已有缓存
    if (self.cachedVoiceContextHasValue && !self.voiceContextInflight) {
        completion(self.cachedVoiceContext);
        return;
    }

    // 正在请求中，加入等待队列
    if (self.voiceContextInflight) {
        if (!self.voiceContextPendingCallbacks) {
            self.voiceContextPendingCallbacks = [NSMutableArray array];
        }
        [self.voiceContextPendingCallbacks addObject:[completion copy]];
        return;
    }

    // 无缓存且无请求，直接返回 nil
    completion(nil);
}

- (void)flushVoiceContextCallbacks:(NSString *)context {
    NSArray *callbacks = [self.voiceContextPendingCallbacks copy];
    self.voiceContextPendingCallbacks = nil;
    for (void(^cb)(NSString *) in callbacks) {
        cb(context);
    }
}

- (void)clearVoiceContextCache {
    NSLog(@"[VoiceContext] 清除缓存");
    self.cachedVoiceContext = nil;
    self.cachedVoiceContextHasValue = NO;
    self.voiceContextCachedAt = 0;
    self.voiceContextInflight = NO;
    self.voiceContextPendingCallbacks = nil;
}

#pragma mark - Transcribe

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

- (void)transcribeWavAudio:(NSData *)audioData
               contextText:(NSString *)contextText
               chatContext:(NSString *)chatContext
                completion:(void(^)(WKVoiceInputResult *, NSError *))completion {

    if (audioData.length > 10 * 1024 * 1024) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"WKVoiceInput" code:413
                                            userInfo:@{NSLocalizedDescriptionKey: @"Audio file too large"}]);
        }
        return;
    }

    NSMutableDictionary *formFields = [NSMutableDictionary dictionary];
    if (contextText.length > 0) formFields[@"context_text"] = contextText;
    if (chatContext.length > 0) formFields[@"chat_context"] = chatContext;

    NSLog(@"[VoiceInput] ===== WAV 语音转写请求 =====");
    NSLog(@"[VoiceInput] audio size: %lu bytes", (unsigned long)audioData.length);

    [[WKAPIClient sharedClient] fileUpload:@"voice/transcribe"
                                formFields:formFields
                                  fileData:audioData
                                  fileName:@"recording.wav"
                                 fileField:@"audio"
                                  mimeType:@"audio/wav"
                                   timeout:kTranscribeTimeout
                          completeCallback:^(id responseObject, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            NSInteger status = [responseObject[@"status"] integerValue];
            if (status != 200) {
                NSString *msg = responseObject[@"msg"] ?: @"transcription failed";
                if (completion) completion(nil, [NSError errorWithDomain:@"WKVoiceInput" code:status
                                                               userInfo:@{NSLocalizedDescriptionKey: msg}]);
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
