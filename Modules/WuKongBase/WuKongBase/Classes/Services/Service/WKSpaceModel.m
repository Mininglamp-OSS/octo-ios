// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKSpaceModel.m
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpaceModel.h"
#import "WKApp.h"
#import "WKAPIClient.h"
#import <PromiseKit/PromiseKit.h>

@interface WKSpaceModel()

@property(nonatomic,strong) NSArray<WKSpaceEntity *> *cachedSpaces;

@end

@implementation WKSpaceModel

+ (instancetype)shared {
    static WKSpaceModel *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WKSpaceModel alloc] init];
    });
    return instance;
}

- (void)invalidateCache {
    self.cachedSpaces = nil;
}

- (AnyPromise *)getMySpaces {
    // 如果有缓存，先返回缓存
    if (self.cachedSpaces) {
        return [AnyPromise promiseWithValue:self.cachedSpaces];
    }

    // 使用WKAPIClient统一接口（参考Web端实现）
    return [[WKAPIClient sharedClient] GET:@"space/my" parameters:nil].then(^id(id responseObject) {
        if ([responseObject isKindOfClass:[NSArray class]]) {
            NSMutableArray *spaces = [NSMutableArray array];
            for (NSDictionary *dict in responseObject) {
                if ([dict isKindOfClass:[NSDictionary class]]) {
                    WKSpaceEntity *space = (WKSpaceEntity *)[WKSpaceEntity fromMap:dict type:ModelMapTypeAPI];
                    if (space) {  // ⚠️ 重要：检查space是否为nil
                        [spaces addObject:space];
                    } else {
                        NSLog(@"⚠️ 解析Space失败，跳过: %@", dict);
                    }
                }
            }
            self.cachedSpaces = [spaces copy];
            NSLog(@"✅ 成功解析%lu个Space", (unsigned long)spaces.count);
            return (id)self.cachedSpaces;
        } else {
            // 返回空数组
            return (id)@[];
        }
    }).catch(^id(NSError *error) {
        NSLog(@"❌ getMySpaces失败: %@", error);
        // 失败时返回空数组
        if (self.cachedSpaces) {
            return (id)self.cachedSpaces;
        }
        // 抛出错误
        @throw error;
    });
}

- (AnyPromise *)createSpaceWithName:(NSString *)name description:(NSString *)desc {
    return [[WKAPIClient sharedClient] POST:@"space/create" parameters:@{
        @"name": name ?: @"",
        @"description": desc ?: @""
    }].then(^(id responseObject) {
        WKSpaceEntity *space = (WKSpaceEntity *)[WKSpaceEntity fromMap:responseObject type:ModelMapTypeAPI];

        // 直接追加到缓存，无需重新请求
        if (self.cachedSpaces) {
            NSMutableArray *newSpaces = [self.cachedSpaces mutableCopy];
            [newSpaces addObject:space];
            self.cachedSpaces = [newSpaces copy];
        }

        return space;
    });
}

- (AnyPromise *)getSpaceDetail:(NSString *)spaceId {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/%@", [WKApp shared].config.apiBaseUrl, spaceId];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        [manager GET:url parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if ([responseObject isKindOfClass:[NSDictionary class]]) {
                WKSpaceEntity *space = (WKSpaceEntity *)[WKSpaceEntity fromMap:responseObject type:ModelMapTypeAPI];
                resolve(space);
            } else {
                resolve([NSError errorWithDomain:@"WKSpace" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid response"}]);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
}

- (AnyPromise *)getMembers:(NSString *)spaceId {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/%@/members", [WKApp shared].config.apiBaseUrl, spaceId];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        [manager GET:url parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if ([responseObject isKindOfClass:[NSArray class]]) {
                NSMutableArray *members = [NSMutableArray array];
                for (NSDictionary *dict in responseObject) {
                    WKSpaceMember *member = (WKSpaceMember *)[WKSpaceMember fromMap:dict type:ModelMapTypeAPI];
                    [members addObject:member];
                }
                resolve([members copy]);
            } else {
                resolve(@[]);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
}

- (AnyPromise *)createInvite:(NSString *)spaceId {
    NSString *path = [NSString stringWithFormat:@"space/%@/invite", spaceId];
    return [[WKAPIClient sharedClient] POST:path parameters:nil].then(^id(id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            NSString *inviteCode = responseObject[@"invite_code"];
            return inviteCode ?: @"";
        }
        return @"";
    });
}

- (AnyPromise *)joinSpace:(NSString *)inviteCode {
    return [[WKAPIClient sharedClient] POST:@"space/join" parameters:@{@"invite_code": inviteCode}].then(^(id result) {
        [self invalidateCache]; // 加入后清除缓存
        return result;
    });
}

- (AnyPromise *)leaveSpace:(NSString *)spaceId {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/%@/leave", [WKApp shared].config.apiBaseUrl, spaceId];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        [manager POST:url parameters:@{} headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [self invalidateCache]; // 离开后清除缓存
            resolve(responseObject);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
}

- (AnyPromise *)disbandSpace:(NSString *)spaceId {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/%@", [WKApp shared].config.apiBaseUrl, spaceId];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        [manager DELETE:url parameters:nil headers:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [self invalidateCache]; // 解散后清除缓存
            resolve(responseObject);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
}

- (AnyPromise *)removeMembers:(NSString *)spaceId uids:(NSArray<NSString *> *)uids {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/%@/members/remove", [WKApp shared].config.apiBaseUrl, spaceId];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        NSDictionary *params = @{@"uids": uids};

        [manager POST:url parameters:params headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            resolve(responseObject);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
}

- (AnyPromise *)changeMemberRole:(NSString *)spaceId uid:(NSString *)uid role:(NSInteger)role {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/%@/members/%@/role", [WKApp shared].config.apiBaseUrl, spaceId, uid];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        NSDictionary *params = @{@"role": @(role)};

        [manager PUT:url parameters:params headers:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            resolve(responseObject);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
}

@end
