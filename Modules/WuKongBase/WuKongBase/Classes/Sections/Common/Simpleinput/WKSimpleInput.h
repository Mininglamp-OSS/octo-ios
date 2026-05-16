//
//  WKSimpleInput.h
//  WuKongMoment
//
//  Created by tt on 2020/11/17.
//

#import <UIKit/UIKit.h>
#import "WKGrowingTextView.h"
@class WKSimpleInput;
NS_ASSUME_NONNULL_BEGIN

@protocol WKSimpleInputDelegate <NSObject>

@optional
// 输入框弹起
- (void)simpleInputUp:(WKSimpleInput *)input up:(BOOL)up;

// 输入框高度发生改变
-(void) simpleInput:(WKSimpleInput*) input heightChange:(CGFloat)height;
// 发送文本
-(void) simpleInput:(WKSimpleInput*) input sendText:(NSString*)text;

@end

@interface WKSimpleInput : UIView

@property(nonatomic,weak) id<WKSimpleInputDelegate> delegate;

@property(nonatomic,strong) WKGrowingTextView *textView;

@property (assign, nonatomic) CGFloat keyboardHeight; // 键盘高度
@property(nonatomic,assign,readonly) CGFloat inputTotalHeight; //当前输入框总高度

@property(nonatomic,assign,readonly) CGFloat inputTextViewMinHeight; //当前输入框最小高度

@property(nonatomic,copy) NSString *placeholder; // 占位


- (void)becomeFirstResponder;



@end

NS_ASSUME_NONNULL_END
