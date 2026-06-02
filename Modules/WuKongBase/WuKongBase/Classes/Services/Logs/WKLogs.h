//
//  ViewController.h
//  TalkClient3
//
//  Created by tt on 2018/9/3.
//  Copyright © 2018年 aiti. All rights reserved.
//
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <UIKit/UIKit.h>

// 日志等级
static  DDLogLevel ddLogLevel = DDLogLevelAll;

@interface WKLogsManager : NSObject

+(void) setup:(nullable NSString*)logsDirectory;

@end

#ifndef __OPTIMIZE__ // DEBUG模式
    #define WKLogInfo(fmt,...)  NSLog(fmt,##__VA_ARGS__)
    #define WKLogDebug(fmt,...)  NSLog(fmt,##__VA_ARGS__)
    //#define WKLogVerbose(fmt,...)  DDLogVerbose(fmt,##__VA_ARGS__)
    #define WKLogError(fmt,...)  NSLog(fmt,##__VA_ARGS__)
    #define WKLogWarn(fmt,...)  NSLog(fmt,##__VA_ARGS__)
#else
    // Release 下全部 no-op:
    // 主线程 NSLog 会经由 Bugly 的 LibLogRedirect 全局 os_unfair_lock 串行化,
    // 高频/大对象日志(如 WKAPIClient.logRequestEnd: 打整个 response)在并发完成回调里
    // 会把主线程卡到 >1s, 被 Bugly 抓成卡顿堆栈。release 包不需要这些调试日志。
    #define WKLogInfo(fmt,...)  ((void)0)
    #define WKLogDebug(fmt,...)  ((void)0)
    //#define WKLogVerbose(fmt,...)  DDLogVerbose(fmt,##__VA_ARGS__)
    #define WKLogError(fmt,...)  ((void)0)
    #define WKLogWarn(fmt,...)  ((void)0)
#endif
