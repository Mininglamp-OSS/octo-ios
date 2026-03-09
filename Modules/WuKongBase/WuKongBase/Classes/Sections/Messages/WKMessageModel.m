//
//  WKMessageVM.m
//  WuKongBase
//
//  Created by tt on 2019/12/28.
//

#import "WKMessageModel.h"
#import "WKApp.h"
#import "WKTimeTool.h"
#import "WKSecurityTipManager.h"
#import "WuKongBase.h"
#import "NSAttributedString+Markdown.h"
#import "WKMarkdownParser.h"
#import "NSMutableAttributedString+WK.h"
#import <WuKongBase/WuKongBase-Swift.h>

@interface WKMessageModel ()

@property(nonatomic,strong) NSMutableArray *reactionsInner;

@property(nonatomic,strong) NSMutableDictionary<NSString*,NSNumber*> *reactionsTop3DictInner;

@property(nonatomic,strong) NSMutableArray<WKReaction*> *reactionTop3Inner;

@property(nonatomic,assign) BOOL sensitiveWordIsMatch; // 敏感词是否已经匹配过了

@property(nonatomic,assign) BOOL _hasSensitiveWord;

@property(nonatomic,assign) WKReason oldReasonCode;

@property(nonatomic,strong) WKMarkdownParser *reasonMarkDownParser;

@property(nonatomic,assign) BOOL streamLoadedFromDB; // 流是否已成DB中加载

@property(nonatomic,strong) NSMutableArray<WKStream*> *streamsInner;



@end

@implementation WKMessageModel

-(instancetype) initWithMessage:(WKMessage*)message {
    self = [super init];
    if(self) {
        self.message = message;
        self.flameIconSizeFactor = 0.4f;
    }
    return self;
}

- (WKSetting *)setting {
    return self.message.setting;
}

- (uint32_t)clientSeq {
    return self.message.clientSeq;
}

- (NSString *)clientMsgNo {
    return self.message.clientMsgNo;
}
- (uint64_t)messageId {
    return self.message.messageId;
}
- (uint32_t)messageSeq {
    return self.message.messageSeq;
}

- (uint32_t)orderSeq {
    return self.message.orderSeq;
}
- (NSInteger)timestamp {
    return self.message.timestamp;
}

- (NSString *)dateStr {
    if(!_dateStr) {
        _dateStr = [WKTimeTool getTimeString:[NSDate dateWithTimeIntervalSince1970: self.timestamp] format:@"yyyy-MM-dd"];
    }
    return _dateStr;
}

- (NSString *)timeStr {
    if(!_timeStr) {
        _timeStr = [WKTimeTool formatTimeByAutoAMPM:[NSDate dateWithTimeIntervalSince1970:self.timestamp]];
    }
    return _timeStr;
}

- (NSString *)editedAtStr {
    if(!_editedAtStr) {
        if(self.remoteExtra.isEdit) {
            _editedAtStr = [WKTimeTool formatTimeByAutoAMPM:[NSDate dateWithTimeIntervalSince1970:self.remoteExtra.editedAt]];
        }
    }
    return _editedAtStr;
}

- (NSInteger)localTimestamp {
     return self.message.localTimestamp;
}

- (NSString *)fromUid {
    return self.message.fromUid;
}
- (WKChannelInfo *)from {
    return self.message.from;
}

- (void)setFrom:(WKChannelInfo *)from {
    self.message.from = from;
}

-(WKChannelMember*) memberOfFrom {
    return self.message.memberOfFrom;
}

- (NSString *)toUid {
    return self.message.toUid;
}

- (WKChannel *)channel {
    return self.message.channel;
}
- (WKChannelInfo *)channelInfo {
    return self.message.channelInfo;
}
- (NSInteger)contentType {
    return self.message.contentType;
}

- (WKMessageContent *)content {
    return self.message.content;
}
- (BOOL)isSend {
    if(!self.fromUid || [self.fromUid isEqualToString:@""] || [self.fromUid isEqualToString:[WKApp shared].loginInfo.uid]) {
        return true;
    }
    return false;
}

- (WKMessageStatus)status {
    return self.message.status;
}

- (void)setStatus:(WKMessageStatus)status {
    self.message.status = status;
}

- (WKReason)reasonCode {
    return self.message.reasonCode;
}
- (NSMutableAttributedString *)reason {
    if(self.oldReasonCode != self.reasonCode) {
        _reason = [self getReason];
        self.oldReasonCode = self.reasonCode;
    }
    return _reason;
}

