//
//  WKTopShadowView.m
//  WuKongBase
//
//  Created by tt on 2021/11/3.
//

#import "WKTopShadowView.h"

@implementation WKTopShadowView


- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.shadowProviderLayer.frame = CGRectMake(0.0f, self.bounds.size.height, self.bounds.size.width, 10.0f);

}

@end
