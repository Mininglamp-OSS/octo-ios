//
//  WKIconButton.h
//  WuKongBase
//
//  Created by tt on 2022/11/1.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKIconButton : UIView

@property(nonatomic,strong) UIImageView *imageView;
@property(nonatomic,strong) UILabel *titleLbl;

@property(nonatomic,assign) CGFloat width;

@property(nonatomic,copy) void(^onClick)(void);

@end

NS_ASSUME_NONNULL_END
