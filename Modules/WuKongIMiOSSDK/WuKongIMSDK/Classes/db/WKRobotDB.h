//
//  WKRobotDB.h
//  WuKongIMSDK
//
//  Created by tt on 2021/10/19.
//

#import <Foundation/Foundation.h>
#import "WKRobot.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKRobotDB : NSObject

+ (WKRobotDB *)shared;

/// 查询robot
-(NSArray<WKRobot*>*) queryRobots:(NSArray<NSString*>*)robotIDs;

-(void) addOrUpdateRobots:(NSArray<WKRobot*>*)robots;

-(WKRobot*) queryRobotWithUsername:(NSString*)username;

-(NSArray<WKRobot*>*) queryRobotsWithUsernames:(NSArray<NSString*>*)usernames;


@end

NS_ASSUME_NONNULL_END
