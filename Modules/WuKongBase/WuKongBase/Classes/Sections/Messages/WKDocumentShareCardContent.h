//
//  WKDocumentShareCardContent.h
//  WuKongBase
//
//  文档转发卡片（ContentType=18），与 octo-web DocumentShareCardContent 对齐。
//

#import <WuKongIMSDK/WuKongIMSDK.h>
#import "WKConstant.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKDocumentShareCardContent : WKMessageContent

@property(nonatomic,copy) NSString *docId;
@property(nonatomic,copy) NSString *kind;
@property(nonatomic,copy) NSString *title;
@property(nonatomic,copy) NSString *ownerName;
@property(nonatomic,copy) NSString *updatedAt;
/// 保留 wire 字段以兼容跨端序列化；导航时不信任此 URL，而由 docId 重建同源地址。
@property(nonatomic,copy) NSString *documentURL;
@property(nonatomic,copy) NSString *permission;

@end

NS_ASSUME_NONNULL_END
