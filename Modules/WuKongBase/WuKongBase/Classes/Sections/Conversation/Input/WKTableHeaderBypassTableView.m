//
//  WKTableHeaderBypassTableView.m
//  WuKongBase
//
//  Created by tt on 2021/11/3.
//

#import "WKTableHeaderBypassTableView.h"

@implementation WKTableHeaderBypassTableView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
   UIView *hitTest = [super hitTest:point withEvent:event];
    if([hitTest isDescendantOfView:self.tableHeaderView]) {
        return nil;
    }
    return hitTest;
}

@end
