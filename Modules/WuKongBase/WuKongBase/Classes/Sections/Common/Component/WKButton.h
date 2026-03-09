//
//  WKButton.h
//  WuKongBase
//
//  Created by tt on 2019/12/2.
//

#import <UIKit/UIKit.h>
typedef enum : NSUInteger {
    WKButtonStyleDefault,
} WKButtonStyle;

NS_ASSUME_NONNULL_BEGIN

@interface WKButton : UIButton
-(instancetype) initWithStyle:(WKButtonStyle)style;
@end

NS_ASSUME_NONNULL_END