- (WKMarkdownParser *)reasonMarkDownParser {
    if(!_reasonMarkDownParser) {
        _reasonMarkDownParser = [[WKMarkdownParser alloc] init];
    }
    return _reasonMarkDownParser;
}

-(NSMutableAttributedString*) getReason{
    WKReason reasonCode = self.reasonCode;
    uint8_t channelType =  self.channel.channelType;
    if(reasonCode == WK_REASON_NOT_IN_WHITELIST || reasonCode == WK_REASON_IN_BLACKLIST) {
        if(channelType == WK_PERSON) {
            WKChannelInfo *channelInfo = self.channelInfo;
            if(reasonCode == WK_REASON_IN_BLACKLIST) {
                if(channelInfo && !channelInfo.beBlacklist) {
                    return [[NSMutableAttributedString alloc] initWithString:LLang(@"已把对方拉黑。")];
                }
                return [[NSMutableAttributedString alloc] initWithString:LLang(@"消息已发出，但被对方拒收了。")];
            }
            
            NSString *name = @"--";
           
            if(channelInfo) {
                name = channelInfo.displayName;
            }
            NSString *verStr = [NSString stringWithFormat:LLang(@"开启了朋友验证，你还不是他（她）朋友。请先发送朋友验证请求，对方验证通过后，才能聊天。[发送朋友验证](%@://friend/apply?uid=%@)"),WKApp.shared.config.appSchemaPrefix,self.channel.channelId];
            NSString *str =  [NSString stringWithFormat:@"%@%@",name,verStr];
            
           NSArray<id<WKMatchToken>> *tokens = [self.reasonMarkDownParser parseMarkdownIntoAttributedString:str];
            NSMutableAttributedString *result =  [[NSMutableAttributedString alloc] init];
            [result lim_render:str tokens:tokens];
            
            return result;
        }else {
            return [[NSMutableAttributedString alloc] initWithString:LLang(@"已被踢出群聊或拉入黑名单，不能发送消息")];
        }
    }
    return nil;
}

- (NSDictionary *)extra {
    return self.message.extra;
}

- (BOOL)readed {
    return self.message.remoteExtra.readed;
}

- (NSDate *)readedAt {
    return self.message.remoteExtra.readedAt;
}

- (void)setReaded:(BOOL)readed {
    self.message.remoteExtra.readed = readed;
}

- (BOOL)voiceReaded {
    return self.message.voiceReaded;
}
- (void)setVoiceReaded:(BOOL)voiceReaded {
    self.message.voiceReaded = voiceReaded;
}

- (BOOL)revoke {
    return self.message.remoteExtra.revoke;
}

- (WKMessageExtra *)remoteExtra {
    return self.message.remoteExtra;
}

- (id<WKTaskProto>)task {
    return self.message.task;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[self class]]) {
        WKMessageModel *another = (WKMessageModel *)object;
        
        return self.clientSeq!=0 && self.clientSeq == another.clientSeq;
    }
    
    return NO;
}

- (NSInteger)reminderAnimationCount {
    if(_reminderAnimationCount<=0) {
        return 1;
    }
    return _reminderAnimationCount;
}

- (NSUInteger)hash {
    return self.clientSeq;
}

- (BOOL)isPersonChannel {
    return self.channel.channelType == WK_PERSON;
}

- (NSArray<WKReaction *> *)reactions {
    if(!_reactionsInner) {
        _reactionsInner = [NSMutableArray arrayWithArray:self.message.reactions];
    }
    return  _reactionsInner;
}

- (NSMutableDictionary<NSString *,NSNumber *> *)reactionsTop3DictInner {
    if(!_reactionsTop3DictInner) {
        _reactionsTop3DictInner = [NSMutableDictionary dictionary];
        if(self.reactions && self.reactions.count>0) {
            for (WKReaction *reaction in self.reactions) {
                NSNumber *emojiCount = _reactionsTop3DictInner[reaction.emoji];
                if(emojiCount == nil) {
                    emojiCount = @(0);
                }
                _reactionsTop3DictInner[reaction.emoji] = @(emojiCount.intValue+1);
            }
        }
    }
    return _reactionsTop3DictInner;
}

- (NSArray<WKReaction *> *)reactionTop3 {
    if(_reactionTop3Inner) {
        return  _reactionTop3Inner;
    }
    
    
    [self reloadCalcReactionTop3];
    
    return _reactionTop3Inner;
}

