//
//  WKGlobalContactsVM.m
//  WuKongBase
//

#import "WKGlobalContactsVM.h"
#import "WKGlobalSearchV2API.h"
#import "WKChannelHistorySearchKeywordUtil.h"
#import "WKSearchContactsCell.h"
#import "WKApp.h"
#import "WKAvatarUtil.h"
#import "WKConstant.h"
#import <WuKongIMSDK/WuKongIMSDK.h>

/// 类型安全取字符串：服务端字段可能为 NSNull / 非字符串，`?:` 挡不住 NSNull，
/// 后续 -length 会 unrecognized selector 崩溃。与本 PR 其它解析层同款防御。
static NSString *WKGCS_String(id _Nullable v) {
    if ([v isKindOfClass:[NSString class]]) return (NSString *)v;
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber *)v stringValue];
    return @"";
}


@interface WKGlobalContactsVM ()
@property (nonatomic, copy, readwrite) NSString *keyword;
@property (nonatomic, copy, readwrite) NSArray<WKSearchContactsModel *> *friendModels;
@property (nonatomic, copy, readwrite) NSArray<WKSearchContactsModel *> *groupModels;
@property (nonatomic, assign, readwrite) BOOL isLoading;
@property (nonatomic, copy, readwrite, nullable) NSError *error;
@property (nonatomic, assign, readwrite) BOOL queryStarted;

@property (nonatomic, assign) NSInteger reqIdCounter;
@property (nonatomic, assign) NSInteger activeReqId;
@end

@implementation WKGlobalContactsVM

- (instancetype)init {
    self = [super init];
    if (self) {
        _keyword = @"";
        _friendModels = @[];
        _groupModels = @[];
    }
    return self;
}

- (BOOL)shouldRunSearch {
    return self.keyword.length > 0; // 联系人/群组按名字搜，需非空 keyword
}

- (void)applyKeyword:(nullable NSString *)keyword {
    BOOL truncated = NO;
    NSString *cleaned = [WKChannelHistorySearchKeywordUtil truncateToDefault:keyword ?: @"" didTruncate:&truncated];
    if (truncated && [self.delegate respondsToSelector:@selector(globalContactsVMKeywordExceedLimit:)]) {
        [self.delegate globalContactsVMKeywordExceedLimit:self];
    }
    if ([cleaned isEqualToString:self.keyword]) return;
    self.keyword = cleaned;
    [self refresh];
}

- (void)refresh {
    [self cancelInFlight];
    self.friendModels = @[];
    self.groupModels = @[];
    self.error = nil;

    if (![self shouldRunSearch]) {
        self.isLoading = NO;
        self.queryStarted = NO;
        [self notifyState];
        return;
    }

    self.queryStarted = YES;
    self.isLoading = YES;
    [self notifyState];

    self.reqIdCounter += 1;
    NSInteger reqId = self.reqIdCounter;
    self.activeReqId = reqId;

    __weak typeof(self) ws = self;
    [WKGlobalSearchV2API searchContactsAndGroupsWithKeyword:self.keyword page:1]
        .then(^(id result) {
            __strong typeof(ws) ss = ws;
            if (!ss || ss.activeReqId != reqId) return;
            ss.activeReqId = 0;
            ss.isLoading = NO;
            NSDictionary *dict = [result isKindOfClass:[NSDictionary class]] ? result : @{};
            ss.friendModels = [ss modelsFromArray:dict[@"friends"] isGroup:NO];
            ss.groupModels = [ss modelsFromArray:dict[@"groups"] isGroup:YES];
            ss.error = nil;
            [ss notifyState];
        })
        .catch(^(NSError *error) {
            __strong typeof(ws) ss = ws;
            if (!ss || ss.activeReqId != reqId) return;
            ss.activeReqId = 0;
            ss.isLoading = NO;
            ss.error = error;
            [ss notifyState];
        });
}

- (void)cancelInFlight {
    self.activeReqId = 0;
    self.isLoading = NO;
}

#pragma mark - 映射（与 WKGlobalSearchVM.handleSearchResult 同口径）

- (NSArray<WKSearchContactsModel *> *)modelsFromArray:(id)raw isGroup:(BOOL)isGroup {
    NSArray *arr = [raw isKindOfClass:[NSArray class]] ? raw : nil;
    if (arr.count == 0) return @[];
    NSString *kw = self.keyword;
    NSMutableArray<WKSearchContactsModel *> *models = [NSMutableArray array];
    for (NSDictionary *item in arr) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSString *remark = WKGCS_String(item[@"channel_remark"]);
        NSString *rawName = WKGCS_String(item[@"channel_name"]);
        NSString *name = (remark.length > 0) ? [self stripHTMLTags:remark] : [self stripHTMLTags:rawName];
        NSString *cid = WKGCS_String(item[@"channel_id"]);

        WKSearchContactsModel *m = [WKSearchContactsModel new];
        m.name = name ?: @"";
        m.keyword = kw ?: @"";
        m.avatar = isGroup ? [WKAvatarUtil getGroupAvatar:cid] : [WKAvatarUtil getAvatar:cid];
        m.showBottomLine = @(NO);
        m.showTopLine = @(NO);
        [self applyExternalFieldsTo:m from:item];
        if (isGroup) {
            m.onClick = ^(WKFormItemModel *model, NSIndexPath *indexPath) {
                [[WKApp shared] pushConversation:[WKChannel groupWithChannelID:cid]];
            };
        } else {
            m.onClick = ^(WKFormItemModel *model, NSIndexPath *indexPath) {
                [[WKApp shared] invoke:WKPOINT_USER_INFO param:@{ @"uid": cid }];
            };
        }
        [models addObject:m];
    }
    return models;
}

- (NSString *)stripHTMLTags:(NSString *)html {
    if (!html || html.length == 0) return html ?: @"";
    static NSRegularExpression *regex = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
    });
    return [regex stringByReplacingMatchesInString:html options:0 range:NSMakeRange(0, html.length) withTemplate:@""];
}

- (void)applyExternalFieldsTo:(WKSearchContactsModel *)m from:(NSDictionary *)raw {
    if (!m || !raw) return;
    id homeId   = raw[@"home_space_id"];
    id homeName = raw[@"home_space_name"];
    id isExt    = raw[@"is_external"];
    id srcName  = raw[@"source_space_name"];
    if ([homeId isKindOfClass:[NSString class]]) m.home_space_id = homeId;
    if ([homeName isKindOfClass:[NSString class]]) m.home_space_name = homeName;
    if ([isExt isKindOfClass:[NSNumber class]]) m.is_external = isExt;
    if ([srcName isKindOfClass:[NSString class]]) m.source_space_name = srcName;
}

- (void)notifyState {
    if ([self.delegate respondsToSelector:@selector(globalContactsVMDidChangeState:)]) {
        [self.delegate globalContactsVMDidChangeState:self];
    }
}

@end
