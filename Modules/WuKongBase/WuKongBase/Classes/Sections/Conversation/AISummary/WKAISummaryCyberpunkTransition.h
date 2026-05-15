//
//  WKAISummaryCyberpunkTransition.h
//  WuKongBase
//
//  AI 一键总结 → Bot 私聊的赛博朋克切场。
//
//  用法：先把 prompt 入队 send，然后调用本类，pushBlock 里执行真正的 pushConversation:。
//  动画总时长 0.65s；T=300ms 时回调 pushBlock 静默触发 nav push，到 T=650ms 时
//  overlay 已撤掉，用户落点已经是 Bot DM。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKAISummaryCyberpunkTransition : NSObject

/// @param sourceView 用于取截图与 window 的视图（通常是当前 chat VC.view）
/// @param pushBlock  在动画进行到 ~300ms 时被调用，期望执行 [WKApp pushConversation:]
+ (void)performFromView:(UIView *)sourceView
              pushBlock:(nullable void (^)(void))pushBlock;

@end

NS_ASSUME_NONNULL_END
