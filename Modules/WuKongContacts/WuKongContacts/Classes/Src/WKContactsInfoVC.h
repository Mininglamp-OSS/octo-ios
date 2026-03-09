//
//  WKContactsInfoVC.h
//  WuKongContacts
// 联系人信息
//  Created by tt on 2019/12/31.
//

#import <Foundation/Foundation.h>
#import <WuKongBase/WuKongBase.h>
#import "WKContactsInfoVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKContactsInfoVC : WKBaseVC

@property(nonatomic,copy) NSString *uid; // 用户uid

@end

// 联系人信息头部
@interface WKContactsInfoHeader : UIView

-(void) refresh:(WKUserInfoResp*)model;

@end

// 联系人信息底部
@interface WKContactsInfoFooter : UIView

-(void) refresh:(WKUserInfoResp*)model;

@end

NS_ASSUME_NONNULL_END
