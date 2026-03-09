//
//  UIButton+WK.h
//  WuKongBase
//
//  Created by tt on 2022/7/21.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN



@interface UIButton (WK)

- (void)lim_addEventHandler:(void (^)(void))block forControlEvents:(UIControlEvents)controlEvents;

@end

NS_ASSUME_NONNULL_END
