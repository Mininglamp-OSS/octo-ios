//
//  OctoSummaryDateFormat.h
//  OctoContext
//
//  共享的日期 / 相对时间格式化工具。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OctoSummaryDateFormat : NSObject

/// ISO 8601 → "刚刚 / X 分钟前 / X 小时前 / X 天前 / yyyy-MM-dd"。nil/空 → @""。
+ (NSString *)relativeFromISO:(nullable NSString *)iso;

/// ISO 8601 → "yyyy-MM-dd HH:mm" 本地时区。
+ (NSString *)localFromISO:(nullable NSString *)iso;

@end

NS_ASSUME_NONNULL_END
