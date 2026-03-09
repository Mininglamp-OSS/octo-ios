//
//  WKRobotManager.h
//  WuKongIMSDK
//
//  Created by tt on 2021/10/19.
//

#import <Foundation/Foundation.h>
#import "WKRobot.h"
NS_ASSUME_NONNULL_BEGIN

typedef void(^WKSyncRobotCallback)(NSArray<WKRobot*>* __nullable robots,NSError * __nullable error);
typedef void(^WKSyncRobotProvider)(NSArray<NSDictionary*> *robotVersionDicts,WKSyncRobotCallback callback);

@interface WKRobotManager : NSObject

+ (WKRobotManager *)shared;

/// 机器人数据提供者
@property(nonatomic,copy) WKSyncRobotProvider syncRobotProvider;

// 通过机器人id同步机器人
-(void) sync:(NSArray<NSString*>*)robotIDs complete:(void(^)(BOOL hasData,NSError *error))complete;

// 通过username同步机器人
-(void) syncWithUsernames:(NSArray<NSString*>*)usernames complete:(void(^)(BOOL hasData,NSError *error))complete;

/**
 获取机器人（通过username）
 @param username 机器人的用户名
 */
-(WKRobot*) getRobotWithUsername:(NSString*)username;

@end

NS_ASSUME_NONNULL_END
