//
//  WKForbiddenSpeakTimeSelectVC.h
//  WuKongBase
//
//  Created by tt on 2022/3/25.
//

#import <WuKongBase/WuKongBase.h>
#import "WKForbiddenSpeakTimeSelectVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKForbiddenSpeakTimeSelectVC : WKBaseTableVC<WKForbiddenSpeakTimeSelectVM*>

@property(nonatomic,copy) NSString *uid; // 禁言的用户uid
@property(nonatomic,strong) WKChannel *channel; // 用户所在频道


@end

NS_ASSUME_NONNULL_END
