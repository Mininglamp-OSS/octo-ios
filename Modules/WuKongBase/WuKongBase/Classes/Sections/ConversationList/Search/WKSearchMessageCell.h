// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSearchMessageCell.h
//  WuKongBase
//
//  Created by tt on 2020/5/10.
//

#import "WKFormItemCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSearchMessageModel : WKFormItemModel

@property(nonatomic,strong) WKChannel *channel; // 显示的频道
@property(nonatomic,strong) NSNumber *messageCount; // 消息数量
@property(nonatomic,copy) NSString *content;
@property(nonatomic,copy) NSString *keyword;
@property(nonatomic,assign) NSInteger timestamp; // 消息时间

// 搜索结果外部群/发送者 `@SpaceName` 后缀，viewer-relative 判定。
// 字段契约与 WKExternalExtrasKey* 对齐。消息搜索场景优先使用 message 级 from_*
// 字段（sender 的 home_space），缺失时回退到 channel 级（会话所属 home_space）。
// 全部字段可选，缺失时等同于非外部，保留旧行为。
@property(nonatomic,copy,nullable) NSString *home_space_id;
@property(nonatomic,copy,nullable) NSString *home_space_name;
@property(nonatomic,strong,nullable) NSNumber *is_external; // legacy 降级路径
@property(nonatomic,copy,nullable) NSString *source_space_name; // legacy 降级路径


@end

@interface WKSearchMessageCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
