//
//  WKKeyboardService.m
//  WuKongBase
//
//  Created by tt on 2022/9/25.
//

#import "WKKeyboardService.h"
#import "WKNavigationManager.h"

@interface WKKeyboardService ()



@end

@implementation WKKeyboardService

static WKKeyboardService *_instance;
+ (WKKeyboardService *)shared {
    if (_instance == nil) {
        _instance = [[super alloc]init];
    }
    return _instance;
}

-(void) setup {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center  addObserver:self selector:@selector(keyboardDidShow)  name:UIKeyboardDidShowNotification  object:nil];
    [center addObserver:self selector:@selector(keyboardDidHide)  name:UIKeyboardWillHideNotification object:nil];
    [center addObserver:self selector:@selector(keyboardChangeFrame)  name:UIKeyboardDidChangeFrameNotification object:nil];
}

-(void) keyboardChangeFrame {
  
}

- (void)keyboardDidShow{
    self.keyboardIsVisible = YES;
    
}
 
- (void)keyboardDidHide{
     self.keyboardIsVisible = NO;
}

@end
