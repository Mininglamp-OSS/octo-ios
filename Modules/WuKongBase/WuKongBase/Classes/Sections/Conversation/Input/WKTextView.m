//
//  WKTextView.m
//  WuKongBase
//
//  Created by tt on 2020/2/2.
//

#import "WKTextView.h"

@implementation WKTextView




-(UIResponder*)nextResponder{
    if (self.overrideNextResponder != nil) {
        return self.overrideNextResponder;
    } else {
        return [super nextResponder];
    }
}
-(BOOL)canPerformAction:(SEL)action withSender:(id)sender{
    
    if (self.overrideNextResponder != nil) {
         return NO;
    }else {
        return [super canPerformAction:action withSender:sender];
    }
        
}

@end
