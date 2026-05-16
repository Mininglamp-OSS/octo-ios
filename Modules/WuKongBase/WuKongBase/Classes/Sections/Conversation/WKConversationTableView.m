//
//  WKConversationTableView.m
//  WuKongBase
//
//  Created by tt on 2019/12/15.
//

#import "WKConversationTableView.h"
#import "UIView+WK.h"
#import "WKConstant.h"

@interface WKConversationTableView ()

@property(nonatomic,strong) UIEvent *beganEvent;

@end

@implementation WKConversationTableView

- (instancetype)init
{
    self = [super init];
    if (self) {
       // [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)]];
    }
    return self;
}

-(void) didTap:(UITapGestureRecognizer*)gesture {
    if ([_conversationTableDelegate conformsToProtocol:@protocol(WKConversationTableViewDelegate)] &&
        [_conversationTableDelegate respondsToSelector:@selector(tableView:touchesTime:)]){
        [_conversationTableDelegate tableView:self touchesTime:1.0f];
    }
}

-(void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [super touchesBegan:touches withEvent:event];
    self.beganEvent = event;
    if ([_conversationTableDelegate conformsToProtocol:@protocol(WKConversationTableViewDelegate)] &&
        [_conversationTableDelegate respondsToSelector:@selector(tableView:touchesBegan:withEvent:)]){
        [_conversationTableDelegate tableView:self touchesBegan:touches withEvent:event];
    }
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if ([_conversationTableDelegate conformsToProtocol:@protocol(WKConversationTableViewDelegate)] &&
        [_conversationTableDelegate respondsToSelector:@selector(tableView:touchesEnd:withEvent:)]){
        [_conversationTableDelegate tableView:self touchesEnd:touches withEvent:event];
    }
    CGFloat btwTime = event.timestamp -  self.beganEvent.timestamp;
    if ([_conversationTableDelegate conformsToProtocol:@protocol(WKConversationTableViewDelegate)] &&
        [_conversationTableDelegate respondsToSelector:@selector(tableView:touchesTime:)]){
        [_conversationTableDelegate tableView:self touchesTime:btwTime];
    }
}

@end