-(void) reloadCalcReactionTop3 {
    _reactionTop3Inner = [NSMutableArray array];
    
    for (NSString *emoji in self.reactionsTop3DictInner.allKeys) {
       NSNumber *count = self.reactionsTop3DictInner[emoji];
        
        if(_reactionTop3Inner.count==0) {
            WKReaction *reaction = [[WKReaction alloc] init];
            reaction.emoji = emoji;
            [_reactionTop3Inner addObject:reaction];
        }else {
            BOOL isSwap = false; // 是否交换
            for (NSInteger i=0; i<_reactionTop3Inner.count; i++) {
                WKReaction *topReaction = _reactionTop3Inner[i];
                NSNumber *topEmojiCount = self.reactionsTop3DictInner[topReaction.emoji];
                if(count.intValue>topEmojiCount.intValue) {
                    WKReaction *topRea = [[WKReaction alloc] init];
                    topRea.emoji = emoji;
                    if(i<2) {
                        WKReaction *oldReaction = _reactionTop3Inner[i];
                        _reactionTop3Inner[i] = topRea;
                        [_reactionTop3Inner insertObject:oldReaction atIndex:i+1];
                    }else{
                        _reactionTop3Inner[i] = topRea;
                    }
                   
                    isSwap = true;
                    break;
                }
            }
            if(!isSwap) {
                if(_reactionTop3Inner.count<3) {
                    WKReaction *topRea = [[WKReaction alloc] init];
                    topRea.emoji = emoji;
                    [_reactionTop3Inner addObject:topRea];
                }
            }
        }
    };
}

-(void) addReaction:(WKReaction*)reaction {
    NSInteger existIndex = -1;
    for (NSInteger i=0; i<self.reactionsInner.count; i++) {
        WKReaction *oldReaction = self.reactionsInner[i];
        if(reaction.messageId==oldReaction.messageId && [reaction.uid isEqualToString:oldReaction.uid]) {
            existIndex = i;
            break;
        }
    }
    
    if(existIndex!=-1) { // 移除旧的回应
       WKReaction *oldReaction = [self.reactionsInner objectAtIndex:existIndex];
        
        NSNumber *emojiCount = self.reactionsTop3DictInner[oldReaction.emoji];
        if(emojiCount.intValue > 1) {
            self.reactionsTop3DictInner[oldReaction.emoji] = @(emojiCount.intValue-1);
        }else {
            [self.reactionsTop3DictInner removeObjectForKey:oldReaction.emoji];
        }
        
        [self.reactionsInner removeObjectAtIndex:existIndex];
    }
    [self.reactionsInner addObject:reaction];
    
    if(_reactionsTop3DictInner) { // 这里必须 _reactionsTop3DictInner 如果使用self.reactionsTop3DictInner会触发重写的get方法
        NSNumber *emojiCount = self.reactionsTop3DictInner[reaction.emoji];
        if(emojiCount == nil) {
            emojiCount = @(0);
        }
        self.reactionsTop3DictInner[reaction.emoji] = @(emojiCount.intValue+1);
    }
    
   
    [self reloadCalcReactionTop3]; // 重新计算top3
}

- (void)cancelReaction:(WKReaction *)reaction {
    NSInteger removeIndex = -1;
    for (NSInteger i=0; i<self.reactions.count; i++) {
        WKReaction *react = self.reactions[i];
        if([react.uid isEqualToString:reaction.uid] && [react.emoji isEqualToString:reaction.emoji]) {
            removeIndex = i;
            break;
        }
    }
    if(removeIndex!=-1) {
        WKReaction *removeReaction = [self.reactionsInner objectAtIndex:removeIndex];
        [self.reactionsInner removeObjectAtIndex:removeIndex];
        NSNumber *emojiCount = self.reactionsTop3DictInner[removeReaction.emoji];
        if(emojiCount.intValue == 1) {
            [self.reactionsTop3DictInner removeObjectForKey:removeReaction.emoji];
        }else {
            self.reactionsTop3DictInner[removeReaction.emoji] = @(emojiCount.intValue-1);
        }
        [self reloadCalcReactionTop3]; // 重新计算top3
    }
}

-(BOOL) hasSensitiveWord {
    if(self.sensitiveWordIsMatch) {
        return self._hasSensitiveWord;
    }
    if(self.contentType == WK_TEXT) {
       WKTextContent *textContent =  (WKTextContent*)self.content;
        
       self._hasSensitiveWord =  [[WKSecurityTipManager shared] match:textContent.content];
    }
    self.sensitiveWordIsMatch = true;
    return self._hasSensitiveWord;
}

- (BOOL)viewed {
    
    return self.message.viewed;
}

