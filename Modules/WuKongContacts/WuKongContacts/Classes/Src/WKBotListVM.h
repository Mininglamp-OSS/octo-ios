//
//  WKBotListVM.h
//  WuKongContacts
//

#import <WuKongBase/WuKongBase.h>
@class WKBotResp;
NS_ASSUME_NONNULL_BEGIN

@interface WKBotListVM : NSObject

/// 请求Bot列表
-(AnyPromise*) requestBots;

@end

@interface WKBotResp : WKModel

@property(nonatomic,copy) NSString *uid;
@property(nonatomic,copy) NSString *name;
@property(nonatomic,copy) NSString *desc;

@end

NS_ASSUME_NONNULL_END
