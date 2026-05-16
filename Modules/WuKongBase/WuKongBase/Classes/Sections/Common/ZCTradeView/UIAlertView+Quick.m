//
//  UIAlertView+Quick.m
//  直销银行
//
//  Created by 塔利班 on 15/4/18.
//  Copyright (c) 2015年 联创智融. All rights reserved.
//

#import "UIAlertView+Quick.h"

@implementation UIAlertView (Quick)

+ (void)showWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:delegate cancelButtonTitle:cancelButtonTitle otherButtonTitles:otherButtonTitles, nil];
    [alertView show];
}

@end
