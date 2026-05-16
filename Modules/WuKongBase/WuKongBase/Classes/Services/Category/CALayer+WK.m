//
//  CALayer+WK.m
//  WuKongBase
//
//  Created by tt on 2021/8/17.
//

#import "CALayer+WK.h"

@implementation CALayer (WK)

/*
 *  摇动
 */
-(void)shake{
    CAKeyframeAnimation *kfa = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    CGFloat s = 5;
    kfa.values = @[@(-s),@(0),@(s),@(0),@(-s),@(0),@(s),@(0)];
    //时长
    kfa.duration = 0.3f;
    //重复
    kfa.repeatCount = 2;
    //移除
    kfa.removedOnCompletion = YES;
    [self addAnimation:kfa forKey:@"shake"];
}

@end
