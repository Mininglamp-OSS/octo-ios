//
//  ATGrowingTextView.h
//  Session
//
//  Created by tt on 2018/9/30.
//

#import <UIKit/UIKit.h>
#import "WKTextView.h"

NS_ASSUME_NONNULL_BEGIN

@class WKGrowingTextView;

@protocol WKGrowingTextViewDelegate <NSObject>

@optional

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;

- (void)growingTextView:(WKGrowingTextView *)growingTextView willChangeHeight:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve;

- (void)textViewDidChange:(UITextView *)textView;

@end

@interface WKGrowingTextView : UIView


-(instancetype) initWithFont:(UIFont*)font;

@property(nonatomic,strong) WKTextView *internalTextView;

@property(nonatomic,weak) id<WKGrowingTextViewDelegate> delegate;

// 最大高度和最小高度
@property (nonatomic) CGFloat maxHeight;
@property (nonatomic) CGFloat minHeight;

@property(nonatomic) CGSize contentSize;

@property(nonatomic,copy) NSString *text;


@property(nonatomic,strong,nullable) UIView *rightView;

/**
 重置文本框高度
 
 @param newSizeH <#newSizeH description#>
 */
- (void)resizeTextView:(CGFloat)newSizeH;


/// 计算出当前输入框文本的高度
-(CGFloat) measureHeight;

/**
 获得焦点
 
 @return <#return value description#>
 */
-(BOOL) becomeFirstResponder;
/**
 结束编辑
 
 @param force <#force description#>
 */
-(void) endEditing:(BOOL)force;


/**
 插入文本
 @param text <#text description#>
 */
-(void) insertText:(NSString*) text;


/**
 删除文本
 
 @param range <#range description#>
 */
-(void) deleteText:(NSRange)range;


/**
 被选中的范围
 
 @return <#return value description#>
 */
-(NSRange) selectedRange;


@end

NS_ASSUME_NONNULL_END
