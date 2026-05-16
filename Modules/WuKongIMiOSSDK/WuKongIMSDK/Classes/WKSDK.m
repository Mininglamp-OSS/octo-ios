//
//  WKSDK.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/23.
//

#import "WKSDK.h"
#import "WKConnectionManager.h"
#import "WKConnectPacket.h"
#import "WKUnknownContent.h"
#import "WKMessageDB.h"
#import "WKSystemContent.h"
#import "WKCMDContent.h"
#import "WKTextContent.h"
#import "WKImageContent.h"
#import "WKVoiceContent.h"
@interface WKSDK()

@property(nonatomic,strong) NSMutableDictionary *messageContentDict;
@property(nonatomic,strong) NSLock *messageContentDictLock;

@property(nonatomic,copy) WKOfflineMessagePull offlineMessagePullInner;
@property(nonatomic,copy) WKOfflineMessageAck  offlineMessageAckInner;



@end

@implementation WKSDK

static WKSDK *_instance;


+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKSDK *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (NSMutableDictionary *)messageContentDict {
    if(!_messageContentDict) {
        _messageContentDict = [[NSMutableDictionary alloc] init];
        [_messageContentDict setObject:[WKTextContent class] forKey:[NSString stringWithFormat:@"%li",[WKTextContent contentType].longValue]];
        [_messageContentDict setObject:[WKImageContent class] forKey:[NSString stringWithFormat:@"%li",[WKImageContent contentType].longValue]];
        [_messageContentDict setObject:[WKVoiceContent class] forKey:[NSString stringWithFormat:@"%li",[WKVoiceContent contentType].longValue]];
        [_messageContentDict setObject:[WKCMDContent class] forKey:[NSString stringWithFormat:@"%li",[WKCMDContent contentType].longValue]];
        
    }
    return _messageContentDict;
}

- (NSLock *)messageContentDictLock {
    if(!_messageContentDictLock) {
        _messageContentDictLock = [[NSLock alloc] init];
    }
    return _messageContentDictLock;
}

- (WKOptions *)options {
    if(!_options) {
        _options = [[WKOptions alloc] init];
    }
    return _options;
}

- (void)setConnectURL:(NSString *)connectURL {
    _connectURL = connectURL;
    NSURL *connURL = [NSURL URLWithString:connectURL];
    self.options.host = [connURL host];
    NSLog(@"%@",[connURL port]);
    NSArray<NSString*> *connectArray =[connectURL componentsSeparatedByString:@":"];
    if(connectArray.count>=2) {
        self.options.port = [connectArray.lastObject intValue];
    }
    
    NSString *queryStr =  [connURL query];
    if(queryStr && ![queryStr isEqualToString:@""]) {
       NSArray<NSString*> *params = [queryStr componentsSeparatedByString:@"&"];
        if(params.count>0) {
            NSString *uid;
            NSString *token;
            NSString *name;
            NSString *avatar;
            for (NSString *param in params) {
                NSArray<NSString*> *keyValues = [param componentsSeparatedByString:@"="];
                if(keyValues.count==2) {
                   NSString *key = keyValues[0];
                   NSString *value = keyValues[1];
                    if([key isEqualToString:@"uid"]) {
                        uid = value;
                    }else if([key isEqualToString:@"token"]) {
                        token = value;
                    }else if([key isEqualToString:@"name"]) {
                        token = value;
                    }else if([key isEqualToString:@"avatar"]) {
                        token = value;
                    }
                }
            }
            if(uid && ![uid isEqualToString:@""] && token && ![token isEqualToString:@""]) {
                self.options.connectInfo = [WKConnectInfo initWithUID:uid token:token name:name avatar:avatar];
            }
        }
    }
}

-(WKConnectionManager*) connectionManager{
    if(!_connectionManager){
        _connectionManager =[WKConnectionManager sharedManager];
    }
    return _connectionManager;
}

