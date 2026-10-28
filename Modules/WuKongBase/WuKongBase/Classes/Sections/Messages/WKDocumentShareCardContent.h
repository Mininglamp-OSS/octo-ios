//
//  WKDocumentShareCardContent.h
//  WuKongBase
//
//  文档转发卡片（ContentType=18）。
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
@property(nonatomic,copy) NSString *documentURL;
@property(nonatomic,copy) NSString *permission;

@end

NS_ASSUME_NONNULL_END
