//
//  WKUnreadAckRunner.m
//  WuKongIMSDK
//

#import "WKUnreadAckRunner.h"
#import "WKUnreadAckQueueDB.h"

@interface WKUnreadAckRunner ()
@property (atomic, assign) BOOL inFlight;
@property (nonatomic, copy, nullable) WKUnreadAckProvider uploadProvider;
@end

@implementation WKUnreadAckRunner

+ (instancetype) shared {
    static WKUnreadAckRunner *_inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _inst = [[self alloc] init];
    });
    return _inst;
}

-(void) setUploadProvider:(WKUnreadAckProvider)provider {
    _uploadProvider = [provider copy];
}

-(void) kick {
    if (!self.uploadProvider) {
        NSLog(@"[UnreadAck] kick: no uploadProvider set, skip");
        return;
    }
    if (self.inFlight) {
        NSLog(@"[UnreadAck] kick: already in flight, skip");
        return;
    }
    self.inFlight = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self drain];
    });
}

-(void) drain {
    NSArray<WKUnreadAckEntry*> *due = [[WKUnreadAckQueueDB shared] dueEntries];
    if (due.count == 0) {
        NSLog(@"[UnreadAck] drain: nothing due");
        self.inFlight = NO;
        return;
    }
    NSLog(@"[UnreadAck] drain: %lu due", (unsigned long)due.count);

    WKUnreadAckProvider provider = self.uploadProvider;
    dispatch_group_t group = dispatch_group_create();
    for (WKUnreadAckEntry *entry in due) {
        dispatch_group_enter(group);
        WKChannel *channel = entry.channel;
        uint32_t seq = entry.lastReadSeq;
        provider(channel, seq, ^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"[UnreadAck] upload FAIL channelId=%@ seq=%u err=%@",
                      channel.channelId, seq, error);
                [[WKUnreadAckQueueDB shared] markFailed:channel];
            } else {
                NSLog(@"[UnreadAck] upload OK channelId=%@ seq=%u", channel.channelId, seq);
                [[WKUnreadAckQueueDB shared] markDone:channel];
            }
            dispatch_group_leave(group);
        });
    }

    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.inFlight = NO;
    });
}

@end
