//
//  WKLogicView.h
//  WuKongLogin
//
//  Created by tt on 2019/12/2.
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN

typedef void(^onLogin)(NSString*mobile,NSString*password,NSString *country);
@interface WKLoginView : UIView

@property(nonatomic,copy) onLogin onLogin;

@property(nonatomic,strong) NSString *country;
@property(nonatomic,strong) NSString *mobile;

- (void)viewConfigChange:(WKViewConfigChangeType)type;
@end

NS_ASSUME_NONNULL_END
