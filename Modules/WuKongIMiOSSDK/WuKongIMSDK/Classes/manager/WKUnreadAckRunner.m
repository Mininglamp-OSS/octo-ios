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
        // 即使本轮没 due, 也可能有 backoff 中的条目 —— 排个 timer.
        [self postDrainScheduleOrKick];
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
                // FIX(seq-aware): 只删 stored.last_read_seq <= seq 的 row.
                // 若 upload 在飞时 user 又往后读了一段(stored 被 enqueue 推高),
                // 保留 row 让下一轮 drain 用更新的 seq 顶上去, 不丢进度.
                [[WKUnreadAckQueueDB shared] markDone:channel ackedSeq:seq];
            }
            dispatch_group_leave(group);
        });
    }

    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.inFlight = NO;
        // FIX(auto-retry): drain 完后看队列状态:
        //   - 还有立即 due 的(包括 drain 期间被 markLocalRead 新 enqueue 的): 再跑一轮.
        //   - 只剩 backoff 中: dispatch_after 排个定时 kick.
        //   - 全空: 不调度.
        [self postDrainScheduleOrKick];
    });
}

-(void) postDrainScheduleOrKick {
    NSArray<WKUnreadAckEntry*> *moreDue = [[WKUnreadAckQueueDB shared] dueEntries];
    if (moreDue.count > 0) {
        // 期间又 enqueue 了新的(它们的 kick 撞 inFlight=YES 被跳过), 现在补跑.
        NSLog(@"[UnreadAck] postDrain: %lu more due, re-kick", (unsigned long)moreDue.count);
        [self kick];
        return;
    }
    NSTimeInterval next = [[WKUnreadAckQueueDB shared] earliestFutureRetryAt];
    if (next <= 0) {
        return;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval delta = next - now;
    if (delta < 0.5) delta = 0.5;     // 至少 500ms, 防忙环
    if (delta > 3600) delta = 3600;   // 1h cap, 与 backoff 表对齐
    NSLog(@"[UnreadAck] schedule next kick in %.0fs", delta);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delta * NSEC_PER_SEC)),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [weakSelf kick];
    });
}

@end
