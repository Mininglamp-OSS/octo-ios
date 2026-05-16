//
//  WKContactsAddFunctionItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/6/22.
//

#import <UIKit/UIKit.h>
#import <WuKongBase/WuKongBase.h>
NS_ASSUME_NONNULL_BEGIN

@interface WKContactsAddFunctionItemModel : WKFormItemModel
// 标题
@property(nonatomic,copy) NSString *title;
// 子标题
@property(nonatomic,copy) NSString *subtitle;
// icon图像
@property(nonatomic,strong) UIImage *icon;

@end

@interface WKContactsAddFunctionItemCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
