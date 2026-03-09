//
//  WKNumberKeyboardView.m
//  WuKongBase
//
//  Created by tt on 2020/9/17.
//

#import "WKNumberKeyboardView.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WKResource.h"
#import "WKNavigationManager.h"
#import "WKConstant.h"
#import "WKLogs.h"
#define eachLineKeyCount 4 // 每行按键数量
#define eachLineKeySpace 10.0f // 每行按键间距

#define eachKeyHeight 50.0f // 每个按键高度

#define commonKeyBoxTag -100

//#define emptyheight 200.0f // 空白部分高度，用于done的动画
@interface WKNumberKeyboardView ()

@property(nonatomic,weak) id<UITextInput> textInput;

@property(nonatomic,strong) UIView *commonKeyBox; // 常规按键box

@property(nonatomic,strong) UIButton *doneBtn; // done的按钮

@property(nonatomic,weak) UIViewController *topViewController;

@end

@implementation WKNumberKeyboardView

- (instancetype)init
{
    self = [super init];
    if (self) {
        CGFloat bottomSafe = 0.0f;
        if (@available(iOS 11.0, *)) {
            bottomSafe = [[[UIApplication sharedApplication] keyWindow] safeAreaInsets].bottom;
        }
         self.frame = CGRectMake(0.0f, 0.0f, [UIScreen mainScreen].bounds.size.width, eachKeyHeight*4+eachLineKeySpace*5+bottomSafe);
       
        [self initCommonNumKey];
        [self addSubview:self.commonKeyBox];
        [self initOtherBtn];
        [self addKeyboardListen];
        
        self.topViewController = [WKNavigationManager shared].topViewController;
    }
    return self;
}

- (void)dealloc {
    [self removeKeyboardListen];
    WKLogDebug(@"%s",__func__);
}

+(instancetype) initWithTextInput:(id<UITextInput>)textInput {
    WKNumberKeyboardView *v = [[WKNumberKeyboardView alloc] init];
    v.textInput = textInput;
    return v;
}


- (UIView *)commonKeyBox {
    if(!_commonKeyBox) {
        CGFloat bottomSafe = 0.0f;
        if (@available(iOS 11.0, *)) {
            bottomSafe = [[[UIApplication sharedApplication] keyWindow] safeAreaInsets].bottom;
        }
        CGSize size = [self getKeySize];
        CGFloat height = eachKeyHeight*3+eachLineKeySpace*4;
        _commonKeyBox = [[UIView alloc] initWithFrame:CGRectMake(0.0f, self.lim_height - height - eachKeyHeight -eachLineKeySpace - bottomSafe, self.lim_width - size.width - eachLineKeySpace, height)];
        [_commonKeyBox setBackgroundColor:[UIColor clearColor]];
        _commonKeyBox.tag = commonKeyBoxTag;
    }
    return _commonKeyBox;
}

// 按键大小
-(CGSize) getKeySize {
    return CGSizeMake((self.lim_width-(eachLineKeyCount+1)*eachLineKeySpace)/eachLineKeyCount, eachKeyHeight);
}


// 初始化常规数字键(1-9)
-(void) initCommonNumKey {
    for (NSInteger i=1; i<=9; i++) {
        UIButton *btn = [self getCommonNumBtn:[NSString stringWithFormat:@"%ld",(long)i]];
        btn.tag = i;
        [self.commonKeyBox addSubview:btn];
        
    }
}

#define zeroKeyBoxTag 0
#define dotKeyBoxTag -1
#define delKeyBoxTag -2
#define doneKeyBoxTag -99
-(void) initOtherBtn {
    // 0
    UIButton *btn = [self getCommonNumBtn:@"0"];
    btn.lim_width = btn.lim_width*2.0f+eachLineKeySpace;
    btn.tag = zeroKeyBoxTag;
    [self addSubview:btn];
    
    // .
    btn = [self getCommonNumBtn:@"."];
    btn.tag = dotKeyBoxTag;
    [self addSubview:btn];
    
    // del
    btn = [self getCommonNumBtn:@""];
    btn.tag = delKeyBoxTag;
    [btn setImage:[self imageName:@"Common/Index/Del"] forState:UIControlStateNormal];
    [self addSubview:btn];
    
    // done
    self.doneBtn = [self getCommonNumBtn:self.done?:@"完成"];
    self.doneBtn.tag = doneKeyBoxTag;
    self.doneBtn.lim_height = btn.lim_height*3+ eachLineKeySpace*2;
    [self.doneBtn setBackgroundColor:[WKApp shared].config.themeColor];
    [self.doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self addSubview:self.doneBtn];
}

