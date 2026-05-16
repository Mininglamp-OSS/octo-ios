//
//  ZCTradeInputView.m
//  直销银行
//
//  Created by 塔利班 on 15/4/30.
//  Copyright (c) 2015年 联创智融. All rights reserved.
//

#define ZCTradeInputViewNumCount 6

// 快速生成颜色
#define ZCColor(r, g, b) [UIColor colorWithRed:(r) / 255.0 green:(g) / 255.0 blue:(b) / 255.0 alpha:1.0]

typedef enum {
    ZCTradeInputViewButtonTypeWithCancle = 10000,
    ZCTradeInputViewButtonTypeWithOk = 20000,
    ZCTradeInputViewButtonTypeRegisterBtn = 300000,
} ZCTradeInputViewButtonType;

#import "ZCTradeInputView.h"
#import "NSString+Extension.h"
#import "WKApp.h"
#import "WuKongBase.h"
@interface ZCTradeInputView ()
/** 数字数组 */
@property (nonatomic, strong) NSMutableArray* nums;
/** 确定按钮 */
@property (nonatomic, weak) UIButton* okBtn;
/** 取消按钮 */
@property (nonatomic, weak) UIButton* cancleBtn;
@property (nonatomic, weak) UIButton* registerBtn;
@property (nonatomic, strong) UIButton* bgButton;
@property (nonatomic, strong) UILabel* remarkLbl;

@end

@implementation ZCTradeInputView

#pragma mark - LazyLoad

- (NSMutableArray*)nums
{
    if (_nums == nil) {
        _nums = [NSMutableArray array];
    }
    return _nums;
}

#pragma mark - LifeCircle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = WKApp.shared.config.cellBackgroundColor;
        self.layer.cornerRadius = 10.0f;
        self.clipsToBounds = YES;
        /** 注册keyboard通知 */
        [self setupKeyboardNote];
        /** 添加子控件 */
        [self setupSubViews];

        [self registerButton];
    }
    return self;
}

/** 添加子控件 */
- (void)setupSubViews
{
    /** 取消按钮 */
    UIButton* cancleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self addSubview:cancleBtn];
    //    [cancleBtn setTitle:@"关闭" forState:UIControlStateNormal];
    [cancleBtn setImage:[self imageName:@"Common/Trade/zhifu-close"] forState:UIControlStateNormal];
    [cancleBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    self.cancleBtn = cancleBtn;
    [self.cancleBtn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    self.cancleBtn.tag = ZCTradeInputViewButtonTypeWithCancle;

    self.bgButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 70, 50)];
    self.bgButton.backgroundColor = [UIColor clearColor];
    self.bgButton.tag = ZCTradeInputViewButtonTypeWithCancle;

    [self.bgButton addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.bgButton];

    self.remarkLbl = [[UILabel alloc] init];
    self.remarkLbl.textColor = ZCColor(171, 170, 179);
    self.remarkLbl.font = [UIFont fontWithName:@"PingFangSC-Regular"
                                            size:13];
    self.remarkLbl.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.remarkLbl];

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.textColor = [UIColor blackColor];
    self.titleLbl.font = [UIFont fontWithName:@"Arial-BoldMT" size:36];
    self.titleLbl.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.titleLbl];
}
- (void)registerButton
{
    /** 取消按钮 */
    UIButton* registerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self addSubview:registerBtn];
    [registerBtn setTitle:[NSString stringWithFormat:@"%@", LLang(@"忘记密码")] forState:UIControlStateNormal];
    registerBtn.titleLabel.font = [UIFont fontWithName:@"PingFangSC-Regular" size:14];
    [registerBtn setTitleColor:[UIColor colorWithRed:28.0f / 255.0
                                               green:171.0 / 255.0
                                                blue:235.0 / 255.0
                                               alpha:1.0f] forState:UIControlStateNormal];
    self.registerBtn = registerBtn;
    [self.registerBtn addTarget:self action:@selector(registerBtn:) forControlEvents:UIControlEventTouchUpInside];
    self.registerBtn.tag = ZCTradeInputViewButtonTypeRegisterBtn;
}

//- (UILabel*)titleLabel
//{
//    if (!_titleLabel) {
//        _titleLabel = [[UILabel alloc] init];
//        _titleLabel.textAlignment = NSTextAlignmentCenter;
//    }
//    return _titleLabel;
//}
/** 注册keyboard通知 */
- (void)setupKeyboardNote
{
    // 删除通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(delete) name:ZCTradeKeyboardDeleteButtonClick object:nil];

    // 数字通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(number:) name:ZCTradeKeyboardNumberButtonClick object:nil];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.cancleBtn.width = 32 * ZCScreenWidth / 375.0;
    self.cancleBtn.height = self.cancleBtn.width;
    self.cancleBtn.x = self.size.width - self.cancleBtn.width - 10 * ZCScreenWidth / 375.0;
    self.cancleBtn.y = 5 * ZCScreenWidth / 375.0;

    [self.registerBtn sizeToFit];
    self.registerBtn.height = 20 * ZCScreenWidth / 375.0;
    self.registerBtn.x = self.frame.size.width - self.registerBtn.width - 12 * ZCScreenWidth / 375.0;
    self.registerBtn.y = 216 * ZCScreenWidth / 375.0;

    self.remarkLbl.width = self.frame.size.width;
    self.remarkLbl.height = 18 * ZCScreenWidth / 375.0;
    self.remarkLbl.x = 0;
    self.remarkLbl.y = 70 * ZCScreenWidth / 375.0;

    self.titleLbl.width = self.frame.size.width;
    self.titleLbl.height = 48 * ZCScreenWidth / 375.0;
    self.titleLbl.x = 0;
    self.titleLbl.y = 100 * ZCScreenWidth / 375.0;
    
//    self.titleLbl.font = [UIFont fontWithName:@"PingFangSC-Semibold" size:36];

    self.remarkLbl.text = self.remark;
    self.titleLbl.text = self.title;
}

