//
//  WKModuleManager.m
//  WuKongBase
//
//  Created by tt on 2019/12/1.
//

#import "WKModuleManager.h"
#import "WKApp.h"
#import <WuKongBase/WuKongBase-Swift.h>
@interface WKModuleManager ()
@property(nonatomic,strong) NSMutableDictionary<NSString*,id<WKModuleProtocol>> *moduleMap;
@property(nonatomic,strong) NSLock *lock;
@property(nonatomic,strong) WKModuleContext *moduleContext;
@end

@implementation WKModuleManager

static WKModuleManager *_instance;


+ (id)allocWithZone:(NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
+ (WKModuleManager *)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        _instance.moduleMap = [NSMutableDictionary dictionary];
        _instance.lock = [[NSLock alloc] init];
        
    });
    return _instance;
}

-(void) registerModule:(id<WKModuleProtocol>) moduleProtocol{
    [self.lock lock];
    NSString *moduleId = [moduleProtocol moduleId];
    [self.moduleMap setObject:moduleProtocol forKey:moduleId];
    [self.lock unlock];
}

-(NSArray<id<WKModuleProtocol>>*) getAllModules {
    [self.lock lock];
    NSArray<id<WKModuleProtocol>>* objcModules = self.moduleMap.allValues;
    
    
    NSMutableArray *modules = [[NSMutableArray alloc] init];
    [modules addObjectsFromArray:objcModules];
    
    
    // 资源模块排到最前
   NSArray<id<WKModuleProtocol>> *newmodules = [modules sortedArrayUsingComparator:^NSComparisonResult(id<WKModuleProtocol>  _Nonnull obj1, id<WKModuleProtocol>  _Nonnull obj2) {
        
        if([obj1 moduleType] != WKModuleTypeResource && [obj2 moduleType] == WKModuleTypeResource) {
            return NSOrderedDescending;
        }
        
        if([obj1 moduleType] == WKModuleTypeResource && [obj2 moduleType] != WKModuleTypeResource) {
            return NSOrderedAscending;
        }
        
        if([obj2 moduleSort]>[obj1 moduleSort]) {
            return NSOrderedDescending;
        }
        
        return NSOrderedAscending;
    }];
    
    [self.lock unlock];
    return newmodules;
}

-(NSArray<id<WKModuleProtocol>>*) getResourceModules {
    NSMutableArray<id<WKModuleProtocol>> *resourceModules = [NSMutableArray array];
    NSArray<id<WKModuleProtocol>> *modules = [self getAllModules];
    if(modules && modules.count>0) {
        for (id<WKModuleProtocol> module in modules) {
            if([module moduleType] == WKModuleTypeResource) {
                [resourceModules addObject:module];
            }
        }
    }
    return resourceModules;
}

-(id<WKModuleProtocol>) getModuleWithId:(NSString*)moduleId{
    [self.lock lock];
    id<WKModuleProtocol> module = self.moduleMap[moduleId];
    [self.lock unlock];
    return module;
}

-(void) didModuleInit {
    NSArray<id<WKModuleProtocol>> *modules = [self getAllModules];
    if(modules&&modules.count>0) {
        for (id<WKModuleProtocol> module in modules) {
            // 模块初始化
            if([module respondsToSelector:@selector(moduleInit:)]) {
                [module moduleInit:self.moduleContext];
            }
            
        }
    }
    
}

-(WKModuleContext*) moduleContext {
    if(!_moduleContext) {
        _moduleContext = [WKModuleContext new];
    }
    return _moduleContext;
}

- (BOOL)didFinishLaunching{
    NSArray<id<WKModuleProtocol>> *modules = [self getAllModules];
    if(modules && modules.count>0) {
        for (id<WKModuleProtocol> module in modules) {
            if([module respondsToSelector:@selector(moduleDidFinishLaunching:)]) {
                [module moduleDidFinishLaunching:self.moduleContext];
            }
        }
    }
    return YES;
}

-(BOOL) didOpenURL:(NSURL*)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options{
    NSArray<id<WKModuleProtocol>> *modules = [self getAllModules];
    for (id<WKModuleProtocol> module in modules) {
        if([module respondsToSelector:@selector(moduleOpenURL:options:)]) {
            BOOL open = [module moduleOpenURL:url options:options];
            if(open) {
                return open;
            }
        }
    }
    return NO;
}

-(BOOL) didContinueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler {
    NSArray<id<WKModuleProtocol>> *modules = [self getAllModules];
    for (id<WKModuleProtocol> module in modules) {
        if([module respondsToSelector:@selector(didContinueUserActivity:restorationHandler:)]) {
            BOOL open = [module moduleContinueUserActivity:userActivity restorationHandler:restorationHandler];
            if(open) {
                return open;
            }
        }
    }
    return NO;
}


- (void)moduleDidReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    NSArray<id<WKModuleProtocol>> *modules = [self getAllModules];
    for (id<WKModuleProtocol> module in modules) {
        if([module respondsToSelector:@selector(moduleDidReceiveRemoteNotification:fetchCompletionHandler:)]) {
            [module moduleDidReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
        }
    }
}

-(void) didDatabaseLoad {
    NSArray<id<WKModuleProtocol>> *modules = [self getAllModules];
    for (id<WKModuleProtocol> module in modules) {
        if([module respondsToSelector:@selector(moduleDidDatabaseLoad:)]) {
            [module moduleDidDatabaseLoad:self.moduleContext];
        }
    }
}


@end
