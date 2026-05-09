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

- (void)cancelCurrentEffect;

/// 气泡物理并发锁。炸弹特效启用气泡物理前检查，若为 YES 就跳过气泡物理（仍播放粒子）。
/// 避免多个炸弹同时 snapshot + hide 同一批 cell 造成气泡错乱。
@property (nonatomic, assign) BOOL bubblePhysicsActive;

@end

NS_ASSUME_NONNULL_END
