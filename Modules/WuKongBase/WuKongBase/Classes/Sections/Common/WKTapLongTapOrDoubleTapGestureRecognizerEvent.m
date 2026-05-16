//
//  WKTapLongTapOrDoubleTapGestureRecognizerEvent.m
//  WuKongBase
//
//  Created by tt on 2022/6/21.
//

#import <Foundation/Foundation.h>

#import "WKTapLongTapOrDoubleTapGestureRecognizerEvent.h"

@implementation WKTapLongTapOrDoubleTapGestureRecognizerEvent

+ (instancetype)action:(WKTapLongTapOrDoubleTapGestureRecognizerAction)action {
    WKTapLongTapOrDoubleTapGestureRecognizerEvent *event = [[WKTapLongTapOrDoubleTapGestureRecognizerEvent alloc] init];
    event.action = action;
    return event;
}

@end
