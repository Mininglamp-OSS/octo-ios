//
//  WKSearchContactsCell.h
//  WuKongBase
//
//  Created by tt on 2020/4/25.
//

#import "WKFormItemCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface WKSearchContactsModel : WKFormItemModel

@property(nonatomic,copy) NSString *avatar; // 头像
@property(nonatomic,copy) NSString *name; // 昵称
@property(nonatomic,copy) NSString *contain; // 包含的关键字
@property(nonatomic,copy) NSString *keyword; //变色的文字

@end

@interface WKSearchContactsCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