- (void)setDone:(NSString *)done {
    _done = done;
    UIButton *doneBtn = [self viewWithTag:doneKeyBoxTag];
    if(doneBtn) {
        [doneBtn setTitle:done forState:UIControlStateNormal];
    }
}


-(UIButton*) getCommonNumBtn:(NSString*)title {
    CGSize size = [self getKeySize];
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    btn.layer.masksToBounds = YES;
    btn.layer.cornerRadius = 4.0f;
    [[btn titleLabel] setFont:[[WKApp shared].config appFontOfSizeSemibold:20.0f]];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(btnBackGroundHighlighted:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(btnBackGroundNormal:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)keyBoardAction:(UIButton *)sender {
    NSInteger number = sender.tag;
    if (number <= 9 && number >= 0) { // 0 - 9数字
        [self insert:[NSString stringWithFormat:@"%ld",number]];
        return;
    }
    if(number == delKeyBoxTag) { // 删除
        if ([self.textInput hasText]) {
            [self.textInput deleteBackward];
        }
        return;
    }
    if(number == dotKeyBoxTag) { // .
        [self insert:@"."];
        return;
    }
    if(number == doneKeyBoxTag) { // done
        if(self.onDone) {
            self.onDone();
        }
        return;
    }
    
}
//  普通状态下的背景色
- (void)btnBackGroundNormal:(UIButton *)sender
{
    sender.alpha = 1.0f;
    [self playClickAudio];
    [self keyBoardAction:sender];
}

//  高亮状态下的背景色
- (void)btnBackGroundHighlighted:(UIButton *)sender
{
     sender.alpha = 0.5f;
}
#pragma mark - logic
- (void) playClickAudio{
    
    [[UIDevice currentDevice] playInputClick];
}
- (BOOL)enableInputClicksWhenVisible
{
    return YES;
}

- (void) insert:(NSString *)text
{
    if ([self.textInput isKindOfClass:[UITextField class]]) {
        UITextField *textFd = (UITextField*)self.textInput;
        if([text isEqualToString:@"."]) {
            if([textFd.text containsString:@"."]) {// 点只能有一个
                return;
            }
            if([textFd.text isEqualToString:@""]) { // 第一个点带0
                text = @"0.";
            }
            
        }
        id<UITextFieldDelegate> delegate = [(UITextField *)self.textInput delegate];
        if ([delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            NSRange range = [self _selectedRangeInInputView:self.textInput];
            if ([delegate textField:(UITextField *)self.textInput shouldChangeCharactersInRange:range replacementString:text]) {
                [self.textInput insertText:text];
            }
        } else {
            [self.textInput insertText:text];
        }
    }
    else if ([self.textInput isKindOfClass:[UITextView class]]) {
        UITextView *textVW = (UITextView*)self.textInput;
        if([text isEqualToString:@"."]) {
            if([textVW.text containsString:@"."]) {// 点只能有一个
                return;
            }
            if([textVW.text isEqualToString:@""]) { // 第一个点带0
                text = @"0.";
            }
            
        }
        id<UITextViewDelegate> delegate = [(UITextView *)self.textInput delegate];
        if ([delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
            NSRange range = [self _selectedRangeInInputView:(id<UITextInput>)self.textInput];
            if ([delegate textView:(UITextView *)self.textInput shouldChangeTextInRange:range replacementText:text]) {
                [self.textInput insertText:text];
            }
        } else {
            [self.textInput insertText:text];
        }
    }
    else {
        [self.textInput insertText:text];
    }
}
- (NSRange)_selectedRangeInInputView:(id<UITextInput>)inputView
{
    UITextPosition* beginning = inputView.beginningOfDocument;
    
    UITextRange* selectedRange = inputView.selectedTextRange;
    UITextPosition* selectionStart = selectedRange.start;
    UITextPosition* selectionEnd = selectedRange.end;
    
    const NSInteger location = [inputView offsetFromPosition:beginning toPosition:selectionStart];
    const NSInteger length = [inputView offsetFromPosition:selectionStart toPosition:selectionEnd];
    
    return NSMakeRange(location, length);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.backgroundColor = [UIColor colorWithRed:30.0f/255.0f green:30.0f/255.0f blue:30.0f/255.0f alpha:1.0];
    }else{
        self.backgroundColor = [UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0];
    }
    
    NSArray *commKeyViews = [self.commonKeyBox subviews];
    NSInteger commRowPos = 0;
    NSInteger commColumnPos = 0 ;
    for (NSInteger i=0; i<commKeyViews.count; i++) {
        commColumnPos++;
        if(i%3 == 0) {
            commRowPos++;
            commColumnPos = 1;
        }
        
        UIButton *btn = commKeyViews[i];
        btn.lim_left = (commColumnPos-1)*btn.lim_width+commColumnPos*eachLineKeySpace;
        btn.lim_top = (commRowPos-1)*btn.lim_height + commRowPos*eachLineKeySpace;
        [btn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        
        if([WKApp shared].config.style == WKSystemStyleDark) {
            btn.backgroundColor = [UIColor colorWithRed:44.0f/255.0f green:44.0f/255.0f blue:44.0f/255.0f alpha:1.0f];
        }else{
            btn.backgroundColor = [UIColor whiteColor];
        }
    }
    
    NSArray *otherBtns = [self subviews];
    for (UIView *v in otherBtns) {
        
        if(v.tag != doneKeyBoxTag && v.tag != commonKeyBoxTag) {
            if([WKApp shared].config.style == WKSystemStyleDark) {
                v.backgroundColor = [UIColor colorWithRed:44.0f/255.0f green:44.0f/255.0f blue:44.0f/255.0f alpha:1.0f];
            }else{
                v.backgroundColor = [UIColor whiteColor];
            }
        }
        
        if(v.tag == commonKeyBoxTag) {
            continue;
        }
        if(v.tag == zeroKeyBoxTag) {
            v.lim_top = self.commonKeyBox.lim_bottom;
            v.lim_left = eachLineKeySpace;
            UIButton *btn = (UIButton*)v;
            [btn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        }else if(v.tag == dotKeyBoxTag) {
            v.lim_left = v.lim_width*2 + eachLineKeySpace*3;
            v.lim_top = self.commonKeyBox.lim_bottom;
            UIButton *btn = (UIButton*)v;
            [btn setTitleColor:[WKApp shared].config.defaultTextColor forState:UIControlStateNormal];
        }else if(v.tag == delKeyBoxTag) {
            v.lim_left = self.commonKeyBox.lim_right;
            v.lim_top = self.commonKeyBox.lim_top + eachLineKeySpace;
        }else if(v.tag == doneKeyBoxTag) {
            v.lim_left = self.commonKeyBox.lim_right;
            v.lim_top = self.commonKeyBox.lim_top + eachKeyHeight + eachLineKeySpace*2;
            v.lim_height = eachKeyHeight*3+ eachLineKeySpace*2;
        }
    }
    
}


////添加监听键盘
-(void)addKeyboardListen{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
}
//移除监听
-(void)removeKeyboardListen{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
}

// 键盘隐藏
- (void)keyboardWillHide:(NSNotification *)notification{
    [self configureWithKeyboardNotification:notification show:NO];
}

// 键盘显示
- (void)keyboardWillShow:(NSNotification *)notification{
    [self configureWithKeyboardNotification:notification show:YES];
}

- (void)configureWithKeyboardNotification:(NSNotification *)notification show:(BOOL)show{

    
    [UIView performWithoutAnimation:^{
         [self.doneBtn removeFromSuperview];
        if(!show) {
//            [self.doneBtn removeFromSuperview];
            CGFloat bottomSafe = 0.0f;
            if (@available(iOS 11.0, *)) {
                bottomSafe = [[[UIApplication sharedApplication] keyWindow] safeAreaInsets].bottom;
            }
            self.doneBtn.lim_top = WKScreenHeight - (bottomSafe + eachLineKeySpace) - eachKeyHeight*3;
            if(![self.doneBtn.superview isEqual:self.topViewController.view] ) {
                [self.topViewController.view addSubview:self.doneBtn];
            }
             
        }else {
//            self.doneBtn.lim_top = eachKeyHeight + eachLineKeySpace*2;
            [self addSubview:self.doneBtn];
        }
    }];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
    [UIView setAnimationBeginsFromCurrentState:YES];

    if(show) {
        [self layoutIfNeeded];
    }else {
        
        self.doneBtn.lim_height = eachKeyHeight;
       
    }
    [UIView commitAnimations];
}



-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end
