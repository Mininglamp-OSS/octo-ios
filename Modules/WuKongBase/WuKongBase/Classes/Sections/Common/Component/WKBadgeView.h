//
//  WKBadgeView.h
//  WuKongBase
//
//  Created by tt on 2020/1/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKBadgeView : UIView

@property (strong) UIColor *badgeBackgroundColor;
@property (nonatomic, copy) NSString *badgeValue;

+ (instancetype)viewWithBadgeTip:(NSString *)badgeValue;
+ (instancetype)viewWithoutBadgeTip;

@end

NS_ASSUME_NONNULL_END
