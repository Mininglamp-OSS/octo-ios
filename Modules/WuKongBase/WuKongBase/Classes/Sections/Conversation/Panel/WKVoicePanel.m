// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKVoicePanel.m
//  WuKongBase
//
//  Created by tt on 2020/1/15.
//

#import "WKVoicePanel.h"
#import "Mp3Recorder.h"
#import "CWVoiceView.h"
#import "CWFlieManager.h"
#import "CWRecorder.h"
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <WuKongIMSDK/WKChannelMemberDB.h>
#import "CWRecordModel.h"
#import "CWSpeechToTextView.h"
#import "WKVoiceInputView.h"
#import "WKVoiceInputViewDelegate.h"
#import "WKVoiceInputService.h"
#import "WKInputMentionCache.h"

#define MAXWaveformNum 30

@interface WKVoicePanel ()<CWTalkBackViewDelegate,CWAudioPlayViewDelegate,CWSpeechToTextViewDelegate,CWVoiceChangePlayViewDelegate,WKVoiceInputViewDelegate>
@property(nonatomic,strong) CWVoiceView *voiceView;
@end

@implementation WKVoicePanel

-(instancetype) initWithContext:(id<WKConversationContext>)context {
    self = [super initWithContext:context];
    if (self) {
        [self setBackgroundColor:[WKApp shared].config.backgroundColor];
    }
    return self;
}
-(void) layoutPanel:(CGFloat)height {
    [super layoutPanel:height];
    if(!_voiceView) {
        WKVoiceInputConfig *config = [WKVoiceInputService shared].cachedConfig;
        BOOL enabled = config ? config.enabled : YES; // optimistic default

        _voiceView = [[CWVoiceView alloc] initWithFrame:CGRectMake(0, 0, WKScreenWidth, height)];
        _voiceView.voiceInputEnabled = enabled;
        _voiceView.talkBackViewDelegate = self;
        _voiceView.playViewDelegate = self;
        _voiceView.voiceChangePlayDelegate = self;
        _voiceView.speechToTextDelegate = self;
        _voiceView.voiceInputDelegate = self;
        [_voiceView setupSubViews];
        [_voiceView setBackgroundColor:[WKApp shared].config.backgroundColor];
        [self.contentView addSubview:_voiceView];
    }
    _voiceView.frame = self.contentView.bounds;
}

#pragma mark - CWTalkBackViewDelegate

- (void)beginRecord{
    [self.context startRecordingVoiceMessage];
}

-(void) talkBackViewSendRecord:(CWTalkBackView*) view second:(NSInteger)second {
    NSData *voiceData = [[NSData alloc] initWithContentsOfFile:[CWRecorder shareInstance].recordPath];
    if(voiceData) {
        [self sendVoiceMessage:voiceData second:second waveform:[CWRecordModel shareInstance].levels];
        [CWFlieManager removeFile:[CWRecorder shareInstance].recordPath];
    }
}

#pragma mark - CWAudioPlayViewDelegate
- (void)audioPlayView:(CWAudioPlayView *)view second:(NSInteger)second {
     NSData *voiceData = [[NSData alloc] initWithContentsOfFile:[CWRecordModel shareInstance].path];
    if(voiceData) {
        [self sendVoiceMessage:voiceData second:second waveform:[CWRecordModel shareInstance].levels];
        [CWFlieManager removeFile:[CWRecordModel shareInstance].path];
    }
}

#pragma mark - CWVoiceChangePlayViewDelegate

- (void)voiceChangePlayView:(CWVoiceChangePlayView *)view voicePath:(NSString *)path  second:(NSInteger)second {
    NSData *voiceData = [[NSData alloc] initWithContentsOfFile:path];
    if(voiceData) {
        [self sendVoiceMessage:voiceData second:second waveform:[CWRecordModel shareInstance].levels];
        [CWFlieManager removeFile:path];
    }
}

#pragma mark - CWSpeechToTextViewDelegate

- (void)speechToTextViewDidBeginRecording:(CWSpeechToTextView *)view {
    [self.context startRecordingVoiceMessage];
}

- (void)speechToTextView:(CWSpeechToTextView *)view didRecognizeText:(NSString *)text {
    if (text.length > 0) {
        [self.context sendTextMessage:text];
    }
}

- (void)speechToTextView:(CWSpeechToTextView *)view didRecognizeTextForInput:(NSString *)text {
    if (text.length > 0) {
        [self.context inputInsertText:text];
    }
}

#pragma mark - WKVoiceInputViewDelegate

