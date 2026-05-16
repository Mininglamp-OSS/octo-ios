// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKBotPlazaVM.m
//  WuKongContacts
//

#import "WKBotPlazaVM.h"

@implementation WKBotPlazaVM

- (AnyPromise *)requestBots {
    NSString *spaceId = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentSpaceId"];
    if (!spaceId || spaceId.length == 0) {
        return [AnyPromise promiseWithValue:@[]];
    }
    return [[WKAPIClient sharedClient] GET:@"robot/space_bots" parameters:@{@"space_id": spaceId} model:WKBotResp.class];
}

@end
