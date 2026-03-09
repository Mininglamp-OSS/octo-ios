//
//  WKRobotManager.m
//  WuKongIMSDK
//
//  Created by tt on 2021/10/19.
//

#import "WKRobotManager.h"
#import "WKRobotDB.h"
@implementation WKRobotManager


static WKRobotManager *_instance;
+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKRobotManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}




-(void) sync:(NSArray<NSString*>*)robotIDs complete:(void(^)(BOOL hasData,NSError *error))complete{
    if(!self.syncRobotProvider) {
        NSLog(@"没有设置syncRobotProvider 忽略掉同步robot");
        return;
    }
    if(!robotIDs || robotIDs.count ==0) {
        return;
    }
    
    NSArray<WKRobot*> *robots = [[WKRobotDB shared] queryRobots:robotIDs];
    NSMutableArray *robotVersions = [NSMutableArray array];
    for (NSString *robotID in robotIDs) {
        BOOL hasRobot = false;
        if(robots && robots.count>0) {
            for (WKRobot *robot in robots) {
                if([robotID isEqualToString:robot.robotID]) {
                    hasRobot = true;
                    [robotVersions addObject:@{
                        @"version":@(robot.version),
                        @"robot_id": robotID,
                    }];
                    break;
                }
            }
        }
        if(!hasRobot) {
            [robotVersions addObject:@{
                @"version":@(0),
                @"robot_id": robotID,
            }];
        }
    }
    self.syncRobotProvider(robotVersions, ^(NSArray<WKRobot *> * _Nullable robots, NSError * _Nullable error) {
        if(error) {
            NSLog(@"同步机器人失败！->%@",error);
            if(complete) {
                complete(false,error);
            }
            return;
        }
        [[WKRobotDB shared] addOrUpdateRobots:robots];
        if(complete) {
            complete(robots && robots.count>0,nil);
        }
    });
}

-(void) syncWithUsernames:(NSArray<NSString*>*)usernames complete:(void(^)(BOOL hasData,NSError *error))complete {
    if(!self.syncRobotProvider) {
        NSLog(@"没有设置syncRobotProvider 忽略掉同步robot");
        return;
    }
    if(!usernames || usernames.count ==0) {
        return;
    }
    
    NSArray<WKRobot*> *robots = [[WKRobotDB shared] queryRobotsWithUsernames:usernames];
    NSMutableArray *robotVersions = [NSMutableArray array];
    for (NSString *username in usernames) {
        BOOL hasRobot = false;
        if(robots && robots.count>0) {
            for (WKRobot *robot in robots) {
                if([username isEqualToString:robot.username]) {
                    hasRobot = true;
                    [robotVersions addObject:@{
                        @"version":@(robot.version),
                        @"username": username,
                    }];
                    break;
                }
            }
        }
        if(!hasRobot) {
            [robotVersions addObject:@{
                @"version":@(0),
                @"username": username,
            }];
        }
    }
    self.syncRobotProvider(robotVersions, ^(NSArray<WKRobot *> * _Nullable robots, NSError * _Nullable error) {
        if(error) {
            NSLog(@"同步机器人失败！->%@",error);
            if(complete) {
                complete(false,error);
            }
            return;
        }
        [[WKRobotDB shared] addOrUpdateRobots:robots];
        if(complete) {
            complete(robots && robots.count>0,nil);
        }
    });
}

-(WKRobot*) getRobotWithUsername:(NSString*)username {
    return [[WKRobotDB shared] queryRobotWithUsername:username];
}

@end
