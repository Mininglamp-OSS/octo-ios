//
//  WKUserInfoVC.h
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import "WKBaseTableVC.h"
#import "WKUserInfoVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKUserInfoVC : WKBaseTableVC<WKUserInfoVM*>

@property(nonatomic,strong) NSString *uid; // 用户的唯一ID

@property(nonatomic,copy) NSString *vercode; // 加好友的验证码

@property(nonatomic,strong,nullable) WKChannel *fromChannel; // 从那个频道进入的用户信息页面

@end

@interface WKUserFieldView : UIView


-(instancetype) initWithField:(NSString*)field;

@property(nonatomic,copy) NSString *value;

@end

NS_ASSUME_NONNULL_END
