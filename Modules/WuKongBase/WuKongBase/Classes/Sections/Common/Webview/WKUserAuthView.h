//
//  WKUserAuthVC.h
//  WuKongBase
//
//  Created by tt on 2023/9/12.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKUserAuthView : UIView

@property(nonatomic,copy) NSString *appLogo;
@property(nonatomic,copy) NSString *appName;

@property(nonatomic,assign) BOOL show;

@property(nonatomic,copy) void(^onClose)(void);

@property(nonatomic,copy) void (^onAllow)(void);

@end

NS_ASSUME_NONNULL_END
