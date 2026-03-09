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

+(instancetype) initWith:(NSString*)label value:(NSString*) value;

+(instancetype) initWith:(NSString*)label value:(NSString*) value onClick:(void(^)(WKFormItemModel* model,NSIndexPath *indexPath))onClick;

@end


@interface WKLabelItemCell : WKViewItemCell


@property(nonatomic,strong) WKCopyLabel *valueLbl;

@end

NS_ASSUME_NONNULL_END
