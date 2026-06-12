//
//  OctoSummaryDateFormat.m
//  OctoContext
//

#import "OctoSummaryDateFormat.h"
#import <WuKongBase/WuKongBase.h>

@implementation OctoSummaryDateFormat

+ (NSDate *)parseISO:(NSString *)iso {
    if (iso.length == 0) return nil;
    static NSISO8601DateFormatter *f1, *f2;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        f1 = [NSISO8601DateFormatter new];
        f1.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        f2 = [NSISO8601DateFormatter new];
        f2.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    NSDate *d = [f1 dateFromString:iso];
    if (!d) d = [f2 dateFromString:iso];
    if (!d) {
        // 后端有时返回 "yyyy-MM-dd HH:mm:ss"
        static NSDateFormatter *f3;
        if (!f3) {
            f3 = [NSDateFormatter new];
            f3.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            f3.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        }
        d = [f3 dateFromString:iso];
    }
    return d;
}

+ (NSString *)relativeFromISO:(NSString *)iso {
    NSDate *d = [self parseISO:iso];
    if (!d) return @"";
    NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:d];
    if (diff < 60)            return LLang(@"刚刚");
    if (diff < 60 * 60)       return [NSString stringWithFormat:LLang(@"%ld分钟前"), (long)(diff / 60)];
    if (diff < 60 * 60 * 24)  return [NSString stringWithFormat:LLang(@"%ld小时前"), (long)(diff / 3600)];
    if (diff < 60 * 60 * 24 * 7) return [NSString stringWithFormat:LLang(@"%ld天前"), (long)(diff / 86400)];
    return [self localFromISO:iso];
}

+ (NSString *)localFromISO:(NSString *)iso {
    NSDate *d = [self parseISO:iso];
    if (!d) return @"";
    static NSDateFormatter *out;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        out = [NSDateFormatter new];
        out.dateFormat = @"yyyy-MM-dd HH:mm";
    });
    return [out stringFromDate:d];
}

@end
