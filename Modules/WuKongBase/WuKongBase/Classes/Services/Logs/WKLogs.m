//
//  ViewController.m
//  TalkClient3
//
//  Created by tt on 2018/9/3.
//  Copyright © 2018年 aiti. All rights reserved.
//
#import <CocoaLumberjack/CocoaLumberjack.h>
#import "WKLogs.h"
#import <WuKongIMSDK/WuKongIMSDK.h>



@implementation WKLogsManager

+(void) setup:(nullable NSString*)logsDirectory{

   // [DDLog addLogger:[DDASLLogger sharedInstance]]; // ASL = Apple System Logs
    if (@available(iOS 10.0, *)) {
        [DDLog addLogger:[DDOSLogger sharedInstance]];
    } else {
        [DDLog addLogger:[DDTTYLogger sharedInstance]]; // TTY = Xcode console
    }
    DDFileLogger *fileLogger; // File Logger
    if (logsDirectory) {
        logsDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"limlogs"];
        [WKFileUtil createDirectoryIfNotExist:logsDirectory];
    }
    fileLogger = [[DDFileLogger alloc] initWithLogFileManager:[[DDLogFileManagerDefault alloc] initWithLogsDirectory:logsDirectory]];
   
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles =4; // 日志文件最大数量
    [DDLog addLogger:fileLogger];

}

@end
