//
//  WKLabelItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/21.
//

#import "WKLabelItemCell.h"
#import "WKResource.h"
#import "WKApp.h"
#import "UIView+WK.h"
#import "WKConstant.h"

@interface WKLabelItemModel ()

@end

@implementation WKLabelItemModel

+(instancetype) initWith:(NSString*)label value:(NSString*) value onClick:(void(^)(WKFormItemModel* model,NSIndexPath *indexPath))onClick {
    WKLabelItemModel *model = [WKLabelItemModel new];
    model.label = label;
    model.value = value;
    model.onClick = onClick;
    return model;
}

+(instancetype) initWith:(NSString*)label value:(NSString*) value {
    ;
    return [self initWith:label value:value];
}

- (Class)cell {
    return WKLabelItemCell.class;
}

- (UIFont *)valueFont {
    if(!_valueFont) {
        _valueFont =[[WKApp shared].config appFontOfSize:16.0f];
    }
    return _valueFont;
}

@end


@interface WKLabelItemCell ()


@end

@implementation WKLabelItemCell

- (void)setupUI {
    [super setupUI];
  
    self.valueLbl = [[WKCopyLabel alloc] init];
    self.valueLbl.textAlignment = NSTextAlignmentRight;
    [self.valueLbl setTextColor:[UIColor colorWithRed:153.0f/255.0f green:153.0f/255.0f blue:153.0f/255.0f alpha:1.0f]];
    
    [self.valueView addSubview:self.valueLbl];
}

- (void)refresh:(WKLabelItemModel *)model {
    [super refresh:model];
    
    [self.valueLbl setFont:model.valueFont];
    self.valueLbl.text = model.value;
    self.valueLbl.copyEnabled = model.valueCopy;
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.valueLbl.lim_size = self.valueView.lim_size;
    
}

@end
