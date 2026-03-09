//
//  WKTimeTool.m
//  WuKongBase
//
//  Created by tt on 2019/12/26.
//

#import "WKTimeTool.h"

#import "WuKongBase.h"

@implementation WKTimeTool

+ (BOOL)is12HourFormat{
    NSString *formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containsA =[formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM =containsA.location != NSNotFound;
    return hasAMPM;
}

+(NSString*) formatTimeByAutoAMPM:(NSDate*)dt {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    // ----------设置你想要的格式,hh与HH的区别:分别表示12小时制,24小时制
    formatter.AMSymbol = LLang(@"上午");
    formatter.PMSymbol = LLang(@"下午");
    
    if([self is12HourFormat]) {
        NSString *lang = [WKApp shared].config.langue;
        if([lang isEqualToString:@"zh-Hans"]) {
            [formatter setDateFormat:@"aaa hh:mm"];
        }else{
            [formatter setDateFormat:@"hh:mm aaa"];
        }
        
    }else{
        [formatter setDateFormat:@"HH:mm"];
    }
    return [formatter stringFromDate:dt];;
}

+(NSString*) formatDateStyle1:(NSDate*)dt {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // 当前时间
    NSDate  *currentDate = [NSDate date];
    NSDateComponents *curComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday fromDate:currentDate];
    NSInteger currentYear=[curComponents year];
    NSInteger currentMonth=[curComponents month];
    NSInteger currentDay=[curComponents day];
    
    // 目标判断时间
    NSDateComponents *srcComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday fromDate:dt];
    NSInteger srcYear=[srcComponents year];
    NSInteger srcMonth=[srcComponents month];
    NSInteger srcDay=[srcComponents day];
    
    // 昨天（以“现在”的时候为基准-1天）
    NSDate *yesterdayDate = [NSDate date];
    yesterdayDate = [NSDate dateWithTimeInterval:-24*60*60 sinceDate:yesterdayDate];
    
    NSDateComponents *yesterdayComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:yesterdayDate];
    NSInteger yesterdayMonth=[yesterdayComponents month];
    NSInteger yesterdayDay=[yesterdayComponents day];
    
    NSString *ret = nil;
    if(currentYear==srcYear) {
        if(currentMonth==srcMonth && currentDay == srcDay) {
            return  LLang(@"今天");
        }else if(srcMonth == yesterdayMonth && srcDay == yesterdayDay) {
            return LLang(@"昨天");
        } else {
            long currentTimestamp = [WKTimeTool getIOSTimeStamp_l:currentDate];
            long srcTimestamp = [WKTimeTool getIOSTimeStamp_l:dt];
            
            // 相差时间（单位：秒）
            long delta = currentTimestamp - srcTimestamp;
            // 跟当前时间相差的小时数
            long deltaHour = (delta/3600);
            
            // 如果小于或等 7*24小时就显示星期几
            if (deltaHour <= 7*24){
                NSArray<NSString *> *weekdayAry = [NSArray arrayWithObjects:LLang(@"星期日"), LLang(@"星期一"), LLang(@"星期二"), LLang(@"星期三"), LLang(@"星期四"), LLang(@"星期五"),LLang(@"星期六"), nil];
                // 取出的星期数：1表示星期天，2表示星期一，3表示星期二。。。。 6表示星期五，7表示星期六
                NSInteger srcWeekday=[srcComponents weekday];
                
                // 取出当前是星期几
                NSString *weedayDesc = [weekdayAry objectAtIndex:(srcWeekday-1)];
                ret = [NSString stringWithFormat:@"%@", weedayDesc];
            }
            // 否则直接显示完整日期时间
            else {
                ret = [NSString stringWithFormat:@"%@", [WKTimeTool getTimeString:dt format:@"yyyy-MM-dd"]];
            }
                
        }
    }else {
        ret = [WKTimeTool getTimeString:dt format:@"yyyy-MM-dd"];
    }
    
    return  ret;
}

// 仿照微信的逻辑，显示一个人性化的时间字串
+ (NSString *)getTimeStringAutoShort2:(NSDate *)dt mustIncludeTime:(BOOL)includeTime{
    return [self getTimeStringAutoShort2:dt mustIncludeTime:includeTime containToday:NO];
}

