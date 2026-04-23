//
//  WKMeItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/6/9.
//

#import <WuKongBase/WuKongBase.h>
#import "WKFormItemCell.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKMeItemModel : WKFormItemModel
// 标题
@property(nonatomic,copy) NSString *title;
// icon图像
@property(nonatomic,strong) UIImage *icon;
// 右侧详情文字
@property(nonatomic,copy) NSString *detail;

@end

@interface WKMeItemCell : WKCell

@end

NS_ASSUME_NONNULL_END
