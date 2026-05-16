//
//  WKPartyEffect.h
//  WuKongBase

#import <UIKit/UIKit.h>
@class WKMessageEffectView;

NS_ASSUME_NONNULL_BEGIN

@interface WKPartyEffect : NSObject

+ (void)playInView:(WKMessageEffectView *)effectView sourceRect:(CGRect)sourceRect;

@end

NS_ASSUME_NONNULL_END