- (void)voiceInputDidTranscribe:(NSString *)text shouldReplace:(BOOL)shouldReplace {
    if (shouldReplace) {
        if ([self.context respondsToSelector:@selector(inputSetText:)]) {
            [self.context inputSetText:text];
        }
    } else {
        if ([self.context respondsToSelector:@selector(inputInsertText:)]) {
            [self.context inputInsertText:text];
        }
    }
}

- (void)voiceInputInsertText:(NSString *)text {
    if ([text isEqualToString:@"@"]) {
        if ([self.context respondsToSelector:@selector(inputInsertText:)]) {
            [self.context inputInsertText:@"@"];
        }
        if ([self.context respondsToSelector:@selector(showMentionUsers)]) {
            [self.context showMentionUsers];
        }
    } else {
        if ([self.context respondsToSelector:@selector(inputInsertText:)]) {
            [self.context inputInsertText:text];
        }
    }
}

- (void)voiceInputDeleteBackward {
    if (![self.context respondsToSelector:@selector(inputSelectedRange)]) return;
    NSRange selectedRange = [self.context inputSelectedRange];

    if (selectedRange.length > 0) {
        if ([self.context respondsToSelector:@selector(inputDeleteText:)]) {
            [self.context inputDeleteText:selectedRange];
        }
    } else if (selectedRange.location > 0) {
        if ([self.context respondsToSelector:@selector(inputText)]) {
            NSString *text = [self.context inputText];
            NSRange charRange = [text rangeOfComposedCharacterSequenceAtIndex:selectedRange.location - 1];
            if ([self.context respondsToSelector:@selector(inputDeleteText:)]) {
                [self.context inputDeleteText:charRange];
            }
        }
    }
}

- (NSString *)voiceInputCurrentText {
    if ([self.context respondsToSelector:@selector(inputText)]) {
        return [self.context inputText];
    }
    return nil;
}

