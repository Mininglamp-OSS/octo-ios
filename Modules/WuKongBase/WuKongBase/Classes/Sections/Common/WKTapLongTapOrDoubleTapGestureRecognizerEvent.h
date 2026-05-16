//
//  TapLongTapOrDoubleTapGestureRecognizerAction.h
//  WuKongBase
//
//  Created by tt on 2022/6/21.
//

#import <Foundation/Foundation.h>


typedef enum : NSUInteger {
    WKTapLongTapOrDoubleTapGestureRecognizerActionNone,
    WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForDoubleTap,
    WKTapLongTapOrDoubleTapGestureRecognizerActionWaitForSingleTap,
    WKTapLongTapOrDoubleTapGestureRecognizerActionFail,
    WKTapLongTapOrDoubleTapGestureRecognizerActionKeepWithSingleTap
} WKTapLongTapOrDoubleTapGestureRecognizerAction;

typedef enum : NSUInteger {
    WKTapLongTapOrDoubleTapGestureTap,
    WKTapLongTapOrDoubleTapGestureDoubleTap,
    WKTapLongTapOrDoubleTapGestureLongTap,
    WKTapLongTapOrDoubleTapGestureHold,
} WKTapLongTapOrDoubleTapGesture;


@interface WKTapLongTapOrDoubleTapGestureRecognizerEvent : NSObject

+(instancetype) action:(WKTapLongTapOrDoubleTapGestureRecognizerAction)action;

@property(nonatomic,assign) WKTapLongTapOrDoubleTapGestureRecognizerAction action;


@end
