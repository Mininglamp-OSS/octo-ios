//
//  WKNumberKeyboardView.h
//  WuKongBase
//
//  Created by tt on 2020/9/17.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKNumberKeyboardView : UIView

@property(nonatomic,copy) NSString *done; // done的标题

@property(nonatomic,copy) void(^onDone)(void); // done点击

+(instancetype) initWithTextInput:(id<UITextInput>)textInput;



@end

NS_ASSUME_NONNULL_END
