//
//  WKAllGroupListVM.h
//  WuKongContacts
//

#import <WuKongBase/WuKongBase.h>
#import "WKMyGroupListVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKAllGroupListVM : NSObject

/// 请求我的群组列表
-(AnyPromise*) requestGroups;

@end

NS_ASSUME_NONNULL_END
