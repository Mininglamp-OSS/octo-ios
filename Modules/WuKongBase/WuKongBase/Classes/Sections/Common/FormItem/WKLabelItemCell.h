//
//  WKLabelItemCell.h
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import "WKFormItemCell.h"
#import "WKCopyLabel.h"
#import "WKFormItemModel.h"
#import "WKViewItemCell.h"
NS_ASSUME_NONNULL_BEGIN

@interface WKLabelItemModel : WKViewItemModel

@property(nonatomic,copy) NSString *value;

@property(nonatomic,strong) UIFont *valueFont;

@property(nonatomic,assign) BOOL valueCopy; // value是否允许复制

@property(nonatomic,copy,nullable) NSString *tagText; // 紧贴 value 显示的小标签（如「外部群」），为空则不显示
@property(nonatomic,strong,nullable) UIColor *tagBackgroundColor; // 标签背景色，nil 则用主题色
@property(nonatomic,strong,nullable) UIColor *tagTextColor; // 标签文字色，nil 则白色

+(instancetype) initWith:(NSString*)label value:(NSString*) value;

+(instancetype) initWith:(NSString*)label value:(NSString*) value onClick:(void(^)(WKFormItemModel* model,NSIndexPath *indexPath))onClick;

@end


@interface WKLabelItemCell : WKViewItemCell


@property(nonatomic,strong) WKCopyLabel *valueLbl;
@property(nonatomic,strong) UILabel *tagLbl; // 紧贴 valueLbl 之后的小标签

@end

NS_ASSUME_NONNULL_END