+ (NSString *)getTimeStringAutoShort2:(NSDate *)dt mustIncludeTime:(BOOL)includeTime containToday:(BOOL)today{
    NSString *ret = nil;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // 当前时间
    NSDate  *currentDate = [NSDate date];
    NSDateComponents *curComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday fromDate:currentDate];
    NSInteger currentYear=[curComponents year];
    NSInteger currentMonth=[curComponents month];
    NSInteger currentDay=[curComponents day];
    
    // 目标判断时间
    NSDateComponents *srcComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday fromDate:dt];
    NSInteger srcYear=[srcComponents year];
    NSInteger srcMonth=[srcComponents month];
    NSInteger srcDay=[srcComponents day];
    
    // 要额外显示的时间分钟
    NSString *timeExtraStr = (includeTime?[WKTimeTool getTimeString:dt format:@" HH:mm"]:@"");
    
    // 当年
    if(currentYear == srcYear) {
        long currentTimestamp = [WKTimeTool getIOSTimeStamp_l:currentDate];
        long srcTimestamp = [WKTimeTool getIOSTimeStamp_l:dt];
        
        // 相差时间（单位：秒）
        long delta = currentTimestamp - srcTimestamp;
        
        // 当天（月份和日期一致才是）
        if(currentMonth == srcMonth && currentDay == srcDay) {
            // 时间相差60秒以内
            if(delta < 60)
                ret = LLang(@"刚刚");
            // 否则当天其它时间段的，直接显示“时:分”的形式
            else
                ret = [WKTimeTool getTimeString:dt format:[NSString stringWithFormat:@"%@ HH:mm",LLang(@"今天")]];
        }
        // 当年 && 当天之外的时间（即昨天及以前的时间）
        else {
            // 昨天（以“现在”的时候为基准-1天）
            NSDate *yesterdayDate = [NSDate date];
            yesterdayDate = [NSDate dateWithTimeInterval:-24*60*60 sinceDate:yesterdayDate];
            
            NSDateComponents *yesterdayComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:yesterdayDate];
            NSInteger yesterdayMonth=[yesterdayComponents month];
            NSInteger yesterdayDay=[yesterdayComponents day];
            
            // 前天（以“现在”的时候为基准-2天）
            NSDate *beforeYesterdayDate = [NSDate date];
            beforeYesterdayDate = [NSDate dateWithTimeInterval:-48*60*60 sinceDate:beforeYesterdayDate];
            
            NSDateComponents *beforeYesterdayComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:beforeYesterdayDate];
            NSInteger beforeYesterdayMonth=[beforeYesterdayComponents month];
            NSInteger beforeYesterdayDay=[beforeYesterdayComponents day];
            
            // 用目标日期的“月”和“天”跟上方计算出来的“昨天”进行比较，是最为准确的（如果用时间戳差值
            // 的形式，是不准确的，比如：现在时刻是2019年02月22日1:00、而srcDate是2019年02月21日23:00，
            // 这两者间只相差2小时，直接用“delta/3600” > 24小时来判断是否昨天，就完全是扯蛋的逻辑了）
            if(srcMonth == yesterdayMonth && srcDay == yesterdayDay)
                ret = [NSString stringWithFormat:LLang(@"昨天%@"), timeExtraStr];// -1d
            // “前天”判断逻辑同上
            else if(srcMonth == beforeYesterdayMonth && srcDay == beforeYesterdayDay)
                ret = [NSString stringWithFormat:LLang(@"前天%@"), timeExtraStr];// -2d
            else{
                // 跟当前时间相差的小时数
                long deltaHour = (delta/3600);
                
                // 如果小于或等 7*24小时就显示星期几
                if (deltaHour <= 7*24){
                    NSArray<NSString *> *weekdayAry = [NSArray arrayWithObjects:LLang(@"星期日"), LLang(@"星期一"), LLang(@"星期二"), LLang(@"星期三"), LLang(@"星期四"), LLang(@"星期五"),LLang(@"星期六"), nil];
                    // 取出的星期数：1表示星期天，2表示星期一，3表示星期二。。。。 6表示星期五，7表示星期六
                    NSInteger srcWeekday=[srcComponents weekday];
                    
                    // 取出当前是星期几
                    NSString *weedayDesc = [weekdayAry objectAtIndex:(srcWeekday-1)];
                    ret = [NSString stringWithFormat:@"%@%@", weedayDesc, timeExtraStr];
                }
                // 否则直接显示完整日期时间
                else
                    ret = [NSString stringWithFormat:@"%@%@", [WKTimeTool getTimeString:dt format:@"yyyy/M/d"], timeExtraStr];
            }
        }
    }
    // 往年
    else{
        ret = [NSString stringWithFormat:@"%@%@", [WKTimeTool getTimeString:dt format:@"yyyy/M/d"], timeExtraStr];
    }
    
    return ret;
}

+ (NSString *)getTimeString:(NSDate *)dt format:(NSString *)fmt{
    NSDateFormatter* format = [[NSDateFormatter alloc] init];
    [format setDateFormat:fmt];
    return [format stringFromDate:(dt==nil?[WKTimeTool getIOSDefaultDate]:dt)];
}

+ (NSTimeInterval) getIOSTimeStamp:(NSDate *)dat{
    NSTimeInterval a = [dat timeIntervalSince1970];
    return a;
}

+ (long) getIOSTimeStamp_l:(NSDate *)dat{
    return [[NSNumber numberWithDouble:[WKTimeTool getIOSTimeStamp:dat]] longValue];
}

+ (NSDate*)getIOSDefaultDate
{
    return [NSDate date];
}

+ (NSDate *)dateFromString:(NSString *)str {
    return [self dateFromString:str format:@"yyyy-MM-dd HH:mm:ss"];
}
+ (NSDate *)dateFromString:(NSString *)str format:(NSString *)fmt{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:fmt];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"Asia/Shanghai"]];
    NSDate *date = [formatter dateFromString:str];
    return date;
}



+(NSString*) formatCountdownTime:(NSInteger) countdownTime {
    NSInteger second = countdownTime - [[NSDate date] timeIntervalSince1970];
    if(second<=0) {
        return @"";
    }
    NSInteger day = 0;
    day = second/60/60/24;
    NSInteger hour = second/60/60%24;
    NSInteger minute = second/60%60;
    NSInteger bsecond = second%60;
    NSString *timeStr = @"";
    if(day>0) {
        timeStr = [NSString stringWithFormat:@"%ld天%ld时%ld分",(long)day,(long)hour,(long)minute];
    }else  {
        timeStr = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)hour,(long)minute,(long)bsecond];
    }
    return timeStr;
}
@end
