//
//  ATGrowingTextView.m
//  Session
//
//  Created by tt on 2018/9/30.
//

#ifdef __LP64__
#   define CGFloor floor
#else
#   define CGFloor floorf
#endif
#import "UIView+WK.h"
#import "WKGrowingTextView.h"
#import "WKConstant.h"
#import "WKCommon.h"
#import "WKTextView.h"
@interface WKGrowingTextView()<UITextViewDelegate>{
    UIColor *_intrinsicTextColor;
    // textview 字体
    UIFont *_intrinsicTextFont;
}




@end

@implementation WKGrowingTextView


-(instancetype) init{
    self = [super init];
    if (!self)return nil;
    [self setupUI:[UIFont systemFontOfSize:16.0f]];
    return self;
}

-(instancetype) initWithFont:(UIFont*)font {
    self = [super init];
    if (!self)return nil;
    [self setupUI:font];
    return self;
}

-(void) setupUI:(UIFont*)font{
    
    _maxHeight = 100.0f; // 输入框最大高度，大于此高度进入滚动模式
    _minHeight = 20.0f;
    _intrinsicTextFont = font;
    
    [self addSubview:self.internalTextView];
    
    
    
    
}

-(void) layoutSubviews{
    [super layoutSubviews];
    
    _internalTextView.lim_size = self.lim_size;
    
    if(_rightView){
        CGFloat rightSpace = 2.0f;
        _internalTextView.lim_width = self.lim_width - _rightView.lim_width - rightSpace;
        _rightView.lim_left = self.internalTextView.lim_right - rightSpace;
        _rightView.lim_top = self.lim_height - _rightView.lim_height - 2.0f;
    }
    
}

// 计算出的高度
- (CGFloat)measureHeight
{
    if ([WKCommon iosMajorVersion] >= 7)
    {
        CGRect frame = _internalTextView.bounds;
        CGSize fudgeFactor = CGSizeMake(10.0, 17.0);
        
        frame.size.height -= fudgeFactor.height;
        frame.size.width -= fudgeFactor.width;
        
        frame.size.width -= _internalTextView.textContainerInset.right;
        
        NSMutableAttributedString *textToMeasure = [[NSMutableAttributedString alloc] initWithAttributedString:_internalTextView.attributedText];
        if ([textToMeasure.string hasSuffix:@"\n"])
        {
            [textToMeasure appendAttributedString:[[NSAttributedString alloc] initWithString:@"-"]];
        }
        [textToMeasure removeAttribute:NSFontAttributeName range:NSMakeRange(0, textToMeasure.length)];
        if (_intrinsicTextFont != nil) {
            [textToMeasure addAttribute:NSFontAttributeName value:_intrinsicTextFont range:NSMakeRange(0, textToMeasure.length)];
        }
        
        // NSString class method: boundingRectWithSize:options:attributes:context is
        // available only on ios7.0 sdk.
        CGRect size = [textToMeasure boundingRectWithSize:CGSizeMake(CGRectGetWidth(frame), MAXFLOAT)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                       //attributes:attributes
                                                  context:nil];
        
        return CGFloor(CGRectGetHeight(size) + fudgeFactor.height);
    }
    else
    {
        return CGFloor(self.internalTextView.contentSize.height);
    }
}

-(void) setContentSize:(CGSize)contentSize{
    _internalTextView.contentSize = contentSize;
}

#pragma mark - textView
-(UITextView*)internalTextView {
    if(!_internalTextView) {
        _internalTextView = [[WKTextView alloc] init];
        _internalTextView.font = _intrinsicTextFont;
        _internalTextView.delegate = self;
        _internalTextView.contentInset = UIEdgeInsetsZero;
        _internalTextView.showsHorizontalScrollIndicator = NO;
        // _internalTextView.attributedText = [[NSAttributedString alloc] initWithString:@"-" attributes:[self defaultAttributes]];
        _internalTextView.scrollsToTop = false;
        _internalTextView.scrollEnabled = YES;
//        _internalTextView.returnKeyType = UIReturnKeySend;
        if ([WKCommon iosMajorVersion]>= 7) {
            _internalTextView.textContainer.layoutManager.allowsNonContiguousLayout = true;
            _internalTextView.allowsEditingTextAttributes = false;
        }
        //        [_internalTextView setBackgroundColor:[UIColor blueColor]];
    }
    return _internalTextView;
}

