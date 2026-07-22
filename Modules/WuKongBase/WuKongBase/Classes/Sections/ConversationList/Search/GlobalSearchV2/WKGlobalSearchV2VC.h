//
//  WKGlobalSearchV2VC.h
//  WuKongBase
//
//  全局搜索（服务端 API 版，对齐 web）。外壳复刻会话内搜索 WKChannelHistorySearchVC 的
//  视觉/交互（搜索 pill、Tabbar、筛选 chip、离线条、空态、防抖）。
//  四个 tab：聊天记录(L1→L2) / 联系人 / 群组 / 文件。
//
//  灰度开关关闭时不会用到本类——入口工厂 WKGlobalSearchEntry 会回落到旧本地搜索栈。
//

#import "WKBaseVC.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WKGlobalSearchV2Tab) {
    WKGlobalSearchV2TabMessages = 0, // 聊天记录（L1 聚合总览）
    WKGlobalSearchV2TabContacts,     // 联系人
    WKGlobalSearchV2TabGroups,       // 群组
    WKGlobalSearchV2TabFiles,        // 文件
};

@interface WKGlobalSearchV2VC : WKBaseVC

/// 进入时默认选中的 tab（联系人入口传 Contacts）。
@property (nonatomic, assign) WKGlobalSearchV2Tab initialTab;
/// 进入时预填的关键词（可空）。
@property (nonatomic, copy, nullable) NSString *initialKeyword;

@end

NS_ASSUME_NONNULL_END
