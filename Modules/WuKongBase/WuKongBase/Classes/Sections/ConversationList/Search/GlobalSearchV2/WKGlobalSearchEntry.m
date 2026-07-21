//
//  WKGlobalSearchEntry.m
//  WuKongBase
//

#import "WKGlobalSearchEntry.h"
#import "WKGlobalSearchFeatureFlag.h"
#import "WKGlobalSearchV2VC.h"
#import "WKGlobalSearchResultController.h"

@implementation WKGlobalSearchEntry

+ (UIViewController *)controllerWithSearchType:(WKHistoryMessageSearchType)type
                                       keyword:(nullable NSString *)keyword {
    if ([WKGlobalSearchFeatureFlag apiEnabled]) {
        WKGlobalSearchV2VC *vc = [WKGlobalSearchV2VC new];
        vc.initialTab = [self v2TabFromSearchType:type];
        vc.initialKeyword = keyword;
        return vc;
    }
    WKGlobalSearchResultController *vc = [WKGlobalSearchResultController new];
    vc.searchType = type;
    if (keyword.length > 0) vc.keyword = keyword;
    return vc;
}

+ (WKGlobalSearchV2Tab)v2TabFromSearchType:(WKHistoryMessageSearchType)type {
    switch (type) {
        case WKHistoryMessageSearchTypeContacts: return WKGlobalSearchV2TabContacts;
        case WKHistoryMessageSearchTypeMessages:  return WKGlobalSearchV2TabMessages;
        default:                                  return WKGlobalSearchV2TabMessages; // All/Conversation → 聊天记录
    }
}

@end
