//
//  WKVoiceContent.m
//  WuKongIMSDK
//
//  Created by tt on 2020/1/16.
//

#import "WKVoiceContent.h"
#import "WKSDK.h"
#import "WKMediaUtil.h"
#import "WKFileUtil.h"
#import "VoiceConverter.h"
@interface WKVoiceContent ()


@end
@implementation WKVoiceContent

// waveform 为音频波浪数据
+ (instancetype)initWithData:(NSData *)voiceData second:(int)second waveform:(NSData*)waveform{
    WKVoiceContent *voiceContent = [WKVoiceContent new];
    voiceContent.voiceData = voiceData;
    voiceContent.second = second;
    voiceContent.waveform = waveform;
    return voiceContent;
}

-(void)writeDataToLocalPath {
    [super writeDataToLocalPath];
    
    
    if(self.voiceData) {
        [self.voiceData writeToFile:self.localPath atomically:YES];
        // 转码amr
        [VoiceConverter EncodeWavToAmr:self.localPath amrSavePath:self.thumbPath sampleRateType:Sample_Rate_8000];
    }
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    self.remoteUrl = contentDic[@"url"];
    self.second = contentDic[@"timeTrad"]?[contentDic[@"timeTrad"] integerValue]:0;
    
    NSString *waveformStr = contentDic[@"waveform"];
    if(waveformStr && ![waveformStr isEqualToString:@""]) {
       self.waveform = [[NSData alloc] initWithBase64EncodedString:waveformStr options:NSDataBase64DecodingIgnoreUnknownCharacters];
    }
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:self.remoteUrl?:@"" forKey:@"url"];
    [dataDict setObject:@(self.second) forKey:@"timeTrad"];
    if(self.waveform) {
        [dataDict setObject:[self.waveform base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed] forKey:@"waveform"];
    }
    return dataDict;
}
// 语音的源文件扩展名
- (NSString *)extension {
    return @".wav";
}

// 语音的副本文件扩展名
- (NSString *)thumbExtension {
    return @".amr";
}

+(NSNumber*) contentType {
    return @(WK_VOICE);
}

- (NSString *)conversationDigest {
    return @"[语音]";
}

- (NSString *)searchableWord {
    return @"[语音]";
}

- (BOOL)viewedOfVisible {
    if(self.message && self.message.isSend) {
        return true;
    }
    return false;
}

- (NSInteger)flameSecond {
   NSInteger oldFlameSecond =  [super flameSecond];
    if(self.flame && self.second>oldFlameSecond) {
        return self.second+1;
    }
    return oldFlameSecond;

}

@end
