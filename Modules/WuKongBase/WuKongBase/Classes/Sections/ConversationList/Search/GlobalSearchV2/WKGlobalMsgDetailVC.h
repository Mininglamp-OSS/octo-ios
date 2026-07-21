//
//  WKGlobalMsgDetailVC.h
//  WuKongBase
//
//  全局搜索「聊天记录」L1 点某桶后进入的 L2 详情页：该会话内命中消息扁平流。
//  UI 复用会话内搜索的消息/文件 cell + 高亮 + 定位跳转。
//

#import "WKBaseVC.h"
#import "WKGlobalSearchModels.h"
#import "WKChannelHistorySearchModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKGlobalMsgDetailVC : WKBaseVC

/// push 前必须赋值。
@property (nonatomic, strong) WKGlobalSearchGroupBucket *bucket;
@property (nonatomic, copy, nullable) NSString *keyword;
@property (nonatomic, copy, nullable) WKChannelHistorySearchFilter *filter;

@end

NS_ASSUME_NONNULL_END
