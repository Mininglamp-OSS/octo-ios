//
//  WKLabelCell.m
//  WuKongWallet
//
//  Created by tt on 2020/9/16.
//

#import "WKLabelCell.h"
#import "WKApp.h"
@implementation WKLabelModel

- (Class)cell {
    return WKLabelCell.class;
}

- (UIFont *)font {
    if(!_font) {
        _font = [[WKApp shared].config appFontOfSize:14.0f];
    }
    return _font;
}

- (UIColor *)textColor {
    if(!_textColor) {
        _textColor = [WKApp shared].config.tipColor;
    }
    return _textColor;
}

- (NSNumber *)left {
    if(!_left) {
        _left = @(15.0f);
    }
    return _left;
}
@end

@interface WKLabelCell ()

@property(nonatomic,strong) UILabel *lbl;

@property(nonatomic,strong) WKLabelModel *model;


@end

@implementation WKLabelCell

+ (CGSize)sizeForModel:(WKLabelModel *)model {
    CGFloat width = WKScreenWidth-  model.left.floatValue*2;
    if(model.width && model.width.floatValue>0) {
        width = model.width.floatValue;
    }
    CGSize size = [self getTextSize:model.text maxWidth:(width) font:model.font];
    return size;
}

- (void)setupUI {
    [super setupUI];
    [self setBackgroundColor:[UIColor clearColor]];
    [self.contentView addSubview:self.lbl];
}

- (void)refresh:(WKLabelModel *)model {
    [super refresh:model];
    self.model = model;
    
    self.lbl.font =model.font;
    self.lbl.textColor = model.textColor;
    self.lbl.text = model.text;
   
    
    CGFloat width = WKScreenWidth - model.left.floatValue*2;
    if(model.width && model.width.floatValue>0) {
        width = model.width.floatValue;
    }
    self.lbl.lim_width = width;
    
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.lbl sizeToFit];
    self.lbl.lim_left = self.model.left.floatValue;
    if(self.model.center) {
        self.lbl.lim_left = self.contentView.lim_width/2.0f - self.lbl.lim_width/2.0f;
    }
    
}

- (UILabel *)lbl {
    if(!_lbl) {
        _lbl = [[UILabel alloc] init];
        _lbl.numberOfLines = 0;
        _lbl.lineBreakMode = NSLineBreakByCharWrapping;
    }
    return _lbl;
}


//
//+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth  fontSize:(CGFloat)fontSize{
//    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
//    style.lineBreakMode = NSLineBreakByCharWrapping;
//    style.alignment = NSTextAlignmentCenter;
//    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:fontSize], NSParagraphStyleAttributeName:style}];
//    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
//    return size;
//}

+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth  font:(UIFont*)font {
    // 设置文字属性 要和label的一致
    NSDictionary *attrs = @{NSFontAttributeName :font};
    CGSize maxSize = CGSizeMake(maxWidth, MAXFLOAT);

    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading;

    // 计算文字占据的宽高
    CGSize size = [text boundingRectWithSize:maxSize options:options attributes:attrs context:nil].size;

   // 当你是把获得的高度来布局控件的View的高度的时候.size转化为ceilf(size.height)。
    return  size;
}

@end
