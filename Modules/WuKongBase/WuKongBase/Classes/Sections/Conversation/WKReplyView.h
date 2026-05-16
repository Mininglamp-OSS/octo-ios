//
//  WKReplyView.h
//  WuKongBase
//
//  Created by tt on 2020/10/20.
//

#import <UIKit/UIKit.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKReplyView : UIView

+(instancetype) message:(WKMessage*)message;

@property(nonatomic,copy) void(^onClose)(void);

@end

NS_ASSUME_NONNULL_END
