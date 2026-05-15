//
//  WKAIBotMotionDriver.m
//  WuKongBase
//

#import "WKAIBotMotionDriver.h"
#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase-Swift.h>

static NSString * const kKVOKey = @"contentOffset";
static const NSTimeInterval kStartDebounce = 0.08;
static const NSTimeInterval kStopDebounce  = 0.25;

@interface WKAIBotMotionDriver ()
@property(nonatomic, weak)   WKAIBotRiveView *bot;
@property(nonatomic, weak)   UIScrollView    *scrollView;
@property(nonatomic, assign) BOOL    attached;
@property(nonatomic, assign) BOOL    walking;
@property(nonatomic, assign) BOOL    startScheduled;
@property(nonatomic, assign) NSInteger stopGen;     // 用于取消上一次 stop 的 dispatch_after
@property(nonatomic, assign) CGFloat lastOffsetY;
@end

@implementation WKAIBotMotionDriver

- (instancetype)initWithBot:(WKAIBotRiveView *)bot scrollView:(UIScrollView *)scrollView {
    if ((self = [super init])) {
        _bot = bot;
        _scrollView = scrollView;
        _lastOffsetY = scrollView.contentOffset.y;
    }
    return self;
}

- (void)dealloc {
    [self detach];
}

- (void)attach {
    if (self.attached) return;
    UIScrollView *sv = self.scrollView;
    if (!sv) return;
    [sv addObserver:self forKeyPath:kKVOKey options:NSKeyValueObservingOptionNew context:nil];
    self.attached = YES;
}

- (void)detach {
    if (!self.attached) return;
    self.attached = NO;
    @try { [self.scrollView removeObserver:self forKeyPath:kKVOKey]; } @catch (__unused id e) {}
    self.stopGen++; // 让在飞的 stop 任务作废
    if (self.walking) {
        [self.bot stopWalk];
        self.walking = NO;
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if (![keyPath isEqualToString:kKVOKey]) return;
    if (!self.attached) return;

    CGPoint o = [change[NSKeyValueChangeNewKey] CGPointValue];
    CGFloat dy = o.y - self.lastOffsetY;
    self.lastOffsetY = o.y;
    if (fabs(dy) < 0.5) return; // 微抖动忽略

    [self bumpStopTimer];

    if (!self.walking && !self.startScheduled) {
        self.startScheduled = YES;
        __weak typeof(self) ws = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kStartDebounce * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(ws) ss = ws;
            if (!ss) return;
            ss.startScheduled = NO;
            if (!ss.attached || ss.walking) return;
            [ss.bot walk];
            ss.walking = YES;
        });
    }
}

#pragma mark - Stop debounce

- (void)bumpStopTimer {
    self.stopGen++;
    NSInteger gen = self.stopGen;
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kStopDebounce * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(ws) ss = ws;
        if (!ss) return;
        if (ss.stopGen != gen) return; // 期间又有新滚动，作废
        if (!ss.walking) return;
        [ss.bot stopWalk];
        ss.walking = NO;
    });
}

@end
