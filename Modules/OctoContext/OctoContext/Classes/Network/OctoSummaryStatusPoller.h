//
//  OctoSummaryStatusPoller.h
//  OctoContext
//
//  对应 dmworksummary/src/hooks/useSummaryList.ts 的轮询: 列表里挑出非终态
//  task,每 5s 调一次 batch-status,变更后局部回调让 VC 刷新对应 cell。
//

#import <Foundation/Foundation.h>
#import "OctoSummaryModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryStatusPoller : NSObject

/// 持有的 task ids 集合 (NSNumber wrapping int64_t).每次 update 列表后重置。
- (void)setTaskIds:(NSArray<NSNumber *> *)taskIds;

/// status 变化回调: dict 形如 @{ @<taskId> : OctoBatchStatusItem }。
@property(nonatomic, copy, nullable) void (^onUpdate)(NSDictionary<NSNumber *, OctoBatchStatusItem *> *changes);

- (void)start;   // 立即开始,5s 周期
- (void)pause;
- (void)resume;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
