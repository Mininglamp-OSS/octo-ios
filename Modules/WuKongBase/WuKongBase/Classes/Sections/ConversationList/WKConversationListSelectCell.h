//
//  WKConversationListSelectCell.h
//  WuKongBase
//
//  Created by tt on 2020/9/28.
//

#import <WuKongBase/WuKongBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKConversationListSelectModel : WKFormItemModel
// 标题
@property(nonatomic,copy) NSString *title;

@property(nonatomic,copy) NSString *value;
// icon宽度
@property(nonatomic,strong) NSNumber *width;
// icon高度
@property(nonatomic,strong) NSNumber *height;
// icon的url
@property(nonatomic,copy) NSString *iconURL;
// icon图像
@property(nonatomic,strong) UIImage *icon;

// icon是否显示为圆形
@property(nonatomic,assign) BOOL circular;
// 是否被选中
@property(nonatomic,assign) BOOL selected;


/// 是否开启多选
@property(nonatomic,assign) BOOL multiple;

@end

@interface WKConversationListSelectCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
