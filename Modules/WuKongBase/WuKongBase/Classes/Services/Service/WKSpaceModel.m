//
//  WKSpaceModel.m
//  WuKongBase
//
//  Created by Claude on 2026/03/11.
//

#import "WKSpaceModel.h"
#import "WKApp.h"
#import "AFNetworking.h"

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
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        // 如果有缓存，先返回缓存
        if (self.cachedSpaces) {
            resolve(self.cachedSpaces);
        }

        // 发起网络请求
        NSString *url = [NSString stringWithFormat:@"%@/space/my", [WKApp shared].config.apiBaseUrl];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        // 设置token
        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        [manager GET:url parameters:nil headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if ([responseObject isKindOfClass:[NSArray class]]) {
                NSMutableArray *spaces = [NSMutableArray array];
                for (NSDictionary *dict in responseObject) {
                    WKSpaceEntity *space = (WKSpaceEntity *)[WKSpaceEntity fromMap:dict type:ModelMapTypeAPI];
                    [spaces addObject:space];
                }
                self.cachedSpaces = [spaces copy];
                resolve(self.cachedSpaces);
            } else {
                // 如果没有缓存，返回空数组
                if (!self.cachedSpaces) {
                    resolve(@[]);
                }
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            // 如果有缓存，失败时不报错，静默降级
            if (!self.cachedSpaces) {
                resolve(error);
            }
        }];
    }];
}

- (AnyPromise *)createSpaceWithName:(NSString *)name description:(NSString *)desc {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/create", [WKApp shared].config.apiBaseUrl];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        NSDictionary *params = @{
            @"name": name ?: @"",
            @"description": desc ?: @""
        };

        [manager POST:url parameters:params headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if ([responseObject isKindOfClass:[NSDictionary class]]) {
                WKSpaceEntity *space = (WKSpaceEntity *)[WKSpaceEntity fromMap:responseObject type:ModelMapTypeAPI];

                // 直接追加到缓存，无需重新请求
                if (self.cachedSpaces) {
                    NSMutableArray *newSpaces = [self.cachedSpaces mutableCopy];
                    [newSpaces addObject:space];
                    self.cachedSpaces = [newSpaces copy];
                }

                resolve(space);
            } else {
                resolve([NSError errorWithDomain:@"WKSpace" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid response"}]);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
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
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/%@/invite", [WKApp shared].config.apiBaseUrl, spaceId];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        [manager POST:url parameters:@{} headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if ([responseObject isKindOfClass:[NSDictionary class]]) {
                NSString *inviteCode = responseObject[@"invite_code"];
                resolve(inviteCode ?: @"");
            } else {
                resolve([NSError errorWithDomain:@"WKSpace" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid response"}]);
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
}

- (AnyPromise *)joinSpace:(NSString *)inviteCode {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        NSString *url = [NSString stringWithFormat:@"%@/space/join", [WKApp shared].config.apiBaseUrl];
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"token"];
        if (token) {
            [manager.requestSerializer setValue:token forHTTPHeaderField:@"token"];
        }

        NSDictionary *params = @{@"invite_code": inviteCode};

        [manager POST:url parameters:params headers:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [self invalidateCache]; // 加入后清除缓存
            resolve(responseObject);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            resolve(error);
        }];
    }];
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
