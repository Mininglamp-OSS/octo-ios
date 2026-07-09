//
//  WKChannelHistorySearchKeywordUtil.h
//  WuKongBase
//
//  关键词工具：按 composed character sequence 截断到 64，避免在 emoji/组合字中间斩断。
//  与 web 端 truncateChannelSearchKeyword(value, 64) 同口径。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger WKChannelHistorySearchKeywordMaxRunes;

@interface WKChannelHistorySearchKeywordUtil : NSObject

/// 按 composed grapheme 计数。
+ (NSInteger)runeCount:(nullable NSString *)keyword;

/// 截断到 maxRunes 个 grapheme。didTruncate 输出是否发生截断。
+ (NSString *)truncate:(nullable NSString *)keyword
              maxRunes:(NSInteger)maxRunes
           didTruncate:(BOOL * _Nullable)didTruncate;

/// 默认上限版本（64）。
+ (NSString *)truncateToDefault:(nullable NSString *)keyword
                    didTruncate:(BOOL * _Nullable)didTruncate;

@end

NS_ASSUME_NONNULL_END
