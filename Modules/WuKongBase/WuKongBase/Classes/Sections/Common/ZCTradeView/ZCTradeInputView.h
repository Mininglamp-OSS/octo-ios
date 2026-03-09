//
//  ZCTradeInputView.h
//  直销银行
//
//  Created by 塔利班 on 15/4/30.
//  Copyright (c) 2015年 联创智融. All rights reserved.
//  交易输入视图

#import <Foundation/Foundation.h>

static NSString* ZCTradeInputViewCancleButtonClick = @"ZCTradeInputViewCancleButtonClick";
static NSString* ZCTradeInputViewOkButtonClick = @"ZCTradeInputViewOkButtonClick";
static NSString* ZCTradeInputViewPwdKey = @"ZCTradeInputViewPwdKey";

static NSString* ZCTradeKeyboardDeleteButtonClick = @"ZCTradeKeyboardDeleteButtonClick";
static NSString* ZCTradeKeyboardOkButtonClick = @"ZCTradeKeyboardOkButtonClick";
static NSString* ZCTradeKeyboardNumberButtonClick = @"ZCTradeKeyboardNumberButtonClick";
static NSString* ZCTradeKeyboardNumberKey = @"ZCTradeKeyboardNumberKey";

#import <UIKit/UIKit.h>
#import "UIView+Extension.h"
#import "ZCTradeView.h"
//typedef enum{
//    RedPackType = 0,
//    TranfserType,
//    GamePay,
//
//}PayType;

@class ZCTradeInputView;
@protocol ZCTradeInputViewDelegate <NSObject>

@optional
/** 确定按钮点击 */
- (void)tradeInputView:(ZCTradeInputView*)tradeInputView okBtnClick:(UIButton*)okBtn;
/** 取消按钮点击 */
- (void)tradeInputView:(ZCTradeInputView*)tradeInputView cancleBtnClick:(UIButton*)cancleBtn;
/** 忘记密码 */

- (void)tradeInputView:(ZCTradeInputView*)tradeInputView registerBtnClick:(UIButton*)registerBtn;

@end

@interface ZCTradeInputView : UIView
@property (nonatomic, strong) UILabel* titleLbl;
@property (nonatomic, weak) id<ZCTradeInputViewDelegate> delegate;
@property (nonatomic, copy) NSString* title;
@property(nonatomic,copy) NSString *remark;
-(void) clearInput;
@end
