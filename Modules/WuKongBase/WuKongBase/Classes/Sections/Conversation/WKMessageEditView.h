//
//  WKMessageEditView.h
//  WuKongBase
//
//  Created by tt on 2022/4/15.
//

#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKMessageEditView : UIView

+(instancetype) message:(WKMessage*)message;

@property(nonatomic,copy) void(^onClose)(void);

@end

NS_ASSUME_NONNULL_END
