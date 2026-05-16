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

    self.tagLbl = [[UILabel alloc] init];
    self.tagLbl.textAlignment = NSTextAlignmentCenter;
    self.tagLbl.font = [[WKApp shared].config appFontOfSize:11.0f];
    self.tagLbl.textColor = [UIColor whiteColor];
    self.tagLbl.layer.cornerRadius = 4.0f;
    self.tagLbl.layer.masksToBounds = YES;
    self.tagLbl.hidden = YES;
    [self.valueView addSubview:self.tagLbl];
}

- (void)refresh:(WKLabelItemModel *)model {
    [super refresh:model];

    [self.valueLbl setFont:model.valueFont];
    self.valueLbl.text = model.value;
    self.valueLbl.copyEnabled = model.valueCopy;

    if(model.tagText && model.tagText.length > 0) {
        self.tagLbl.hidden = NO;
        self.tagLbl.text = model.tagText;
        self.tagLbl.backgroundColor = model.tagBackgroundColor ?: [UIColor colorWithRed:255.0f/255.0f green:149.0f/255.0f blue:0.0f/255.0f alpha:1.0f];
        self.tagLbl.textColor = model.tagTextColor ?: [UIColor whiteColor];
    } else {
        self.tagLbl.hidden = YES;
        self.tagLbl.text = nil;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if(!self.tagLbl.hidden) {
        // 标签紧贴在 value 右侧，整体右对齐到 valueView 末端
        CGSize tagFitSize = [self.tagLbl sizeThatFits:CGSizeMake(CGFLOAT_MAX, self.valueView.lim_height)];
        CGFloat tagWidth = MAX(tagFitSize.width + 10.0f, 32.0f);
        CGFloat tagHeight = MIN(MAX(tagFitSize.height + 4.0f, 18.0f), self.valueView.lim_height - 8.0f);
        CGFloat valueGap = 6.0f;
        CGFloat valueWidth = MAX(self.valueView.lim_width - tagWidth - valueGap, 0.0f);
        self.valueLbl.lim_size = CGSizeMake(valueWidth, self.valueView.lim_height);
        self.valueLbl.lim_top = 0.0f;
        self.valueLbl.lim_left = 0.0f;
        self.tagLbl.lim_size = CGSizeMake(tagWidth, tagHeight);
        self.tagLbl.lim_top = (self.valueView.lim_height - tagHeight) / 2.0f;
        self.tagLbl.lim_left = self.valueView.lim_width - tagWidth;
    } else {
        self.valueLbl.lim_size = self.valueView.lim_size;
        self.valueLbl.lim_top = 0.0f;
        self.valueLbl.lim_left = 0.0f;
    }
}

@end
