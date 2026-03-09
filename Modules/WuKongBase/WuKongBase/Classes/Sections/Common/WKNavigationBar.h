//
//  WKNavigationBar.h
//  WuKongBase
//
//  Created by tt on 2020/6/19.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    WKNavigationBarStyleDefault, // 默认样式
    WKNavigationBarStyleWhite, // 白色样式
    WKNavigationBarStyleDark, // 深色模式
} WKNavigationBarStyle;

@interface WKNavigationBar : UIView

@property(nonatomic,strong) UILabel *titleLabel;
@property(nonatomic,strong) UILabel *subtitleLabel;
@property(nonatomic,strong) UIButton *backButton;

/// 导航栏标题
@property(nonatomic,copy) NSString *title;


/// 子标题
@property(nonatomic,copy,nullable) NSString *subtitle;

/// 右边视图
@property(nonatomic,strong) UIView *rightView;


/// 右边视图frame
@property(nonatomic,assign) CGRect rightViewFrame;


/// 显示返回按钮
@property(nonatomic,assign) BOOL showBackButton;


/// 是否开启大标题模式
@property(nonatomic,assign) BOOL largeTitle;

// 样式
@property(nonatomic,assign) WKNavigationBarStyle style;


/// 返回点击
@property(nonatomic,strong) void(^onBack)(void);

@end

NS_ASSUME_NONNULL_END
