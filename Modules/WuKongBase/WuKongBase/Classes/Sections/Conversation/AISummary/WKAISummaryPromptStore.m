// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
//
//  WKAISummaryPromptStore.m
//  WuKongBase
//

#import "WKAISummaryPromptStore.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

static NSString * const kStoreKey       = @"WKAISummary.channelSettings";
static NSString * const kKeyCustom      = @"customPrompt";
static NSString * const kKeyLastRange   = @"lastRange";

@implementation WKAISummaryPromptStore

#pragma mark - Helpers

+ (NSString *)channelKey:(WKChannel *)channel {
    if (!channel || channel.channelId.length == 0) return nil;
    return [NSString stringWithFormat:@"%d_%@", (int)channel.channelType, channel.channelId];
}

+ (NSDictionary *)rootDict {
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kStoreKey];
    return d ?: @{};
}

+ (void)mutateChannelEntry:(WKChannel *)channel
                     block:(void (^)(NSMutableDictionary *entry))block {
    NSString *ck = [self channelKey:channel];
    if (!ck) return;
    NSMutableDictionary *root = [[self rootDict] mutableCopy];
    NSMutableDictionary *entry = [(root[ck] ?: @{}) mutableCopy];
    block(entry);
    if (entry.count == 0) {
        [root removeObjectForKey:ck];
    } else {
        root[ck] = entry;
    }
    [[NSUserDefaults standardUserDefaults] setObject:root forKey:kStoreKey];
}

+ (NSDictionary *)channelEntry:(WKChannel *)channel {
    NSString *ck = [self channelKey:channel];
    if (!ck) return @{};
    return [self rootDict][ck] ?: @{};
}

#pragma mark - Custom prompt

+ (NSString *)customPromptForChannel:(WKChannel *)channel {
    NSString *p = [self channelEntry:channel][kKeyCustom];
    if (![p isKindOfClass:NSString.class]) return nil;
    NSString *t = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return t.length > 0 ? p : nil;
}

+ (void)saveCustomPrompt:(NSString *)prompt forChannel:(WKChannel *)channel {
    NSString *clean = [(prompt ?: @"") stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self mutateChannelEntry:channel block:^(NSMutableDictionary *entry) {
        if (clean.length == 0) {
            [entry removeObjectForKey:kKeyCustom];
        } else {
            entry[kKeyCustom] = prompt; // 保留原始（含两端空白），避免下次编辑被裁
        }
    }];
}

+ (BOOL)hasCustomPromptForChannel:(WKChannel *)channel {
    return [self customPromptForChannel:channel].length > 0;
}

#pragma mark - Last range

+ (NSInteger)lastRangeForChannel:(WKChannel *)channel {
    NSNumber *n = [self channelEntry:channel][kKeyLastRange];
    if (![n isKindOfClass:NSNumber.class]) return 0;
    return n.integerValue;
}

+ (void)saveLastRange:(NSInteger)range forChannel:(WKChannel *)channel {
    [self mutateChannelEntry:channel block:^(NSMutableDictionary *entry) {
        entry[kKeyLastRange] = @(range);
    }];
}

@end
