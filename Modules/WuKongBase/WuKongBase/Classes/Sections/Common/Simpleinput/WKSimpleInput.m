//
//  WKSimpleInput.m
//  WuKongMoment
//
//  Created by tt on 2020/11/17.
//

#import "WKSimpleInput.h"
#import "UIView+WK.h"
#import "WKConstant.h"
#import "WKResource.h"
#import "WKSimpleEmojiPanel.h"
#import "WKCommon.h"
#import "WKApp.h"
#import <WuKongBase/WuKongBase.h>
#define WKPanelDefaultHeight (300.0f + [self safeBottom])// 面板默认高度

#define inputMinHeight  36.0f // 输入框高度

#define inputEdgeInsets  UIEdgeInsetsMake(15.0f, 15.0f, 15.0f, 15.0f) // 输入框边距

#define inputBarHeight (inputHeight+inputEdgeInsets.top+inputEdgeInsets.bottom ) // 输入框bar

#define itemEdgeInsets UIEdgeInsetsMake(10.0f, 10.0f, 10.0f, 10.0f) // item边距

@interface WKSimpleInput ()<WKGrowingTextViewDelegate>

@property(nonatomic,assign) CGFloat inputCurrentHeight; // 输入框当前高度
@property(nonatomic,assign,readonly) CGFloat inputBarCurrentHeight; // 输入框bar当前高度


@property(nonatomic,assign) CGFloat panelHeight; // 面板高度
@property(nonatomic,assign,readonly) CGFloat currentPanelHeight; // 当前面板高度
@property(nonatomic,strong) UIView *panelView; // 面板

@property(nonatomic,strong) UIView *itemBoxView;

@property(nonatomic,strong) UIButton *emojiBtn;
@property(nonatomic,strong) WKSimpleEmojiPanel *emojiPanel;



@end

@implementation WKSimpleInput

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupUI];
        [self addKeyboardListen];
    }
    return self;
}


-(void) setupUI {
    
    self.inputCurrentHeight = inputMinHeight;

   
    self.layer.shadowOffset = CGSizeMake(0.0f, -2.0f);
    self.layer.shadowOpacity = 1.0f;
   
    self.frame = CGRectMake(0.0f, 0.0f, WKScreenWidth, 0.0f);
    [self addSubview:self.textView];
    
    [self addSubview:self.itemBoxView];
    [self.itemBoxView addSubview:self.emojiBtn];
    
    [self.panelView addSubview:self.emojiPanel];
    [self addSubview:self.panelView];
    
    [self enableWrapLineMenus];
    
    // 长按菜单隐藏(长按菜单恢复到原来状态)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHideMenu:) name:UIMenuControllerDidHideMenuNotification object:nil];
}

- (void)dealloc {
    [self removeKeyboardListen];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIMenuControllerDidHideMenuNotification object:nil];
}

