//
//  OctoSummaryTipContent.m
//  OctoContext
//

#import "OctoSummaryTipContent.h"
#import <WuKongBase/WuKongBase.h>

@implementation OctoSummaryTipContent

+ (NSNumber *)contentType {
    return @(WK_TIP);
}

+ (instancetype)tipWithUid:(NSString *)uid name:(NSString *)name {
    OctoSummaryTipContent *c = [self new];
    c.content = @{
        @"content": @"{0}总结了群聊内容",
        @"extra": @[@{@"uid": uid ?: @"", @"name": name ?: @""}],
    };
    return c;
}

@end
