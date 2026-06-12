//
//  OctoSummaryStatusPoller.m
//  OctoContext
//

#import "OctoSummaryStatusPoller.h"
#import "OctoSummaryAPI.h"

@interface OctoSummaryStatusPoller ()
@property(nonatomic, strong) NSArray<NSNumber *> *taskIds;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *lastStatus;
@property(nonatomic, strong) dispatch_source_t timer;
@property(nonatomic, assign) BOOL paused;
@end

@implementation OctoSummaryStatusPoller

- (instancetype)init {
    if ((self = [super init])) {
        _lastStatus = [NSMutableDictionary dictionary];
        _taskIds = @[];
    }
    return self;
}

- (void)setTaskIds:(NSArray<NSNumber *> *)taskIds {
    _taskIds = [taskIds copy] ?: @[];
}

- (void)start {
    [self stop];
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, 0), 5 * NSEC_PER_SEC, NSEC_PER_SEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.timer, ^{
        if (weakSelf.paused) return;
        [weakSelf tick];
    });
    dispatch_resume(self.timer);
}

- (void)pause  { self.paused = YES; }
- (void)resume { self.paused = NO; }
- (void)stop {
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
}

- (void)tick {
    if (self.taskIds.count == 0) return;
    __weak typeof(self) weakSelf = self;
    [[OctoSummaryAPI shared] batchStatus:self.taskIds callback:^(id _Nullable result, NSError * _Nullable error) {
        if (!weakSelf || error) return;
        NSArray<OctoBatchStatusItem *> *items = result;
        NSMutableDictionary<NSNumber *, OctoBatchStatusItem *> *changes = [NSMutableDictionary dictionary];
        for (OctoBatchStatusItem *it in items) {
            NSNumber *key = @(it.taskId);
            NSNumber *prev = weakSelf.lastStatus[key];
            if (!prev || prev.integerValue != it.status) {
                changes[key] = it;
                weakSelf.lastStatus[key] = @(it.status);
            }
        }
        if (changes.count > 0 && weakSelf.onUpdate) weakSelf.onUpdate(changes);
    }];
}

- (void)dealloc { [self stop]; }

@end
