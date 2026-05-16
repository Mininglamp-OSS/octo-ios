// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMultiplePanel.h
//  WuKongBase
//  多选面板
//  Created by tt on 2020/10/11.
//

#import <UIKit/UIKit.h>
@class WKMultiplePanel;
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKMultipActionNone,
    WKMultipActionDelete, // 删除
    WKMultipActionForward, // 逐条转发
    WKMultipActionMergeForward, // 合并转发
    
} WKMultipAction;

@protocol WKMultiplePanelDelegate <NSObject>

@optional


/// 多选面板行为
/// @param panel <#panel description#>
/// @param action <#action description#>
-(void) multiplePanel:(WKMultiplePanel*)panel action:(WKMultipAction)action;

@end

@interface WKMultiplePanel : UIView

@property(nonatomic,weak) id<WKMultiplePanelDelegate> delegate;

// 顶部"已选 N 条"计数显示。每次 selection 变化由 WKConversationView 调一次。
-(void) setSelectedCount:(NSInteger)count;

@end

NS_ASSUME_NONNULL_END