- (NSDictionary *)defaultAttributes {
    if (_intrinsicTextFont == nil) {
        return @{NSFontAttributeName: [UIFont systemFontOfSize:16.0f]};
    } else {
        if (_intrinsicTextColor)
            return @{NSFontAttributeName: _intrinsicTextFont, NSForegroundColorAttributeName: _intrinsicTextColor};
        else
            return @{NSFontAttributeName: _intrinsicTextFont};
    }
}

#pragma mark - UITextViewDelegate
- (void)textViewDidChange:(UITextView *)__unused textView{
    [self refreshHeight:true];
    if (_delegate && [_delegate respondsToSelector:@selector(textViewDidChange:)]) {
        [_delegate textViewDidChange:textView];
    }
}
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    
    if (_delegate && [_delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
        return [_delegate textView:textView shouldChangeTextInRange:range replacementText:text];
    }
    return YES;
}

- (void)refreshHeight:(bool)textChanged{
    CGFloat newSizeH = [self measureHeight];
    id<WKGrowingTextViewDelegate> delegate = _delegate;
    if(newSizeH < _minHeight || !_internalTextView.hasText)
        newSizeH = _minHeight; //not smalles than minHeight
    
    if (_internalTextView.frame.size.height > _maxHeight)
        newSizeH = _maxHeight; // not taller than maxHeight
    
    if (ABS(_internalTextView.frame.size.height - newSizeH) > FLT_EPSILON ){
        if (newSizeH > _maxHeight && _internalTextView.frame.size.height <= _maxHeight)
            newSizeH = _maxHeight;
        
        if (newSizeH <= _maxHeight) {
            if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:duration:animationCurve:)])
                [delegate growingTextView:self willChangeHeight:newSizeH duration:0.0 animationCurve:0];
        }
    }
}

- (void)resizeTextView:(CGFloat)newSizeH
{
    if(newSizeH>=_maxHeight) {
        self.internalTextView.scrollEnabled = YES;
    }else {
        self.internalTextView.scrollEnabled = NO;
    }
    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.size.height = CGFloor(newSizeH);
    self.frame = internalTextViewFrame;
    
    internalTextViewFrame.origin = CGPointZero;
    if(!CGRectEqualToRect(_internalTextView.frame, internalTextViewFrame))
        _internalTextView.frame = internalTextViewFrame;
}

-(BOOL) becomeFirstResponder {
    return [self.internalTextView becomeFirstResponder];
}


-(void) endEditing:(BOOL)force{
    [self.internalTextView endEditing:YES];
}

-(void) setText:(NSString *)text{
    [self.internalTextView setText:text];
}
-(NSString*) text{
    return self.internalTextView.text;
}
-(void) insertText:(NSString*) text{
    NSRange range = self.selectedRange;
    NSString *replaceText = [self.internalTextView.text stringByReplacingCharactersInRange:range withString:text];
    range = NSMakeRange(range.location + text.length, 0);
    [self.internalTextView setText:replaceText];
    self.selectedRange = range;
    [self refreshHeight:true];
}

-(void) deleteText:(NSRange)range{
    NSString *text = self.text;
    if (range.location + range.length <= [text length]
        && range.location != NSNotFound && range.length != 0)
    {
        NSString *newText = [text stringByReplacingCharactersInRange:range withString:@""];
        NSRange newSelectRange = NSMakeRange(range.location, 0);
        [self.internalTextView setText:newText];
        self.internalTextView.selectedRange = newSelectRange;
    }
    [self refreshHeight:true];
}

-(NSRange) selectedRange{
    return self.internalTextView.selectedRange;
}

-(void) setSelectedRange:(NSRange)selectedRange{
    self.internalTextView.selectedRange  = selectedRange;
}

-(void) setRightView:(UIView *)rightView{
    if(_rightView){
        [_rightView removeFromSuperview];
    }
    _rightView = rightView;
    if(rightView) {
        [self addSubview:rightView];
    }
}


@end


