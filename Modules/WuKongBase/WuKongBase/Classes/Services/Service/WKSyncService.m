//
//  WKSyncService.m
//  WuKongBase
//
//  Created by tt on 2019/12/7.
//

#import "WKSyncService.h"
#import "UIView+WKCommon.h"
#import "WKApp.h"
#import "WKConstant.h"
#import "WKSync.h"
@implementation WKSyncService

static WKSyncService *_instance = nil;
+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone ];
    });
    return _instance;
}

+(instancetype) shared{
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(void) sync {
    [self sync:nil];
}

- (void)sync:(void (^)(NSError *))callback {
    MBProgressHUD *hub = [[self rootViewController].view showHUDWithDim];
       hub.hidden = YES;
    
    // 创建一个 dispatch_group
       dispatch_group_t group = dispatch_group_create();
    
       dispatch_async(dispatch_get_global_queue(0, 0), ^{
           
           NSArray<id<WKSync>> *syncServices = [[WKApp shared] invokes:WKPOINT_CATEGORY_SYNC param:nil];
           if(syncServices) {
               for (id<WKSync> syncService in syncServices) {
                   if([syncService needSync]) {
                       
                       // 进入 dispatch_group
                       dispatch_group_enter(group);
                       
                       dispatch_async(dispatch_get_main_queue(), ^{
                           if(syncService.title) {
                               hub.hidden = NO;
                               hub.label.text = syncService.title;
                           }
                          
                       });
                       dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                           // 在主线程中更新 HUD
                           dispatch_async(dispatch_get_main_queue(), ^{
                               if (syncService.title) {
                                   hub.hidden = NO;
                                   hub.label.text = syncService.title;
                               }
                           });
                           [syncService sync:^(NSError *error) {
                               dispatch_group_leave(group);
                           }];
                       });
                      
                   }
               }
               // 在所有同步任务完成后执行隐藏 HUD 和回调
               dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                   [hub hideAnimated:YES];
                   if(callback) {
                       callback(nil);
                   }
               });
               
           }else {
               if(callback) {
                   callback(nil);
               }
           }
       });
}

-(void) syncContacts:(void (^)(NSError  * __nullable error))callback {
   id<WKSync> syncService = [WKApp.shared invoke:WKPOINT_SYNC_CONTACTS param:nil];
    if(syncService) {
        [syncService sync:callback];
    }
}

-(UIViewController*) rootViewController{
    return  [[UIApplication sharedApplication].delegate window].rootViewController;
}

@end
