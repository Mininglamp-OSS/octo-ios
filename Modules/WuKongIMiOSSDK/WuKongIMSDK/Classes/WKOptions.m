//
//  WKOptions.m
//  CocoaAsyncSocket
//
//  Created by tt on 2019/11/23.
//

#import "WKOptions.h"
#define WK_DB_Prefix @"wukongim_"

@implementation WKOptions

-(id) init {
   if (self = [super init]) {
       self.host = @"127.0.0.1";
       self.port = 6666;
       self.isDebug = true;
       self.heartbeatInterval = 60;
       self.enableMessageAttachUserInfo = true;
       self.messageRetryInterval = 10;
       self.messageRetryCount = 8;
       
       self.contentEditRetryInterval = 10;
       self.contentEditRetryCount = 8;
       
       self.reminderDoneUploadExpire = 60 * 60 * 24;
       self.reminderRetryInterval = 10;
       self.reminderRetryCount = 20;
       self.expireMsgCheckInterval = 10;
       self.expireMsgLimit = 50;
       
       
       self.offlineMessageLimit = 300;
       self.protoVersion = WKDefaultProtoVersion;
       self.proto = WK_PROTO_WK;
       self.messageFileRootDir =[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"files"];
       self.dbPrefix = WK_DB_Prefix;
       self.dbDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"wukongimdb"];
       self.imageMaxBytes =  1024 * 100; // 100k 缩略图最大大小
       self.syncChannelMessageLimit = 30;
       
       self.messageExtraSyncLimit = 100;
       
       self.receiptFlushInterval = 2;
       
       self.channelRequestMaxLimit = 10;
       
       self.sendFrequency = 100;
       self.sendMaxCountOfEach = 5;
   }
   return self;
}

-(BOOL) hasLogin {
    return self.connectInfo!=nil&&self.connectInfo.token&&![self.connectInfo.token isEqualToString:@""]&&self.connectInfo.uid&&![self.connectInfo.uid isEqualToString:@""];
}

@end
