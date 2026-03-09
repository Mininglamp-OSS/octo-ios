//
//  WKSearchMoreCell.m
//  WuKongBase
//
//  Created by tt on 2020/5/10.
//

#import "WKSearchMoreCell.h"
#import "WKApp.h"
@implementation WKSearchMoreModel

- (Class)cell {
    return WKSearchMoreCell.class;
}

- (NSNumber *)showArrow {
    return @(NO);
}
@end

@interface WKSearchMoreCell ()

@property(nonatomic,strong) UILabel *placeholderLbl;
@property(nonatomic,strong) UIImageView *iconImgView;

@end

@implementation WKSearchMoreCell

+ (CGSize)sizeForModel:(WKFormItemModel *)model {
    return CGSizeMake(WKScreenWidth, 18.0f + 10.0f + 10.0f);
}

- (void)setupUI {
    [super setupUI];
    
    self.placeholderLbl = [[UILabel alloc] init];
    [self.placeholderLbl setFont:[UIFont systemFontOfSize:14.0f]];
    [self.placeholderLbl setTextColor:[UIColor colorWithRed:90.0f/255.0f green:112.0f/255.0f blue:149.0f/255.0f alpha:1.0f]];
    [self addSubview:self.placeholderLbl];
    
    self.iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 18.0f, 18.0f)];
    [self.iconImgView setImage:[self imageName:@"ConversationList/Index/IconSearch"]];
    [self addSubview:self.iconImgView];
}

- (void)refresh:(WKSearchMoreModel *)model {
    [super refresh:model];
    
    self.placeholderLbl.text = model.placeholder;
    [self.placeholderLbl sizeToFit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.iconImgView.lim_left = 20.0f;
    self.iconImgView.lim_top = self.lim_height/2.0f - self.iconImgView.lim_height/2.0f;
    
    
    self.placeholderLbl.lim_left = self.iconImgView.lim_right + 10.0f;
    self.placeholderLbl.lim_top = self.lim_height/2.0f - self.placeholderLbl.lim_height/2.0f;
}

-(UIImage*) imageName:(NSString*)name {
    return [WKApp.shared loadImage:name moduleID:@"WuKongBase"];
//    return [[WKResource shared] resourceForImage:name podName:@"WuKongBase_images"];
}

@end
