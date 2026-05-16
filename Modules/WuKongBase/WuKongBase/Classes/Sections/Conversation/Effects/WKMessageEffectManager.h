// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKMessageEffectManager.h
//  WuKongBase

#import <UIKit/UIKit.h>
@class WKMessageModel;

NS_ASSUME_NONNULL_BEGIN

@interface WKMessageEffectManager : NSObject

+ (instancetype)shared;

/// 检测消息是否触发特效（命中 💣 / 👍 等），返回特效类型，nil 表示无
- (nullable NSString *)effectTypeForMessage:(WKMessageModel *)message;

/// 某条消息是否已经触发过特效（避免 cell 重用或重新显示时再次触发）
- (BOOL)hasTriggeredForMessage:(WKMessageModel *)message;

/// 标记消息已触发
- (void)markTriggeredForMessage:(WKMessageModel *)message;

- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect;

/// 带发送者头像的触发接口（rocketLaunch 等会用 avatarImage 渲染舷窗内头像）
- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect
          avatarImage:(nullable UIImage *)avatarImage;

/// 群聊火箭特效的完整接口:avatarImage = 群头像(最终舷窗显示),
/// memberAvatars = 群成员头像列表(非空 → 触发能量汇聚动画)
- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect
          avatarImage:(nullable UIImage *)avatarImage
        memberAvatars:(nullable NSArray<UIImage *> *)memberAvatars;

/// 群聊 + fromSelf 组合(目前 classy 效果用 fromSelf 决定手臂方向)
- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect
          avatarImage:(nullable UIImage *)avatarImage
        memberAvatars:(nullable NSArray<UIImage *> *)memberAvatars
             fromSelf:(BOOL)fromSelf;

/// 带方向信息的触发接口：classy 特效需要知道消息是不是自己发的，
/// 决定手臂从气泡哪一侧伸出（self=左，other=右）。
- (void)triggerEffect:(NSString *)effectType
           inHostView:(UIView *)hostView
           sourceRect:(CGRect)sourceRect
          avatarImage:(nullable UIImage *)avatarImage
             fromSelf:(BOOL)fromSelf;

- (void)cancelCurrentEffect;

/// 气泡物理并发锁。炸弹特效启用气泡物理前检查，若为 YES 就跳过气泡物理（仍播放粒子）。
/// 避免多个炸弹同时 snapshot + hide 同一批 cell 造成气泡错乱。
@property (nonatomic, assign) BOOL bubblePhysicsActive;

@end

NS_ASSUME_NONNULL_END
