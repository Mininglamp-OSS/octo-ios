//
//  WKIconSwitchButton.h
//  WuKongBase
//
//  Created by tt on 2022/11/1.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKIconSwitchButton : UIView

- (instancetype)initWithIconSize:(CGSize)size;

@property(nonatomic,assign) BOOL on; // 是否打开

@property(nonatomic,copy) void(^onSwitch)(BOOL on); // 切换

@property(nonatomic,strong) UIFont *titleFont;

@property(nonatomic,strong) UIImageView *onIconImgView; // 打开的icon
@property(nonatomic,strong) UIImageView *offIconImgView; // 关闭的icon

@property(nonatomic,strong) UILabel *onTitleLbl; // 打开的标题
@property(nonatomic,strong) UILabel *offTitleLbl; // 关闭的标题

@property(nonatomic,assign) CGFloat width;

@end

NS_ASSUME_NONNULL_END