-(WKChatManager*) chatManager{
    if(!_chatManager){
        _chatManager =[WKChatManager new];
    }
    return _chatManager;
}

-(WKConversationManager*) conversationManager {
    if(!_conversationManager) {
        _conversationManager = [WKConversationManager new];
    }
    return _conversationManager;
}

-(WKChannelManager*) channelManager{
    if(!_channelManager){
        _channelManager =[WKChannelManager new];
    }
    return _channelManager;
}

-(WKPakcetBodyCoderManager*) bodyCoderManager{
    if(!_bodyCoderManager){
        _bodyCoderManager =[WKPakcetBodyCoderManager new];
    }
    return _bodyCoderManager;
}

- (WKMediaManager *)mediaManager {
    return  [WKMediaManager shared];
}

- (WKCMDManager *)cmdManager {
    if(!_cmdManager) {
        _cmdManager = [WKCMDManager new];
    }
    return _cmdManager;
}

- (WKReceiptManager *)receiptManager {
    return  [WKReceiptManager shared];
}

- (WKReactionManager *)reactionManager {
    return [WKReactionManager shared];
}

- (WKRobotManager *)robotManager {
    return [WKRobotManager shared];
}

- (WKReminderManager *)reminderManager {
    return [WKReminderManager shared];
}

- (WKFlameManager *)flameManager {
    return [WKFlameManager shared];
}

- (WKPinnedMessageManager *)pinnedMessageManager {
    return WKPinnedMessageManager.shared;
}


-(WKCoder*) coder{
    if(!_coder){
        _coder =[WKCoder new];
    }
    return _coder;
}

-(BOOL) isDebug{
    return self.options.isDebug;
}

- (NSString *)sdkVersion {
    return @"1.0.0";
}


-(void) registerMessageContent:(Class)cls {
    if (cls && [cls respondsToSelector:@selector(contentType)]) {
        NSNumber *contentType = [cls contentType];
        [self registerMessageContent:cls contentType:contentType.integerValue];
    } else {
        NSLog(@"Error: Class does not respond to contentType or is nil");
    }
}

-(void) registerMessageContent:(Class)cls contentType:(NSInteger)contentType {
    [self.messageContentDictLock lock];
    [self.messageContentDict setObject:cls forKey:[NSString stringWithFormat:@"%li",contentType]];
    [self.messageContentDictLock unlock];
}

-(Class) getMessageContent:(NSInteger)contentType {
    [self.messageContentDictLock lock];
    Class cls =  [self.messageContentDict objectForKey:[NSString stringWithFormat:@"%li",contentType]];
    if(cls) {
        [self.messageContentDictLock unlock];
        return cls;
    }
    if([self isSystemMessage:contentType]) { // 系统消息
         [self.messageContentDictLock unlock];
        return [WKSystemContent class];
    }
    [self.messageContentDictLock unlock];
    return [WKUnknownContent class];
}

- (WKMessageFileUploadTask *)getMessageFileUploadTask:(WKMessage *)message {
    return [self.mediaManager.taskManager get:[NSString stringWithFormat:@"%u",message.clientSeq]];
}
-(WKMessageFileDownloadTask*) getMessageDownloadTask:(WKMessage*)message {
     return [self.mediaManager.taskManager get:[NSString stringWithFormat:@"%u",message.clientSeq]];
}

-(BOOL) isSystemMessage:(NSInteger)contentType {
    return contentType >= 1000 && contentType<=2000;
}

-(void) setOfflineMessageProvider:(WKOfflineMessagePull) offlineMessagePull offlineMessagesAck:(WKOfflineMessageAck) offlineMessageAckCallback {
    self.offlineMessagePullInner = offlineMessagePull;
    self.offlineMessageAckInner = offlineMessageAckCallback;
}

- (WKOfflineMessagePull)offlineMessagePull {
    return self.offlineMessagePullInner;
}
- (WKOfflineMessageAck)offlineMessageAck {
    return self.offlineMessageAckInner;
}

@end
