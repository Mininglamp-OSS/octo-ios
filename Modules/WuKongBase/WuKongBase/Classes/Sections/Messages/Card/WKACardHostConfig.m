//
//  WKACardHostConfig.m
//  WuKongBase
//

#import "WKACardHostConfig.h"

@implementation WKACardHostConfig

+ (ACOHostConfig *)hostConfigForDark:(BOOL)dark {
    static ACOHostConfig *lightConfig = nil;
    static ACOHostConfig *darkConfig = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lightConfig = [self buildConfigDark:NO];
        darkConfig = [self buildConfigDark:YES];
    });
    ACOHostConfig *cfg = dark ? darkConfig : lightConfig;
    if (!cfg) {
        // 兜底：解析失败时返回默认 config，保证渲染不崩
        cfg = [[ACOHostConfig alloc] init];
    }
    return cfg;
}

+ (ACOHostConfig *)buildConfigDark:(BOOL)dark {
    NSDictionary *json = [self hostConfigJSONDark:dark];
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    if (!data) {
        return [[ACOHostConfig alloc] init];
    }
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    ACOHostConfigParseResult *result = [ACOHostConfig fromJson:payload];
    if (result.isValid && result.config) {
        return result.config;
    }
    return [[ACOHostConfig alloc] init];
}

+ (NSDictionary *)hostConfigJSONDark:(BOOL)dark {
    NSString *fg   = dark ? @"#FFFFFF" : @"#1F1F1F";
    NSString *fgSub = dark ? @"#B0B0B0" : @"#6E6E6E";
    NSString *bgDefault  = dark ? @"#1C1C1E" : @"#FFFFFF";
    NSString *bgEmphasis = dark ? @"#2C2C2E" : @"#F5F5F5";
    NSString *sep = dark ? @"#3A3A3C" : @"#E5E5E5";
    NSString *accent = dark ? @"#5A5A5C" : @"#313131"; // [octo] 强调/正向按钮：app 主体灰黑色系(替系统蓝)；深色用中深灰保证在深色卡片上可见 + 白字对比

    NSDictionary *(^colorSet)(NSString *) = ^NSDictionary *(NSString *base) {
        return @{ @"default": @{ @"default": base, @"subtle": fgSub },
                  @"accent":  @{ @"default": accent, @"subtle": accent },
                  @"good":    @{ @"default": @"#2E7D32", @"subtle": @"#2E7D32" },
                  @"warning": @{ @"default": @"#ED6C02", @"subtle": @"#ED6C02" },
                  @"attention": @{ @"default": @"#D32F2F", @"subtle": @"#D32F2F" } };
    };

    return @{
        @"spacing": @{ @"small": @4, @"default": @8, @"medium": @12,
                       @"large": @16, @"extraLarge": @20, @"padding": @12 },
        @"separator": @{ @"lineThickness": @1, @"lineColor": sep },
        @"supportsInteractivity": @YES,
        @"fontFamily": @"-apple-system",
        @"fontSizes": @{ @"small": @12, @"default": @14, @"medium": @16,
                         @"large": @18, @"extraLarge": @22 },
        @"fontWeights": @{ @"lighter": @300, @"default": @400, @"bolder": @600 },
        @"imageSizes": @{ @"small": @40, @"medium": @80, @"large": @160 },
        @"containerStyles": @{
            @"default":  @{ @"backgroundColor": bgDefault,  @"foregroundColors": colorSet(fg) },
            @"emphasis": @{ @"backgroundColor": bgEmphasis, @"foregroundColors": colorSet(fg) },
            @"good":     @{ @"backgroundColor": bgDefault,  @"foregroundColors": colorSet(fg) },
            @"attention":@{ @"backgroundColor": bgDefault,  @"foregroundColors": colorSet(fg) },
            @"warning":  @{ @"backgroundColor": bgDefault,  @"foregroundColors": colorSet(fg) }
        },
        @"actions": @{
            @"maxActions": @6,
            @"spacing": @"default",
            @"buttonSpacing": @8,
            @"actionsOrientation": @"Horizontal",
            @"actionAlignment": @"Stretch",
            @"showCard": @{ @"actionMode": @"Inline", @"inlineTopMargin": @8 }
        },
        @"factSet": @{
            @"title": @{ @"color": @"default", @"size": @"default", @"weight": @"bolder", @"wrap": @YES },
            @"value": @{ @"color": @"default", @"size": @"default", @"weight": @"default", @"wrap": @YES },
            @"spacing": @8
        }
    };
}

@end
