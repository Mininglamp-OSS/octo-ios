//
//  WKPwdKeyboardInputView.m
//  WuKongWallet
//
//  Created by tt on 2020/9/2.
//

#import "WKPwdKeyboardInputView.h"

@implementation WKPwdKeyboardInputView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.delegate = self;
    }
    return self;
}

- (void)show
{
    [self showInView:[[[UIApplication sharedApplication] delegate] window]];
}
- (void)hiddenkeyboardViewCompletion:(void (^)(void))completion
{
    self.hiddenView = ^{
        completion();
    };
}
/** 输入完成点击确定按钮 */
- (NSString*)finish:(NSString*)pwd
{
    if (_finishBlock) {
        _finishBlock(pwd);
    }
    return pwd;
}

/** 点击取消按钮 */
- (void)tradeView:(ZCTradeView*)tradeInputView
    cancleBtnClick:(UIButton*)cancleBtnClick
{
    if (self.cancelBlock) {
        self.cancelBlock();
    }
}

- (void)tradeView:(ZCTradeView*)tradeInputView
    registerBtnClick:(UIButton*)registerBtnClick
{
    if (self.cancelBlock) {
        self.cancelBlock();
    }
    if (self.otherButtonClickBlock) {
        self.otherButtonClickBlock(registerBtnClick);
    }
}


@end

