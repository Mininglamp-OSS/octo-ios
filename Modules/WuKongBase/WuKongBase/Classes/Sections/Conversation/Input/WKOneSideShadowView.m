//
//  WKOneSideShadowView.m
//  WuKongBase
//
//  Created by tt on 2021/11/3.
//

#import "WKOneSideShadowView.h"
#import "WuKongBase.h"
@interface WKOneSideShadowView ()



@end

@implementation WKOneSideShadowView

- (CALayer *)shadowProviderLayer {
    if(!_shadowProviderLayer) {
        _shadowProviderLayer = [[CALayer alloc] init];
    }
    return _shadowProviderLayer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        [self prepare];
    }
    return self;
}

-(void) prepare {
    [self.layer addSublayer:self.shadowProviderLayer];
    self.shadowProviderLayer.backgroundColor = [WKApp shared].config.themeColor.CGColor;
    self.shadowProviderLayer.shadowColor = [UIColor colorWithRed:195.0f/155.0f green:195.0f/155.0f blue:195.0f/155.0f alpha:1.0f].CGColor;
    self.shadowProviderLayer.shadowOpacity = 0.2f;
    self.shadowProviderLayer.shadowOffset = CGSizeMake(0.0f, 2.0f);
    self.shadowProviderLayer.shadowRadius = 5;
}

@end
