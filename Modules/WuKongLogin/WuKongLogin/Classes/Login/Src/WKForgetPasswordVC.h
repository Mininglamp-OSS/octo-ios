//
//  WKForgetPasswordVC.h
//  WuKongLogin
//
//  Created by tt on 2020/10/27.
//

#import <WuKongBase/WuKongBase.h>
#import "WKForgetPasswordVM.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKForgetPasswordVC : WKBaseVC<WKForgetPasswordVM*>

@property(nonatomic,strong) NSString *country;
@property(nonatomic,copy) NSString *mobile;


@end

NS_ASSUME_NONNULL_END
