//
//  WKEndpointManager.m
//  WuKongCore
//
//  Created by tt on 2019/12/1.
//

#import "WKEndpointManager.h"
#import "WKConstant.h"
#import "WKApp.h"
@interface WKEndpointManager ()

@property(nonatomic,strong) NSMutableDictionary<NSString*,WKEndpoint*> *endpointIDDict;
@property(nonatomic,strong) NSMutableDictionary<NSString*,NSMutableArray<WKEndpoint*>*> *endpointCategoryDict;
@end
@implementation WKEndpointManager

-(instancetype) init {
    self = [super init];
    if(self) {
        self.endpointIDDict = [NSMutableDictionary dictionary];
        self.endpointCategoryDict = [NSMutableDictionary dictionary];
    }
    return self;
}


-(void) registerEndpoint:(WKEndpoint*)endpoint {
    if(endpoint.moduleID) {
        if( ![WKApp.shared.remoteConfig moduleOn:endpoint.moduleID]) {
            return; // 未开启的模块不进行注册
        }
    }
    [self.endpointIDDict setObject:endpoint forKey:endpoint.sid];
    if(endpoint.category && ![endpoint.category isEqualToString:@""]) {
       NSMutableArray<WKEndpoint*> *endpoints =  [self.endpointCategoryDict objectForKey:endpoint.category];
        if(!endpoints) {
            endpoints = [NSMutableArray array];
        }
        if(endpoints.count>0) {
            NSInteger existIndex = -1;
            for (NSInteger i=0;i<endpoints.count;i++) {
                WKEndpoint *endp = endpoints[i];
                if(endp.sid && [endp.sid isEqualToString:endpoint.sid]) {
                    existIndex = i;
                    break;
                }
            }
            if(existIndex!=-1) {
                [endpoints removeObjectAtIndex:existIndex];
            }
            
        }
        [endpoints addObject:endpoint];
        [self.endpointCategoryDict setObject:endpoints forKey:endpoint.category];
        
    }
}

-(void) unregisterEndpoint:(WKEndpoint*)endpoint {
    [self.endpointIDDict removeObjectForKey:endpoint.sid];
    if(endpoint.category && ![endpoint.category isEqualToString:@""]) {
        NSMutableArray<WKEndpoint*> *endpoints =  [self.endpointCategoryDict objectForKey:endpoint.category];
         if(!endpoints) {
             endpoints = [NSMutableArray array];
         }
        if(endpoints.count>0) {
            NSInteger existIndex = -1;
            for (NSInteger i=0;i<endpoints.count;i++) {
                WKEndpoint *endp = endpoints[i];
                if(endp.sid && [endp.sid isEqualToString:endpoint.sid]) {
                    existIndex = i;
                    break;
                }
            }
            if(existIndex!=-1) {
                [endpoints removeObjectAtIndex:existIndex];
            }
        }
        [self.endpointCategoryDict setObject:endpoints forKey:endpoint.category];
    }
}

-(void) unregisterEndpointWithCategory:(NSString*)category {
    NSMutableArray<WKEndpoint*> *endpoints =  [self.endpointCategoryDict objectForKey:category];
    if(endpoints && endpoints.count>0) {
        for (WKEndpoint *endpoint in endpoints) {
            [self.endpointIDDict removeObjectForKey:endpoint.sid];
        }
        [self.endpointCategoryDict removeObjectForKey:category];
    }
}

-(WKEndpoint*) getEndpointWithSid:(NSString*)sid {
    WKEndpoint *endpoint = self.endpointIDDict[sid];
    if(endpoint && endpoint.moduleID && ![WKApp.shared.remoteConfig moduleOn:endpoint.moduleID]) {
        return nil;
    }
    return endpoint;
}

-(NSArray<WKEndpoint*>*) getEndpointsWithCategory:(NSString*)category {
    NSArray *items = self.endpointCategoryDict[category];
    if(!items) {
        return nil;
    }
    items = [items sortedArrayUsingComparator:^NSComparisonResult(WKEndpoint*  _Nonnull obj1, WKEndpoint*  _Nonnull obj2) {
        if(!obj1.sort) {
            obj1.sort = @(0);
        }
        if(!obj2.sort) {
            obj2.sort = @(0);
        }
        if(obj1.sort.integerValue < obj2.sort.integerValue) {
           return NSOrderedDescending;
        }
        if(obj1.sort.integerValue == obj2.sort.integerValue) {
            return NSOrderedSame;
        }
        return NSOrderedAscending;
        
    }];
    
    NSMutableArray *newItems = [NSMutableArray array];
    if(items && items.count>0) {
        for (WKEndpoint *endpoint in items) {
            if(!endpoint.moduleID || [WKApp.shared.remoteConfig moduleOn:endpoint.moduleID]) {
                [newItems addObject:endpoint];
            }
        }
    }
    
    return newItems;
}

-(void) registerMergeForwardItem:(NSInteger)contentType cls:(Class)cls {
    
    [self registerEndpoint:[WKEndpoint initWithSid:[NSString stringWithFormat:@"%@.%ld",WKPOINT_CATEGORY_MERGEFORWARD_ITEM,contentType] handler:^id _Nullable(id  _Nonnull param) {
        
        return cls;
    }]];
    
}

-(Class) mergeForwardItem:(NSInteger)contentType {
   return [self invoke:[NSString stringWithFormat:@"%@.%ld",WKPOINT_CATEGORY_MERGEFORWARD_ITEM,contentType] param:nil];
}


-(NSArray*) invokes:(NSString*)category param:(id)param{
    NSArray<WKEndpoint*> *endpoints = [self getEndpointsWithCategory:category];
    if(endpoints) {
        NSMutableArray *items = [NSMutableArray array];
        for (WKEndpoint *endpoint in endpoints) {
            id obj = endpoint.handler(param);
            if(obj) {
                [items addObject:obj];
            }
        }
        return items;
    }
    return nil;
}

-(id) invoke:(NSString*)endpointSID param:(id)param{
   WKEndpoint *endpoint = [self getEndpointWithSid:endpointSID];
    if(endpoint) {
       return  endpoint.handler(param);
    }
    return nil;
}

- (void)pushUserInfoVC:(NSString*)uid vercode:(NSString*)vercode source:(WKChannel*)channel{
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    param[@"uid"] = uid?:@"";
    if(vercode) {
        param[@"vercode"] = vercode;
    }
    if(channel) {
        param[@"channel"] = channel;
    }
    [self invoke:WKPOINT_USER_INFO param:param];
}

- (void)pushUserInfoVC:(NSString*)uid vercode:(NSString*)vercode {
    
    [self pushUserInfoVC:uid vercode:vercode source:nil];
}

- (void)pushUserInfoVC:(NSString*)uid {
    
    [self pushUserInfoVC:uid vercode:nil];
}

@end