-(void) menuDidHideMenu:(NSNotification *)notification {
    [self enableWrapLineMenus];
}
-(void) wrapLineMenu:(id)sender {
    [self.textView insertText:@"\n"];
}
// 启用换行菜单
-(void) enableWrapLineMenus{
    UIMenuItem *menuItem = [[UIMenuItem alloc]initWithTitle:LLang(@"换行") action:@selector(wrapLineMenu:)];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setMenuItems:[NSArray arrayWithObject:menuItem]];
    [menuController setMenuVisible:NO];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
    
    if([WKApp shared].config.style == WKSystemStyleDark) {
        self.layer.shadowColor = [UIColor colorWithRed:15.0f/255.0f green:15.0f/255.0f blue:15.0f/255.0f alpha:1.0].CGColor;
        [self.textView.internalTextView setBackgroundColor:[UIColor colorWithRed:38.0f/255.0f green:38.0f/255.0f blue:38.0f/255.0f alpha:1.0]];
    }else{
        self.layer.shadowColor = [UIColor colorWithRed:240.0f/255.0f green:240.0f/255.0f blue:240.0f/255.0f alpha:1.0].CGColor;
        [self.textView.internalTextView setBackgroundColor:[UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0]];
    }

 
    self.lim_top = WKScreenHeight - [self inputTotalHeight];
    self.lim_height = [self inputTotalHeight];
    
    self.textView.lim_height = self.inputCurrentHeight;
    
    
    self.itemBoxView.lim_height = self.inputBarCurrentHeight;
    NSArray *subviews = self.itemBoxView.subviews;
    UIView *preView;
    if(subviews && subviews.count>0) {
        for (UIView *subview in subviews) {
            subview.lim_top = self.inputBarCurrentHeight/2.0f - subview.lim_height/2.0f;
            if(!preView) {
                subview.lim_left = 0.0f;
            }else{
                subview.lim_left = preView.lim_right + itemEdgeInsets.left;
            }
            preView = subview;
        }
        if(preView) {
            self.itemBoxView.lim_width = preView.lim_right;
        }
    }else{
        self.itemBoxView.lim_width = 0.0f;
    }
    self.itemBoxView.lim_left = self.lim_width - self.itemBoxView.lim_width - itemEdgeInsets.right;
    
    self.textView.lim_width = self.lim_width - self.itemBoxView.lim_width - itemEdgeInsets.left - itemEdgeInsets.right - itemEdgeInsets.left;
    self.textView.lim_left = itemEdgeInsets.left;
    
    self.panelView.lim_width = self.lim_width;
    self.panelView.lim_top = self.inputBarCurrentHeight;
    self.panelView.lim_height = self.lim_height - self.inputBarCurrentHeight;
    
}

- (UIButton *)emojiBtn {
    if(!_emojiBtn) {
        _emojiBtn = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)];
        [_emojiBtn setImage:[self imageName:@"Common/Index/EmojiFaceNormal"] forState:UIControlStateNormal];
        [_emojiBtn setImage:[self imageName:@"Common/Index/EmojiFaceSelected"] forState:UIControlStateSelected];
        [_emojiBtn addTarget:self action:@selector(emojiPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _emojiBtn;
}

- (UIView *)panelView {
    if(!_panelView) {
        _panelView = [[UIView alloc] init];
        [_panelView setBackgroundColor:[WKApp shared].config.cellBackgroundColor];
    }
    return _panelView;
}

- (WKSimpleEmojiPanel *)emojiPanel {
    if(!_emojiPanel) {
        _emojiPanel = [[WKSimpleEmojiPanel alloc] init];
        [_emojiPanel layoutPanel:0.0f];
        __weak typeof(self) weakSelf = self;
        [_emojiPanel setOnEmoji:^(WKEmotion * _Nonnull emoji) {
            [weakSelf.textView insertText:emoji.faceName];
        }];
        [_emojiPanel setOnSend:^{
           NSString *text = weakSelf.textView.text;
            weakSelf.textView.text = @"";
            [weakSelf resetTextView];
            if(weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(simpleInput:sendText:)]) {
                [weakSelf.delegate simpleInput:weakSelf sendText:text];
            }
        }];
    }
    return _emojiPanel;
}

-(void) emojiPressed:(UIButton*)btn {
    [self switchPanel];
}

-(void) switchPanel {
    BOOL selected = !self.emojiBtn.selected;
    self.emojiBtn.selected = selected;
    
    if(selected) {
        self.panelHeight = WKPanelDefaultHeight;
        [self.textView endEditing:YES];
       
        
    }else{
        self.panelHeight = 0.0f;
        [self.textView becomeFirstResponder];
       
    }
   
    __weak typeof(self) weakSelf = self;
    self.panelView.lim_top = self.lim_height;
    [weakSelf keyboardAnimation:^{
        [weakSelf inputPanelUpOrDown:weakSelf.panelHeight>0];
        [weakSelf.emojiPanel layoutPanel:weakSelf.panelHeight];
        [weakSelf layoutSubviews];
    }];
   
   
}



-(CGFloat) safeBottom {
    CGFloat safeBottom = 0.0f;
    if (@available(iOS 11.0, *)) {
        safeBottom = [[UIApplication sharedApplication].keyWindow safeAreaInsets].bottom;
    }
    return safeBottom;
}

