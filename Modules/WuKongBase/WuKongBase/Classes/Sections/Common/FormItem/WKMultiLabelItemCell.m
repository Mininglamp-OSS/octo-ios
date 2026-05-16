//
//  WKMulitLabelItemCell.m
//  WuKongBase
//
//  Created by tt on 2020/1/30.
//

#import "WKMultiLabelItemCell.h"
#import "WKResource.h"
#import "WKApp.h"
@implementation WKMultiLabelItemModel

- (Class)cell {
    return WKMultiLabelItemCell.class;
}

@end

@interface WKMultiLabelItemCell ()

@property(nonatomic,strong) UILabel *labelLbl;
@property(nonatomic,strong) UILabel *valueLbl;

@property(nonatomic,strong) WKMultiLabelItemModel *multilModel;

@end

#define WKMultiValueFontSize 15.0f
#define WKMultiLabelFontSize 17.0f

#define WKMultiValueMaxWidth WKScreenWidth - 40.0f

#define WKMultiValueMaxWidthWithLeftRight 240.0f

#define WKMultiLabelTopSpace 10.0f
#define WKMultiValueTopSpace 10.0f
#define WKMultiValueBottomSpace 10.0f

#define WKultiValueMaxHeight 70.0f


@implementation WKMultiLabelItemCell

+(CGSize) sizeForModel:(WKMultiLabelItemModel*)model{
    CGSize labelSize = [self getTextSize:model.label maxWidth:WKScreenWidth maxHeight:MAXFLOAT fontSize:WKMultiLabelFontSize];
    if(model.value) {
        CGFloat maxWidth = WKMultiValueMaxWidth;
       
        if(model.mode && [model.mode integerValue] == WKMultiLabelItemModeLeftRight) {
            maxWidth = WKMultiValueMaxWidthWithLeftRight;
            
        }
        CGSize valueSize = [self getTextSize:model.value?:@"" maxWidth:maxWidth maxHeight:WKultiValueMaxHeight fontSize:WKMultiValueFontSize];
        
        CGFloat height = WKMultiLabelTopSpace + labelSize.height + WKMultiValueTopSpace + valueSize.height + WKMultiValueBottomSpace+4.0f;
        if(model.mode && [model.mode integerValue] == WKMultiLabelItemModeLeftRight) {
            height = valueSize.height + 20.0f;
        }
        
        return CGSizeMake(WKScreenWidth,MAX(height, model.cellHeight));
    }
    return  CGSizeMake(WKScreenWidth, 54.0f);
   
}

- (void)setupUI {
    [super setupUI];
    self.labelLbl = [[UILabel alloc] init];
    [self.labelLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self addSubview:self.labelLbl];
    
    self.valueLbl = [[UILabel alloc] init];
    [self.valueLbl setFont:[[WKApp shared].config appFontOfSize:WKMultiValueFontSize]];
    self.valueLbl.numberOfLines = 3;
    self.valueLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.valueLbl setTextColor:[UIColor grayColor]];
    [self addSubview:self.valueLbl];
    
}

-(void) refresh:(WKMultiLabelItemModel *)model {
    [super refresh:model];
    self.multilModel = model;
    self.labelLbl.text = model.label;
    [self.labelLbl sizeToFit];
    
    [self.labelLbl setTextColor:[WKApp shared].config.defaultTextColor];
    
    self.valueLbl.text = model.value;
    
}

-(WKMultiLabelItemMode) getMode {
    if(!self.multilModel.mode) {
        return WKMultiLabelItemModeUpDown;
    }
    return [self.multilModel.mode integerValue];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat labelLeft = 15.0f;
    
    self.labelLbl.lim_left = labelLeft;
    
    if([self getMode] == WKMultiLabelItemModeLeftRight) {
        self.labelLbl.lim_centerY_parent = self.contentView;
    }else {
        self.labelLbl.lim_top = WKMultiLabelTopSpace;
    }
    
    CGFloat arrowRight = 10.0f;
    self.arrowImgView.lim_left = self.lim_width - arrowRight - self.arrowImgView.lim_width;
    
    

    if([self getMode] == WKMultiLabelItemModeLeftRight) {
        CGFloat valueTop = WKMultiValueTopSpace;
        
        self.valueLbl.lim_centerY_parent = self.contentView;
        self.valueLbl.lim_width = WKMultiValueMaxWidthWithLeftRight;
        [self.valueLbl sizeToFit];
        self.valueLbl.lim_left = self.contentView.lim_width - self.valueLbl.lim_width - 15.0f;
    }else{
        CGFloat valueTop = WKMultiValueTopSpace;
        self.valueLbl.lim_left = self.labelLbl.lim_left;
        self.valueLbl.lim_top = self.labelLbl.lim_bottom + valueTop;
        self.valueLbl.lim_width = WKMultiValueMaxWidth;
        [self.valueLbl sizeToFit];
    }
    
    self.arrowImgView.lim_top = self.valueLbl.lim_top +  ( self.valueLbl.lim_height/2.0f - self.arrowImgView.lim_height/2.0f);
    
}


-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

+ (CGSize) getTextSize:(NSString*) text maxWidth:(CGFloat)maxWidth maxHeight:(CGFloat)maxHeight fontSize:(CGFloat)fontSize{
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    style.lineBreakMode = NSLineBreakByCharWrapping;
    style.alignment = NSTextAlignmentCenter;
    NSAttributedString *string = [[NSAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:fontSize], NSParagraphStyleAttributeName:style}];
    CGSize size =  [string boundingRectWithSize:CGSizeMake(maxWidth, maxHeight) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil].size;
    return size;
}

@end
