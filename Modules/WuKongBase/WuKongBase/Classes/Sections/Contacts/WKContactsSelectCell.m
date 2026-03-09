//
//  WKContactsSelectCell.m
//  WuKongContacts
//
//  Created by tt on 2019/12/8.
//

#import "WKContactsSelectCell.h"
#import "WKContacts.h"
#import "WuKongBase.h"
@implementation WKContactsSelect



@end

@interface WKContactsSelectCell()<WKCheckBoxDelegate>



@end
@implementation WKContactsSelectCell



-(void) setupUI{
    [super setupUI];
    self.bottomLineView.hidden = YES;
    _avatarImgView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, 45.0f, 45.0f)];
    [self.contentView addSubview:_avatarImgView];
    
    _nameLbl = [[UILabel alloc] init];
    [_nameLbl setFont:[[WKApp shared].config appFontOfSize:16.0f]];
    [self addSubview:_nameLbl];
    
    self.checkBox = [[WKCheckBox alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
    self.checkBox.onFillColor = [WKApp shared].config.themeColor;
    self.checkBox.onCheckColor = [UIColor whiteColor];
    self.checkBox.onTintColor = [WKApp shared].config.themeColor;
    self.checkBox.onAnimationType = BEMAnimationTypeBounce;
    self.checkBox.offAnimationType = BEMAnimationTypeBounce;
    self.checkBox.animationDuration = 0.0f;
    self.checkBox.lineWidth = 1.0f;
//    self.checkBox.tintColor = [UIColor grayColor];
    self.checkBox.delegate = self;
    [self addSubview:self.checkBox];
    
}

+(NSString*) cellId{
    return @"WKContactsSelectCell";
}

-(void) refreshWithModel:(id)cellModel{
    _contactSelectModel = cellModel;
    
    [self.nameLbl setTextColor:[WKApp shared].config.defaultTextColor];
    
    self.avatarImgView.url = _contactSelectModel.avatar;
    self.nameLbl.text = _contactSelectModel.displayName;
    [self.nameLbl sizeToFit];
    self.checkBox.on = self.contactSelectModel.selected;
    
    if(_contactSelectModel.mode == WKContactsModeSingle) {
        self.checkBox.hidden = YES;
        self.avatarImgView.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.nameLbl.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
    }else {
        self.checkBox.hidden = NO;
        self.checkBox.userInteractionEnabled = !_contactSelectModel.disable;
        self.checkBox.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.avatarImgView.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
        self.nameLbl.alpha = _contactSelectModel.disable ? 0.5 : 1.0;
    }
    
   
    
//    if(_contactSelectModel.first) {
//        self.topLineView.hidden = NO;
//    }else {
//        self.topLineView.hidden = YES;
//    }
}


- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat avatarLeft = 10.0f;
    CGFloat nameLeft = 10.0f;
    CGFloat checkBoxLeft = 10.0f;
    self.checkBox.lim_left = checkBoxLeft;
    self.checkBox.lim_top = self.lim_height/2.0f - self.checkBox.lim_height/2.0f;
    if(_contactSelectModel.mode == WKContactsModeSingle) {
        self.avatarImgView.lim_left =  avatarLeft;
    }else {
        self.avatarImgView.lim_left = self.checkBox.lim_right + avatarLeft;
    }
    
    self.avatarImgView.lim_top = self.lim_height/2.0f - self.avatarImgView.lim_height/2.0f;
    self.nameLbl.lim_left = self.avatarImgView.lim_right + nameLeft;
    self.nameLbl.lim_top = self.lim_height/2.0f - self.nameLbl.lim_height/2.0f;
    
//    if(_contactSelectModel.last) {
//        self.bottomLineView.lim_left =  0;
//        self.bottomLineView.lim_width = self.lim_width;
//    }else {
//        self.bottomLineView.lim_left = self.nameLbl.lim_left;
//        self.bottomLineView.lim_width = self.lim_width - self.nameLbl.lim_left;
//    }
    
}

#pragma mark - WKCheckBoxDelegate
- (void)didTapCheckBox:(WKCheckBox*)checkBox {
    self.contactSelectModel.selected = checkBox.on;
    if(_stateChangeCheckBk) {
        _stateChangeCheckBk(self.contactSelectModel);
    }
}
@end
