//
//  WKConversationListCell.h
//  WuKongBase
//
//  Created by tt on 2019/12/22.
//

#import <Foundation/Foundation.h>
#import "WKConversationWrapModel.h"
#import "SwipeTableCell.h"
NS_ASSUME_NONNULL_BEGIN


@interface WKConversationListCell : SwipeTableCell

-(void) refreshWithModel:(WKConversationWrapModel*)model;

/// 最近 tab 上下文：YES 时群聊也走 DM 风格渲染（显示 preview / 时间 / 不显示子区角标）。
/// 默认 NO（关注 tab 行为：群聊只显示头像 + 未读，preview 走 nested 子区行）。
/// 调用方在 refreshWithModel: 之前设置；reuse 时记得重新赋值。
@property(nonatomic,assign) BOOL recentTabContext;

/// 子区预览展开/折叠回调
@property(nonatomic,copy,nullable) void(^onToggleThreadPreview)(NSString *channelId);

@end

NS_ASSUME_NONNULL_END