- (UIView *)itemBoxView {
    if(!_itemBoxView) {
        _itemBoxView = [[UIView alloc] init];
    }
    return _itemBoxView;
}

-(WKGrowingTextView*) textView {
    if(!_textView) {
        _textView = [[WKGrowingTextView alloc] init];
        _textView.lim_height =inputMinHeight;
        _textView.lim_width = self.lim_width - inputEdgeInsets.left - inputEdgeInsets.right;
        _textView.lim_left = inputEdgeInsets.left;
        _textView.lim_top = inputEdgeInsets.top;
        [_textView.internalTextView setBackgroundColor:[UIColor colorWithRed:246.0f/255.0f green:246.0f/255.0f blue:246.0f/255.0f alpha:1.0]];
        _textView.layer.masksToBounds = YES;
        _textView.layer.cornerRadius = 15.0f;
//        _textView.layer.borderWidth = 0.5;
//        _textView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        _textView.tag = 99;
        _textView.delegate = self;
        _textView.internalTextView.returnKeyType = UIReturnKeySend;
    }
    return _textView;
}

- (CGFloat) inputTotalHeight {
    if(self.keyboardHeight>0) {
        return self.keyboardHeight + self.inputBarCurrentHeight;
    }else if(self.panelHeight>0) {
        return self.panelHeight +self.inputBarCurrentHeight;
    }
    return self.inputBarCurrentHeight + [self safeBottom];
}

- (CGFloat)inputBarCurrentHeight {
    return self.inputCurrentHeight + inputEdgeInsets.top + inputEdgeInsets.bottom;
}

-(CGFloat) inputTextViewMinHeight {
    return inputMinHeight;
}

// 当前面板的高度
-(CGFloat) currentPanelHeight{
    if(self.keyboardHeight>0) {
        return self.keyboardHeight;
    }
    
    return self.panelHeight;
}

- (void)becomeFirstResponder {
    [super becomeFirstResponder];
    [self.textView becomeFirstResponder];
}


#pragma  mark -- 键盘相关

//添加监听键盘
-(void)addKeyboardListen{
    [self removeKeyboardListen];
    
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
    [self handleKeyboardNotification:notification show:false];

}

// 键盘显示
- (void)keyboardWillShow:(NSNotification *)notification{
    [self handleKeyboardNotification:notification show:true];
    
    if(self.panelHeight>0) {
        [self switchPanel];
    }
    
}

