#import "NotificationCenterUtils.h"

#import "RuntimeUtils.h"
#import <UIKit/UIKit.h>

static NSMutableArray *notificationHandlers() {
    static NSMutableArray *array = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        array = [[NSMutableArray alloc] init];
    });
    return array;
}

@interface NSNotificationCenter (_a65afc19)

@end

@implementation NSNotificationCenter (_a65afc19)

- (void)_a65afc19_postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    if ([NSThread isMainThread]) {
        for (NotificationHandlerBlock handler in notificationHandlers())
        {
            if (handler(aName, anObject, aUserInfo, ^{
                [self _a65afc19_postNotificationName:aName object:anObject userInfo:aUserInfo];
            })) {
                return;
            }
        }
    }
    
    [self _a65afc19_postNotificationName:aName object:anObject userInfo:aUserInfo];
}

@end

@interface CATransaction (Swizzle)

+ (void)swizzle_flush;

@end

@implementation CATransaction (Swizzle)

+ (void)swizzle_flush {
    //printf("===flush\n");
    
    [self swizzle_flush];
}

@end

@implementation NotificationCenterUtils

// Disabled: 此 swizzle 唯一消费方 (TelegramUtils/Display/WindowContent 等)
// 整块未被实例化，swizzle 在每次 postNotificationName 上增加栈深度且无业务用途。
// 参见 CLAUDE.md "swizzle 白名单" 规则。
//+ (void)load {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        [RuntimeUtils swizzleInstanceMethodOfClass:[NSNotificationCenter class] currentSelector:@selector(postNotificationName:object:userInfo:) newSelector:@selector(_a65afc19_postNotificationName:object:userInfo:)];
//    });
//}

+ (void)addNotificationHandler:(NotificationHandlerBlock)handler {
    [notificationHandlers() addObject:[handler copy]];
}

@end
