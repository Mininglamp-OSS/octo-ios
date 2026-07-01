//
//  WKChannelHistorySearchVC.h
//  WuKongBase
//
//  群聊 / 私聊 / 子区"查找聊天内容"页 — 纯 API，对齐 web ChannelSearchPanel。
//  入口位置：
//   - 群聊/私聊：WKConversationSettingVM 的 `channelsetting.hsitory` row
//   - 子区：    WKThreadSettingVC 的"查找聊天内容"row
//
//  说明：本 VC 不复用全局搜索栈（WKGlobalSearchResultController），与之独立运行。
//

#import "WKBaseVC.h"

@class WKChannel;

NS_ASSUME_NONNULL_BEGIN

@interface WKChannelHistorySearchVC : WKBaseVC

/// 必须在 push 前赋值。
@property (nonatomic, strong) WKChannel *channel;

@end

NS_ASSUME_NONNULL_END
