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

// YUJ-156 外部成员/群 `@SpaceName` 后缀 — viewer-relative 判定，字段契约与
// WKExternalExtrasKey*（`home_space_id` / `home_space_name` / `is_external` /
// `source_space_name`）对齐。字段可选，缺失时等同于非外部。
@property(nonatomic,copy,nullable) NSString *home_space_id;
@property(nonatomic,copy,nullable) NSString *home_space_name;
@property(nonatomic,strong,nullable) NSNumber *is_external; // legacy 降级路径
@property(nonatomic,copy,nullable) NSString *source_space_name; // legacy 降级路径

@end

@interface WKSearchContactsCell : WKFormItemCell

@end

NS_ASSUME_NONNULL_END
