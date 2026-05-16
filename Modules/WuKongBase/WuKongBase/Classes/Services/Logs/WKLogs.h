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
    #define WKLogInfo(fmt,...)  NSLog(fmt,##__VA_ARGS__)
    #define WKLogDebug(fmt,...)  NSLog(fmt,##__VA_ARGS__)
    //#define WKLogVerbose(fmt,...)  DDLogVerbose(fmt,##__VA_ARGS__)
    #define WKLogError(fmt,...)  NSLog(fmt,##__VA_ARGS__)
    #define WKLogWarn(fmt,...)  NSLog(fmt,##__VA_ARGS__)
#endif
