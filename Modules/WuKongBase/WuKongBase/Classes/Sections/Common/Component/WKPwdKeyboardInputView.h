//
//  WKPwdKeyboardInputView.h
//  WuKongWallet
//
//  Created by tt on 2020/9/2.
//

#import <UIKit/UIKit.h>
#import "ZCTradeView.h"
@interface WKPwdKeyboardInputView
    : ZCTradeView <ZCTradeViewDelegate>
// 输入完成block
@property (nonatomic, strong) void (^finishBlock)(NSString* pwd);
// 取消block
@property (nonatomic, strong) void (^cancelBlock)(void);
// 其他链接点击
@property (nonatomic, strong) void (^otherButtonClickBlock)(UIButton* btn);

- (void)show;
- (void) hiddenkeyboardViewCompletion:(void (^)(void))completion;

@end