- (void)clearInput
{
    [self.nums removeAllObjects];

    [self setNeedsDisplay];
}
#pragma mark - Private

// 删除
- (void)delete
{
    [self.nums removeLastObject];

    //    NSLog(@"delete nums %@ ",self.nums);

    [self setNeedsDisplay];
}

// 数字
- (void)number:(NSNotification*)note
{
    ;
    NSDictionary* userInfo = note.userInfo;
    NSString* numObj = userInfo[ZCTradeKeyboardNumberKey];
    if (numObj.length >= ZCTradeInputViewNumCount)
        return;
    [self.nums addObject:numObj];
    //    NSLog(@"数字 nums %@ ",self.nums);
    [self setNeedsDisplay];
}

// 按钮点击
- (void)btnClick:(UIButton*)btn
{
    if (btn.tag == ZCTradeInputViewButtonTypeWithCancle) { // 取消按钮点击
        if ([self.delegate respondsToSelector:@selector(tradeInputView:cancleBtnClick:)]) {

            [self.delegate tradeInputView:self cancleBtnClick:btn];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:ZCTradeInputViewCancleButtonClick object:self];
    }
}
- (void)registerBtn:(UIButton*)btn
{
    if (btn.tag == ZCTradeInputViewButtonTypeRegisterBtn) {
        if ([self.delegate respondsToSelector:@selector(tradeInputView:registerBtnClick:)]) {

            [self.delegate tradeInputView:self registerBtnClick:btn];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:ZCTradeInputViewCancleButtonClick object:self];
    }
}
- (void)drawRect:(CGRect)rect
{
    // 画图
    UIImage* field = [self imageName:@"Common/Trade/password_in"];

    //设置宽高
    CGFloat x = 12 * ZCScreenWidth / 375.0;
    CGFloat w = self.frame.size.width - x * 2;
    CGFloat h = w / 6.0;
    CGFloat y = self.frame.size.height - h - 48 * ZCScreenWidth / 375;

    [field drawInRect:CGRectMake(x, y, w, h)];

    // 画字
    NSString* title = LLang(@"请输入密码");
    UIFont* titleFont = [UIFont fontWithName:@"PingFangSC-Medium" size:16];

    CGSize size = [title sizeWithFont:titleFont andMaxSize:CGSizeMake(MAXFLOAT, MAXFLOAT)];
    CGFloat titleW = size.width;
    CGFloat titleH = 24 * ZCScreenWidth / 375.0;
    CGFloat titleX = (self.width - titleW) * 0.5;
    CGFloat titleY = 10 * ZCScreenWidth / 375.0;
    CGRect titleRect = CGRectMake(titleX, titleY, titleW, titleH);

    NSMutableDictionary* attr = [NSMutableDictionary dictionary];
    attr[NSFontAttributeName] = titleFont;
    attr[NSForegroundColorAttributeName] = WKApp.shared.config.defaultTextColor;
    [title drawInRect:titleRect withAttributes:attr];

    // 画点
    UIImage* pointImage = [self imageName:@"Common/Trade/yuan"];
    CGFloat pointW = ZCScreenWidth * 0.025;
    CGFloat pointH = pointW;
    //CGFloat pointY = self.frame.size.height-80 + (ZCScreenWidth * 0.121875 * 0.8)/2-(pointW/2);
    CGFloat pointY = y + h / 2 - pointW / 2;
    CGFloat pointX;
    CGFloat margin = (h / 2) - (pointW / 2);
    CGFloat padding = h;
    //pointX = 10+margin;
    for (int i = 0; i < self.nums.count; i++) {
        pointX = x + margin + padding * i;
        [pointImage drawInRect:CGRectMake(pointX, pointY, pointW, pointH)];
    }

    //    CGFloat pointW = ZCScreenWidth * 0.025;
    //    CGFloat pointH = pointW;
    //    CGFloat pointY = self.frame.size.height-63;//ZCScreenWidth * 0.24+8;
    //    CGFloat pointX;
    //    CGFloat margin = ZCScreenWidth * 0.0484375 * 0;
    //    CGFloat padding = ZCScreenWidth * 0.045578125;
    //    for (int i = 0; i < self.nums.count; i++) {
    //        pointX = margin + padding + i * (pointW + 2 * padding)+0.5;
    //        [pointImage drawInRect:CGRectMake(pointX, pointY, pointW, pointH)];
    //    }

    // ok按钮状态
    BOOL statue = NO;
    if (self.nums.count == ZCTradeInputViewNumCount) {
        statue = YES;
    } else {
        statue = NO;
    }
    self.okBtn.enabled = statue;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}
@end
