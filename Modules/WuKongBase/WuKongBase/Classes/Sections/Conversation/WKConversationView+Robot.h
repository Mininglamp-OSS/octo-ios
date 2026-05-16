// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKConversationView+Robot.h
//  WuKongBase
//
//  Created by tt on 2022/5/20.
//

#import "WKConversationView.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationView (Robot)

-(void) initRobot;

-(void) syncRobot:(NSArray<NSString*>*) robotIDs;

-(void) adjustRobotMenusIfNeed;

@end

NS_ASSUME_NONNULL_END
