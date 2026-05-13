//
//  WKRealnamePrefetcher.h
//  WuKongBase
//
//  YUJ-381 / dmwork-web#1169 Phase A — 不依赖打开名片预拉取实名状态
//
//  问题：UserModel 加上了 realname_verified 解析后，person 缓存只在打开
//  WKUserInfoVC（loadPersonChannelInfo:）时才会被写入。群聊气泡 / 成员
//  列表 / 通讯录列表如果没人开过对方名片，person.extra[realname_verified]
//  仍是 nil，tri-state fallback 拿不到 @YES → 漏徽章。
//
//  方案：单独抽出来一个轻量预拉取器，命中 GET /users/<uid> 拿原始 dict，
//  把 realname_verified / realname_verified_at 写进 person 缓存，
//  channelInfoUpdate 回调会驱动 cell 自动刷新出徽章。
//
//  节流：每个 uid 在当前会话内只拉一次（NSMutableSet 去重），避免列表
//  滚动时反复触发。会话级即可，不持久化 —— App 重启后下一次 cell 渲染
//  自然会再拉一次。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 实名状态被 prefetcher 写回 person 缓存后会发这个通知。
/// userInfo: @{ @"uid": NSString, @"verified": NSNumber<BOOL> }
/// 监听端在收到通知后按 uid 局部刷新自己关心的 cell / view。
/// 该通知是「兜底」—— SDK 的 channelInfoUpdate delegate 是首选路径，但部分
/// 页面（比如群设置宫格 / 已脱离 ChannelManagerDelegate 链路的视图）拿不到，
/// 用这个广播补刷。
extern NSString *const WKRealnameVerifiedUpdatedNotification;

@interface WKRealnamePrefetcher : NSObject

/// 异步拉取指定 uid 的实名状态并写回 person 缓存。
///
/// 调用方在不打开名片的展示路径（聊天气泡 / 群成员列表 / 通讯录 cell /
/// 私聊 nav header 等）刷新时调用即可，自带去重。
///
/// 提前过滤：
///   - uid 为空 / 自己 / 已在节流集合 → 直接 return
///   - person 缓存里已经有 realname_verified 显式 @YES → 视作已 fetch 过
+ (void)ensureFetched:(NSString *)uid;

@end

NS_ASSUME_NONNULL_END
