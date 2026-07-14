//
//  WKStickerLocalOrderStore.h
//  WuKongBase
//
//  「我的表情」本地顺序持久化：后端目前无 reorder API，只有 PUT sticker/user/front
//  能置顶。用户在「我的表情」tab 里拖动到中间位置的排序，本地 NSUserDefaults 保留
//  path 顺序数组；下次 reload 时把后端列表按本地 order merge 出稳定顺序。
//
//  拖到首位那次会同步调 PUT sticker/user/front，让后端也跟上（多端只在首位一致）。
//

#import <Foundation/Foundation.h>

@class WKSticker;

NS_ASSUME_NONNULL_BEGIN

@interface WKStickerLocalOrderStore : NSObject

+ (instancetype)shared;

// 保存当前 uid 的 path 顺序数组
- (void)saveOrder:(NSArray<NSString *> *)paths forUID:(NSString *)uid;

// 读取当前 uid 的 path 顺序（未存过则返回 nil）
- (nullable NSArray<NSString *> *)loadOrderForUID:(NSString *)uid;

// 清掉指定 uid 的本地 order（登出/账号切换）
- (void)clearForUID:(NSString *)uid;

// 把后端列表 serverList 按本地 order merge 成稳定顺序：
//   1. 服务端 list 里、本地 order 不含的 path（新增/收藏进来的），按 server 原序
//      **插到最前面** —— 用户添加/收藏新表情后期望它立即出现在首位，与 web 直觉一致
//   2. 之后按本地 order 追加（用户拖拽过的顺序保留下来）
//   3. 本地 order 里但 serverList 已不存在的（服务端已删除），过滤掉，并回写清理后的 order
//   4. 本地 order 为空 / uid 为空 → 直接返回 serverList
- (NSArray<WKSticker *> *)mergeServerList:(NSArray<WKSticker *> *)serverList
                                   forUID:(nullable NSString *)uid;

@end

NS_ASSUME_NONNULL_END
