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
    // decodeWithJSON: 而不是直接赋值 content —— displayContent 只在 decodeWithJSON: 里算,
    // 而 WKSystemMessageCell 用 displayContent 算气泡尺寸。发送路径 (contentToMessage →
    // encode) 从来不会走 decodeWithJSON:, 不手动调这一下, 本机回显那条气泡就会因为
    // displayContent == nil 塌陷成 (10, 10) 的空气泡。
    [c decodeWithJSON:@{
        @"content": @"{0}总结了群聊内容",
        @"extra": @[@{@"uid": uid ?: @"", @"name": name ?: @""}],
    }];
    return c;
}

@end
