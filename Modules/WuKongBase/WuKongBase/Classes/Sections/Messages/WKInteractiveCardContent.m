//
//  WKInteractiveCardContent.m
//  WuKongBase
//

#import "WKInteractiveCardContent.h"
#import "WuKongBase.h"

NSString *const WKCardProfileV1 = @"octo/v1";
NSString *const WKCardProfileV2 = @"octo/v2";
NSString *const WKCardMaxVersion = @"1.5";

@implementation WKInteractiveCardContent

+ (NSNumber *)contentType {
    return @(WK_INTERACTIVE_CARD);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cardSeq = -1;
    }
    return self;
}

- (void)decodeWithJSON:(NSDictionary *)contentDic {
    if (![contentDic isKindOfClass:[NSDictionary class]]) {
        return;
    }
    id card = contentDic[@"card"];
    self.card = [card isKindOfClass:[NSDictionary class]] ? card : nil;

    id plain = contentDic[@"plain"];
    self.plain = [plain isKindOfClass:[NSString class]] ? plain : nil;

    id profile = contentDic[@"profile"];
    self.profile = [profile isKindOfClass:[NSString class]] ? profile : WKCardProfileV1;

    id ver = contentDic[@"card_version"];
    self.cardVersion = [ver isKindOfClass:[NSString class]] ? ver : nil;

    // card_seq：容忍 int/int64/字符串数字；缺省 -1
    id seq = contentDic[@"card_seq"];
    if ([seq isKindOfClass:[NSNumber class]]) {
        self.cardSeq = [seq integerValue];
    } else if ([seq isKindOfClass:[NSString class]] && [(NSString *)seq length] > 0) {
        self.cardSeq = [(NSString *)seq integerValue];
    } else {
        self.cardSeq = -1;
    }

    id transient = contentDic[@"transient"];
    self.transient = [transient isKindOfClass:[NSNumber class]] ? [transient boolValue] : NO;
}

- (NSDictionary *)encodeWithJSON {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if (self.card) dict[@"card"] = self.card;
    dict[@"plain"] = self.plain ?: @"";
    dict[@"profile"] = self.profile ?: WKCardProfileV1;
    if (self.cardVersion) dict[@"card_version"] = self.cardVersion;
    if (self.cardSeq >= 0) dict[@"card_seq"] = @(self.cardSeq);
    if (self.transient) dict[@"transient"] = @(YES);
    return dict;
}

- (BOOL)isInteractiveProfile {
    return [self.profile isEqualToString:WKCardProfileV2];
}

- (BOOL)isForwardable {
    // 交互档不可转发（可能含 Input/Submit，转发后动作上下文失效且有伪造面）。
    return ![self isInteractiveProfile];
}

- (BOOL)isProfileSupported {
    // profile 必须在白名单内
    if (!([self.profile isEqualToString:WKCardProfileV1] ||
          [self.profile isEqualToString:WKCardProfileV2])) {
        return NO;
    }
    // card_version <= 1.5（简单按数值比较；缺省视为支持）
    if (self.cardVersion.length > 0) {
        if ([self.cardVersion compare:WKCardMaxVersion options:NSNumericSearch] == NSOrderedDescending) {
            return NO;
        }
    }
    return YES;
}

- (NSString *)renderFingerprint {
    NSString *cardJSON = @"";
    if ([self.card isKindOfClass:[NSDictionary class]]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:self.card
                                                      options:NSJSONWritingSortedKeys
                                                        error:nil];
        if (data) {
            cardJSON = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        }
    }
    return [NSString stringWithFormat:@"%@|%@", self.profile ?: @"", cardJSON];
}

- (NSString *)conversationDigest {
    if (self.plain.length > 0) {
        return self.plain;
    }
    return LLang(@"[卡片]");
}

- (NSString *)searchableWord {
    return self.plain ?: @"[卡片]";
}

@end
