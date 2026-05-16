//
//  WKTouchTableView.m
//  WuKongMoment
//
//  Created by tt on 2020/11/18.
//

#import "WKTouchTableView.h"

@implementation WKTouchTableView


-(void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [super touchesBegan:touches withEvent:event];
    if ([_touchTableViewDelegate conformsToProtocol:@protocol(WKTouchTableViewDelegate)] &&
        [_touchTableViewDelegate respondsToSelector:@selector(tableView:touchesBegan:withEvent:)]){
        [_touchTableViewDelegate tableView:self touchesBegan:touches withEvent:event];
    }
}


@end
