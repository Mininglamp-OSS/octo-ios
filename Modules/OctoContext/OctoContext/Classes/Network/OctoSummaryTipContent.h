//
//  OctoSummaryTipContent.h
//  OctoContext
//
//  对齐 octo-web packages/dmworkbase/src/Messages/SummaryNotify/tip.ts (SummaryTipContent)。
//  复用 WuKongIM 系统号段 WK_TIP(2000), 群内其他端 (Web/Android) 通过通用
//  WKSystemContent/SystemContent 的 {0} 占位符替换机制自动渲染, 不需要为这个
//  类型单独写接收端解析代码。这个 content 类只用于"发送"这一侧。
//

#import <WuKongIMSDK/WuKongIMSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryTipContent : WKSystemContent

/// content = {"content": "{0}总结了群聊内容", "extra": [{"uid": uid, "name": name}]}。
/// 中文模板与 web 端锁定一致, 不做本地化 (LLang), 保证各端展示文案完全相同。
+ (instancetype)tipWithUid:(NSString *)uid name:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
