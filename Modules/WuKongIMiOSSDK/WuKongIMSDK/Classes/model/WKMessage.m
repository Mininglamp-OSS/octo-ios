//
//  WKMessage.m
//  WuKongIMSDK
//
//  Created by tt on 2019/11/27.
//

#import "WKMessage.h"
#import "WKChannelManager.h"
#import "WKMemoryCache.h"
#import "WKSDK.h"
#import "WKMessageDB.h"

@implementation WKMessageHeader

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.showUnread = false;
    }
    return self;
}

- (BOOL)noPersist {
    return _noPersist;
}

@end

@interface WKMessage ()
@property(nonatomic,assign) NSInteger contentTypeInner;
@property(nonatomic,strong) NSMutableArray<WKStream*> *streamsInner;
@end

@implementation WKMessage

- (WKMessageHeader *)header {
    if(!_header) {
        _header = [WKMessageHeader new];
    }
    return _header;
}
- (WKSetting *)setting {
    if(!_setting) {
        _setting = [WKSetting new];
    }
    return  _setting;
}

- (void)setContent:(WKMessageContent *)content {
    _content = content;
    _content.message = self;
}

-(WKChannelInfo*) channelInfo {
    return [[WKChannelManager shared] getChannelInfo:self.channel];
}

- (WKChannelInfo *)from {
    if(!_from) {
        _from = [[WKChannelManager shared] getChannelInfo:[[WKChannel alloc] initWith:self.fromUid channelType:WK_PERSON]];
    }
     return _from;
}

- (WKChannelMember *)memberOfFrom {
   
    return [[WKChannelManager shared] getMember:self.channel uid:self.fromUid];
}
- (BOOL)isSend {
    if(!self.fromUid || [self.fromUid isEqualToString:@""] || [self.fromUid isEqualToString:[WKSDK shared].options.connectInfo.uid]) {
        return true;
    }
    return false;
}

- (id<WKTaskProto>)task {
    return [[WKSDK shared].mediaManager.taskManager get:[NSString stringWithFormat:@"%u",self.clientSeq]];
}

- (NSMutableDictionary *)extra {
    if(!_extra) {
        _extra = [[NSMutableDictionary alloc] init];
    }
    return _extra;
}

- (WKMessageExtra *)remoteExtra {
    if(!_remoteExtra) {
        _remoteExtra = [[WKMessageExtra alloc] init];
    }
    return _remoteExtra;
}

- (NSInteger)contentType {
    if(_contentTypeInner !=0) {
        return _contentTypeInner;
    }
    return self.content.realContentType;
}

- (BOOL)streamOn {
    if(self.streamNo && ![self.streamNo isEqualToString:@""]) {
        return true;
    }
    return false;
}

- (void)setContentType:(NSInteger)contentType {
    _contentTypeInner = contentType;
}

-(BOOL) isEqual:(id)obj{
    if(self == obj) {
        return YES;
    }
    WKMessage *cm = (WKMessage*)obj;
    if(self.messageId == cm.messageId) {
        return YES;
    }
    
    return NO;
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%llu",self.messageId] hash];
}




@end

@interface WKChannelMemberCache : NSObject

@end