- (NSString *)voiceInputChatContext {
    NSMutableArray<NSString*> *parts = [NSMutableArray array];
    NSString *myUid = [WKApp shared].loginInfo.uid;
    WKChannel *channel = self.context.channel;

    // === 第一部分：聊天成员名单（与Web端 buildChatContext 对齐）===
    NSMutableArray<NSString*> *memberNames = [NSMutableArray array];
    NSMutableSet<NSString*> *uniqueNames = [NSMutableSet set];

    if (channel.channelType == WK_GROUP || channel.channelType == WK_COMMUNITY_TOPIC) {
        // 群聊/子区：从DB读取群成员（子区用父群的成员）
        WKChannel *memberChannel = channel;
        if (channel.channelType == WK_COMMUNITY_TOPIC) {
            WKChannel *parent = [self parentGroupChannel:channel];
            if (parent) memberChannel = parent;
        }
        NSArray<WKChannelMember*> *members = [[WKChannelMemberDB shared] getMembersWithChannel:memberChannel];
        if (members.count <= 100) {
            // 小群：收集所有成员
            for (WKChannelMember *member in members) {
                if ([member.memberUid isEqualToString:myUid]) continue;
                if (member.status != WKMemberStatusNormal) continue;
                WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfoOfUser:member.memberUid];
                if (info) {
                    NSString *name = info.name;
                    if (name.length > 0 && ![uniqueNames containsObject:name]) {
                        [uniqueNames addObject:name];
                        [memberNames addObject:name];
                    }
                    NSString *remark = info.remark;
                    if (remark.length > 0 && ![remark isEqualToString:name] && ![uniqueNames containsObject:remark]) {
                        [uniqueNames addObject:remark];
                        [memberNames addObject:remark];
                    }
                }
            }
        } else {
            // 大群(>100人)：只收集最后100条消息中的活跃成员
            NSMutableArray<WKMessageModel*> *allMsgs = [NSMutableArray array];
            for (NSString *date in [self.context dates]) {
                NSArray<WKMessageModel*> *msgs = [self.context messagesAtDate:date];
                if (msgs) [allMsgs addObjectsFromArray:msgs];
            }
            NSMutableOrderedSet<NSString*> *activeUids = [NSMutableOrderedSet orderedSet];
            for (NSInteger i = allMsgs.count - 1; i >= 0 && activeUids.count < 100; i--) {
                NSString *uid = allMsgs[i].fromUid;
                if (uid.length > 0 && ![uid isEqualToString:myUid]) {
                    [activeUids addObject:uid];
                }
            }
            for (NSString *uid in activeUids) {
                WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfoOfUser:uid];
                if (info) {
                    NSString *name = info.name;
                    if (name.length > 0 && ![uniqueNames containsObject:name]) {
                        [uniqueNames addObject:name];
                        [memberNames addObject:name];
                    }
                    NSString *remark = info.remark;
                    if (remark.length > 0 && ![remark isEqualToString:name] && ![uniqueNames containsObject:remark]) {
                        [uniqueNames addObject:remark];
                        [memberNames addObject:remark];
                    }
                }
            }
        }
    } else if (channel.channelType == WK_PERSON) {
        // 单聊：使用对方的名称和备注
        WKChannelInfo *peerInfo = [[WKSDK shared].channelManager getChannelInfo:channel];
        if (peerInfo) {
            if (peerInfo.name.length > 0 && ![uniqueNames containsObject:peerInfo.name]) {
                [uniqueNames addObject:peerInfo.name];
                [memberNames addObject:peerInfo.name];
            }
            if (peerInfo.remark.length > 0 && ![peerInfo.remark isEqualToString:peerInfo.name] && ![uniqueNames containsObject:peerInfo.remark]) {
                [uniqueNames addObject:peerInfo.remark];
                [memberNames addObject:peerInfo.remark];
            }
        }
    }

    if (memberNames.count > 0) {
        [parts addObject:[NSString stringWithFormat:@"聊天成员：%@", [memberNames componentsJoinedByString:@","]]];
    }

    // === 第二部分：最后10条消息 ===
    NSMutableArray<WKMessageModel*> *allMessages = [NSMutableArray array];
    for (NSString *date in [self.context dates]) {
        NSArray<WKMessageModel*> *msgs = [self.context messagesAtDate:date];
        if (msgs) [allMessages addObjectsFromArray:msgs];
    }

    // 过滤文本类型消息
    NSMutableArray<WKMessageModel*> *textMessages = [NSMutableArray array];
    for (WKMessageModel *msg in allMessages) {
        NSString *content = msg.content.contentDict[@"content"];
        if (content.length > 0 && (msg.contentType == WK_TEXT || msg.content.contentDict[@"type"])) {
            [textMessages addObject:msg];
        }
    }

    if (textMessages.count > 0) {
        NSInteger count = MIN(textMessages.count, 10);
        NSArray<WKMessageModel*> *recentMessages = [textMessages subarrayWithRange:NSMakeRange(textMessages.count - count, count)];

        NSMutableArray<NSString*> *msgLines = [NSMutableArray array];
        for (WKMessageModel *msg in recentMessages) {
            NSString *text = msg.content.contentDict[@"content"];
            NSString *name = nil;
            WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfoOfUser:msg.fromUid];
            if (info) {
                name = info.displayName;
            }
            if (!name || name.length == 0) {
                name = msg.fromUid;
            }
            [msgLines addObject:[NSString stringWithFormat:@"[%@]: %@", name, text]];
        }
        [parts addObject:[msgLines componentsJoinedByString:@"\n"]];
    }

    NSString *finalContext = parts.count > 0 ? [parts componentsJoinedByString:@"\n"] : nil;
    // R4: metadata-only 且 DEBUG-gate, 避免生产日志噪音
#if DEBUG
    NSLog(@"[VoicePanel] voiceInputChatContext → channelType=%d, memberNames=%lu, textMsgs=%lu, finalLen=%lu",
          (int)channel.channelType,
          (unsigned long)memberNames.count,
          (unsigned long)textMessages.count,
          (unsigned long)finalContext.length);
#endif
    return finalContext;
}

- (NSRange)voiceInputSelectedRange {
    if ([self.context respondsToSelector:@selector(inputSelectedRange)]) {
        return [self.context inputSelectedRange];
    }
    return NSMakeRange(0, 0);
}

- (void)voiceInputRecordingDidStart {
    [self.context startRecordingVoiceMessage];
}

- (void)voiceInputRecordingDidStop {
    // 录音结束，无需额外操作
}

- (void)voiceInputRequestCursor {
    if ([self.context respondsToSelector:@selector(inputBecomeFirstResponder)]) {
        [self.context inputBecomeFirstResponder];
    }
}

- (WKChannel *)voiceInputChannel {
    if ([self.context respondsToSelector:@selector(channel)]) {
        return self.context.channel;
    }
    return nil;
}