- (void)handleKeyboardNotification:(NSNotification *)notification show:(BOOL)show{
    CGRect keyboardBeginFrame = [notification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect keyboardBeginFrameInView = [self.superview convertRect:keyboardBeginFrame fromView:nil];
    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardEndFrameInView = [self.superview convertRect:keyboardEndFrame fromView:nil];
    CGRect keyboardEndFrameIntersectingView = CGRectIntersection(self.superview.bounds, keyboardEndFrameInView);
    
    CGFloat keyboardHeight = CGRectGetHeight(keyboardEndFrameIntersectingView);
    
    self.keyboardHeight =keyboardHeight;
    
    
    // Workaround for collection view cell sizes changing/animating when view is first pushed onscreen on iOS 8.
    if (CGRectEqualToRect(keyboardBeginFrameInView, keyboardEndFrameInView)) {
        __weak typeof(self) weakSelf = self;
        [UIView performWithoutAnimation:^{
            [weakSelf layoutSubviews];
            [weakSelf inputPanelUpOrDown:show];
        }];
        return;
    }
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
    [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    [self layoutSubviews];
    [self inputPanelUpOrDown:show];
    
    [UIView commitAnimations];
    
  

}


// 输入框面板收缩
-(void) inputPanelUpOrDown:(BOOL)up {
    if( [self delegate]&&[self.delegate respondsToSelector:@selector(simpleInputUp:up:)]){
        [self.delegate simpleInputUp:self up:up];
    }
}

- (void)setPlaceholder:(NSString *)placeholder {
    [self.textView.internalTextView setPlaceholder:placeholder];
}

#pragma mark - WKGrowingTextViewDelegate


#pragma mark - UITextViewDelegate
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    if ([text isEqualToString:@"\n"]) {
        NSString *content = textView.text;
        textView.text = @"";
        [self resetTextView];
        if(self.delegate && [self.delegate respondsToSelector:@selector(simpleInput:sendText:)]) {
            [self.delegate simpleInput:self sendText:content];
        }
        return NO;
    } else  if ([text isEqualToString:@""] && range.length == 1 ) { // 删除
        NSRange range = [self delRangeForEmoticon];
        if(range.length == 1) {
            return YES;
        }
        [self inputDeleteText:range];
        return NO;
    }

    return YES;
}

-(void) resetTextView {
    self.inputCurrentHeight = inputMinHeight;
    [self animateInputPanelChange];
    [self triggerInputPanelChangeEvent];
}

-(void) inputDeleteText:(NSRange)range{
    [self.textView deleteText:range];
}


- (NSRange)delRangeForEmoticon
{
    NSString *text = self.textView.text;
    NSRange range = [self rangeForPrefix:@"[" suffix:@"]"];
    NSRange selectedRange = [self inputSelectedRange];
    if (range.length > 1)
    {
        NSString *name = [text substringWithRange:range];
        WKEmotion *emotion = [[WKEmoticonService shared] emotionByFaceName:name];
        range = emotion? range : NSMakeRange(selectedRange.location - 1, 1);
    }
    return range;
}

- (NSRange)rangeForPrefix:(NSString *)prefix suffix:(NSString *)suffix
{
    NSString *text = self.textView.text;
    NSRange range = [self inputSelectedRange];
    NSString *selectedText = range.length ? [text substringWithRange:range] : text;
    NSInteger endLocation = range.location;
    if (endLocation <= 0)
    {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger index = -1;
    if ([selectedText hasSuffix:suffix]) {
        //往前搜最多20个字符，一般来讲是够了...
        NSInteger p = 20;
        for (NSInteger i = endLocation; i >= endLocation - p && i-1 >= 0 ; i--)
        {
            NSRange subRange = NSMakeRange(i - 1, 1);
            NSString *subString = [text substringWithRange:subRange];
            if ([subString compare:prefix] == NSOrderedSame)
            {
                index = i - 1;
                break;
            }
        }
    }
    return index == -1? NSMakeRange(endLocation - 1, 1) : NSMakeRange(index, endLocation - index);
}

-(NSRange) inputSelectedRange{
    
    return self.textView.selectedRange;
}


- (void)growingTextView:(WKGrowingTextView *)growingTextView willChangeHeight:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve{
   
    if(height < inputMinHeight) {
        height = inputMinHeight;
    }
    CGFloat currentHeight = MIN(height, self.textView.maxHeight);
    if(height!=self.inputCurrentHeight) {
//        self.currentMessageToolBarHeight +=( currentHeight - self.currentInputHeight);
        self.inputCurrentHeight = currentHeight;
        [self animateInputPanelChange];
        [self triggerInputPanelChangeEvent];
    }
    
}


// 输入面板发送改变
-(void) triggerInputPanelChangeEvent {
    if(_delegate&&[_delegate respondsToSelector:@selector(simpleInput:heightChange:)]) {
        [_delegate simpleInput:self heightChange:self.inputCurrentHeight];
    }
}


-(void) animateInputWithBlock:(void(^)(void)) block{
    [UIView animateWithDuration:0.12f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        block();
    } completion:nil];
}

-(void) animateInputPanelChange {
    [self animateInputWithBlock:^{
//        [self adjustInput:NO];
        [self layoutSubviews]; // 加了这句textView才有向上增长的效果，而不是向上移动（很重要）
    }];
}

-(void) keyboardAnimation:(void(^)(void)) block{
    
    [WKCommon commonAnimation:^{
        if(block){
            block();
        }
    }];
}

- (BOOL)endEditing:(BOOL)force {
    
    [self.textView.internalTextView endEditing:YES];
    
    if(self.panelHeight>0) {
        [self switchPanel];
    }
    
    
    return [super endEditing:force];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end