- (NSInteger)viewedAt {
   
    return self.message.viewedAt;
}


- (NSMutableDictionary *)tmpObject {
    if(!_tmpObject) {
        _tmpObject = [NSMutableDictionary dictionary];
    }
    return _tmpObject;
}

- (RadialStatusNode *)flameNode {
    if(!_flameNode) {
        if(![self needFlame]) {
            return nil;
        }
        // 阅后即焚
        _flameNode = [[RadialStatusNode alloc] initWithBackgroundNodeColor:[UIColor colorWithWhite:0.0f alpha:0.5f] enableBlur:false];
        _flameNode.view.lim_size = CGSizeMake(20.0f, 20.0f);
    }
    return _flameNode;
}

-(void) startFlameIfNeed:(void(^)(void))finished {
    if(self.startingFlameFlag) {
        return;
    }
    self.startingFlameFlag = true;
    if(self.content.flame) {
        
        if(self.content.flameSecond<=0 || !self.viewed) {
            [self startFlame:10000000 keep:true finished:finished];
        } else {
            NSInteger remainderFlame = [self remainderFlame];
            if(remainderFlame>0) {
                [self startFlame:remainderFlame keep:false finished:finished];
            }
        }
    }
}

-(BOOL) needFlame {
    if(self.content.flame && !self.viewed) {
        return true;
    }
    if(!self.content.flame || (self.content.flameSecond>0&&self.remainderFlame<=0)) {
        return false;
    }
    return true;
}

-(NSInteger) remainderFlame {
    NSInteger viewedAt = self.viewedAt;
    if(viewedAt>0) {
       NSInteger flameSecond =  self.content.flameSecond -  ([[NSDate date] timeIntervalSince1970] -viewedAt);
        return flameSecond;
    }
    return 0;
}


// 阅后即焚开始销毁
-(void) startFlame:(NSInteger)remainderFlame keep:(BOOL)keep finished:(void(^)(void))finished{
    NSLog(@"startFlame----->%@",self.clientMsgNo);
    UIImage *flameIcon =  [WKGenerateImageUtils generateTintedImgWithImage:[self getImageNameForBaseModule:@"Conversation/Messages/SecretMediaIcon"] color:[UIColor whiteColor] backgroundColor:nil];
     CGFloat factor = self.flameIconSizeFactor;
     flameIcon = [GenerateImageUtils generateImg:CGSizeMake(flameIcon.size.width*factor, flameIcon.size.height*factor) contextGenerator:^(CGSize size, CGContextRef contextRef) {
         CGContextClearRect(contextRef, CGRectMake(0.0f, 0.0f, size.width, size.height));
         CGContextDrawImage(contextRef, CGRectMake(0.0f, 0.0f, size.width, size.height), flameIcon.CGImage);
     } opaque:NO];
    BOOL sparks = !keep;
   CGFloat beginTime = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 - (self.content.flameSecond - remainderFlame);
    CGFloat timeout = remainderFlame+(self.content.flameSecond - remainderFlame);
    if(self.content.flameSecond<=0 || keep) {
        beginTime = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970;
        timeout = remainderFlame;
    }
    __weak typeof(self) weakSelf = self;
    [self.flameNode transitionToStateWithIcon:flameIcon beginTime: beginTime timeout:timeout animated:YES synchronous:false sparks:sparks finished:^{
        [weakSelf stopFlameIfNeed];
        if(weakSelf.OnFlameFinished) {
            weakSelf.OnFlameFinished();
        }
        weakSelf.flameFinished = true;
        if(finished) {
            finished();
        }
    }];
}

-(void) stopFlameIfNeed {
    if(self.flameNode) {
        [self.flameNode animatePaused];
    }
}

-(UIImage*) getImageNameForBaseModule:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

-(NSString*) streamNo {
    return self.message.streamNo;
}

- (WKStreamFlag)streamFlag {
    return self.message.streamFlag;
}

- (NSMutableArray<WKStream *> *)streams {
    if(!self.message.streamOn) {
        return nil;
    }
    if(!self.streamLoadedFromDB) {
       NSArray<WKStream*> *streams  = [WKMessageDB.shared getStreams:self.message.streamNo];
        self.streamsInner = [NSMutableArray arrayWithArray:streams];
        self.streamLoadedFromDB = true;
    }
    if(!self.streamsInner) {
        self.streamsInner = [NSMutableArray array];
    }
    return self.streamsInner;
}

-(BOOL) streamOn {
    return self.message.streamOn;
}

- (void)dealloc {
    [self stopFlameIfNeed];

}


@end
