//
//  WKCopyLabel.m
//  WuKongBase
//
//  Created by tt on 2022/5/9.
//

#import "WKCopyLabel.h"
#import "WKApp.h"
@interface WKCopyLabel ()

@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGR;

@end

@implementation WKCopyLabel

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

-(void) setup {
    // 长按菜单隐藏(长按菜单恢复到原来状态)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHideMenu:) name:UIMenuControllerDidHideMenuNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIMenuControllerDidHideMenuNotification object:nil];
}

-(void) menuDidHideMenu:(NSNotification*)notify {
    self.backgroundColor = [UIColor clearColor];
}

- (void)setCopyEnabled:(BOOL)copyEnabled
{
    _copyEnabled = copyEnabled;
    
    // 确保 UILabel 可交互
    self.userInteractionEnabled = copyEnabled;
    
    if (copyEnabled && !self.longPressGR) {
        self.longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(handleLongPressGesture:)];
        [self addGestureRecognizer:self.longPressGR];
    }
    
    if (self.longPressGR) {
        self.longPressGR.enabled = copyEnabled;
    }
}

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)longPressGR
{
    if (longPressGR.state == UIGestureRecognizerStateBegan) {
        [self becomeFirstResponder];
        [[UIMenuController sharedMenuController] setTargetRect:self.frame inView:self.superview];
        [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
        if(WKApp.shared.config.style == WKSystemStyleDark) {
            self.backgroundColor = [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:0.2f];
        }else{
            self.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.2f];
        }
        
    }
}

#pragma mark - UIMenuController

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    // 自定义响应UIMenuItem Action，例如你可以过滤掉多余的系统自带功能（剪切，选择等），只保留复制功能。
    return (action == @selector(copy:));
}

- (void)copy:(id)sender
{
    [[UIPasteboard generalPasteboard] setString:self.text];
}
@end