- (NSArray<WKChannelMember *> *)voiceInputChannelMembers {
    if (![self.context respondsToSelector:@selector(channel)]) return @[];
    WKChannel *channel = self.context.channel;
    // 子区成员在父群上
    if (channel.channelType == WK_COMMUNITY_TOPIC) {
        WKChannel *parentChannel = [self parentGroupChannel:channel];
        if (parentChannel) return [[WKChannelMemberDB shared] getMembersWithChannel:parentChannel];
    }
    return [[WKChannelMemberDB shared] getMembersWithChannel:channel];
}

- (WKChannel *)parentGroupChannel:(WKChannel *)channel {
    NSRange sep = [channel.channelId rangeOfString:@"____"];
    if (sep.location != NSNotFound) {
        NSString *groupNo = [channel.channelId substringToIndex:sep.location];
        return [WKChannel groupWithChannelID:groupNo];
    }
    return nil;
}

- (void)voiceInputDidTranscribe:(NSString *)text
                       mentions:(NSArray<WKInputMentionItem *> *)mentions
                  shouldReplace:(BOOL)shouldReplace {
    NSLog(@"[VoicePanel] voiceInputDidTranscribe:mentions: mentions=%lu, shouldReplace=%d",
          (unsigned long)mentions.count, shouldReplace);

    if (mentions.count > 0 && [self.context respondsToSelector:@selector(addMentionItems:)]) {
        NSLog(@"[VoicePanel] writing %lu mentions to mentionCache", (unsigned long)mentions.count);
        [self.context addMentionItems:mentions];
    }

    if (shouldReplace) {
        if ([self.context respondsToSelector:@selector(inputSetText:)]) {
            [self.context inputSetText:text];
        }
    } else {
        if ([self.context respondsToSelector:@selector(inputInsertText:)]) {
            [self.context inputInsertText:text];
        }
    }
}

-(void) sendVoiceMessage:(NSData*)voiceData second:(NSInteger)second waveform:(NSArray<NSNumber*>*)waveform{
    if(second<=0) {
        [[WKNavigationManager shared].topViewController.view showHUDWithHide:LLang(@"说话时间太短")];
        return;
    }
    NSData *waveforms = [self cutAudioWaveform:waveform];
    [self.context sendMessage:[WKVoiceContent initWithData:voiceData second:(int)second waveform:waveforms]];
}

-(NSData*) cutAudioWaveform:(NSArray<NSNumber*>*)waveform {
    NSMutableData *filteredSamplesMA = [[NSMutableData alloc]init];
    CGFloat width =  200.0f;
    CGFloat height = 50.0f;
    NSInteger sampleCount = waveform.count;
    NSUInteger binSize = waveform.count / (width * 0.1);
    if(binSize==0) {
        for (NSNumber *wf in waveform) {
            uint8_t v = (uint8_t)(MAX(wf.floatValue * 100.0f, 255));
            [filteredSamplesMA appendBytes:&v length:1];
        }
        return filteredSamplesMA;
    }
    //以binSize为一个样本。每个样本中取一个最大数。也就是在固定范围取一个最大的数据保存，达到缩减目的
    SInt16 maxSample = 0; //sint16两个字节的空间
    for (NSUInteger i= 0; i < sampleCount; i += binSize) {
        uint8_t sampleBin[binSize];
        for (NSUInteger j = 0; j < binSize; j++) {
            if(i+j < waveform.count){
                sampleBin[j] = (uint8_t)(MIN(waveform[i+j].floatValue * 100.0f, 255));
            }
        }
        //选取样本数据中最大的一个数据
        uint8_t value = [self maxValueInArray:sampleBin ofSize:binSize];
        //保存数据
        [filteredSamplesMA appendBytes:&value length:1];
        //将所有数据中的最大数据保存，作为一个参考。可以根据情况对所有数据进行“缩放”
        if (value > maxSample) {
            maxSample = value;
        }
    }
//    //计算比例因子
//    CGFloat scaleFactor = (height * 0.5)/maxSample;
//    //对所有数据进行“缩放”
//    for (NSUInteger i = 0; i < filteredSamplesMA.count; i++) {
//
//        filteredSamplesMA[i] = @([filteredSamplesMA[i] integerValue] * scaleFactor);
//    }
    
    return filteredSamplesMA;
}
//比较大小的方法，返回最大值
- (uint8_t)maxValueInArray:(uint8_t[])values ofSize:(NSUInteger)size {
    uint8_t maxvalue = 0;
    for (int i = 0; i < size; i++) {
        
        if (abs(values[i] > maxvalue)) {
            
            maxvalue = values[i];
        }
    }
    return maxvalue;
}

@end
