//
//  WKStickerGIFCell.m
//  WuKongBase
//
//  Created by tt on 2020/2/1.
//

#import "WKStickerGIFCell.h"
#import <SDWebImage/SDWebImage.h>
#import "WKStickerBigViewModal.h"
#import "WKStickerImageView.h"
#import <WuKongBase/WuKongBase-Swift.h>
#import "WKCheckBox.h"
@interface WKStickerGIFCell ()<WKCheckBoxDelegate>
@property(nonatomic,strong) WKStickerImageView *stickerImageView;

@property(nonatomic,strong) WKStickerBigViewModal *stickerBigViewModal;


@property(nonatomic,strong) WKSticker *sticker;

@property(nonatomic,strong) WKCheckBox *checkBox;

@property(nonatomic,strong) UITapGestureRecognizer *tapGesture;

@end

@implementation WKStickerGIFCell

+(NSString *)reuseIdentifier
{
    return NSStringFromClass(self);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.stickerImageView = [[WKStickerImageView alloc] initWithFrame:CGRectMake(0, 0,frame.size.width,frame.size.height)];
        [self.contentView addSubview:self.stickerImageView];

        
//        self.contentView.userInteractionEnabled = YES;
        UILongPressGestureRecognizer *longTapGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onStickerLongTap:)];
        [self.contentView addGestureRecognizer:longTapGesture];
        
        self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStickerTap)];
        
        
        
//        _selectedBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
//        UIImage *unEditImage = [[WKResource shared] resourceForImage:@"sticker_UnEdit" podName:@"WuKongBase_images"];
//        UIImage *editImage = [[WKResource shared] resourceForImage:@"sticker_edit" podName:@"WuKongBase_images"];
//        [_selectedBtn setImage:unEditImage forState:UIControlStateNormal];
//        [_selectedBtn setImage:editImage forState:UIControlStateSelected];
//        [_selectedBtn addTarget:self action:@selector(selectedBtnEvent:) forControlEvents:UIControlEventTouchUpInside];
//        _selectedBtn.selected = NO;
//        _selectedBtn.hidden = YES;
//        [self addSubview:_selectedBtn];
        
        self.checkBox = [[WKCheckBox alloc] initWithFrame:CGRectMake(0, 0, 24.0f, 24.0f)];
        self.checkBox.onFillColor = [WKApp shared].config.themeColor;
        self.checkBox.onCheckColor = [UIColor whiteColor];
        self.checkBox.onAnimationType = BEMAnimationTypeBounce;
        self.checkBox.offAnimationType = BEMAnimationTypeBounce;
        self.checkBox.animationDuration = 0.0f;
        self.checkBox.lineWidth = 1.0f;
    //    self.checkBox.tintColor = [UIColor grayColor];
        self.checkBox.delegate = self;
        [self addSubview:self.checkBox];
    
        
    }
    return self;
}

-(void) onWillDisplay {
    if(self.sticker.isPlay) { // 当前sticker所在的面板选中状态下才播动画
        self.stickerImageView.isPlay = true;
    }else {
        self.stickerImageView.isPlay = false;
    }
    
}

-(void) onEndDisplay {
    self.stickerImageView.isPlay = false;
}
-(void) onStickerLongTap:(UILongPressGestureRecognizer*)gesture {
    if(!self.allowLongPress) {
        return;
    }
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.stickerBigViewModal = [WKStickerBigViewModal focusedView:self.stickerImageView sticker:self.sticker];
        [self.stickerBigViewModal presentOnWindow:[UIApplication sharedApplication].keyWindow];
    }
}

-(void) onStickerTap {
    self.checkBox.on = !self.checkBox.on;
    self.sticker.isSelected = self.checkBox.on;
    if(self.onCheck) {
        self.onCheck(self.checkBox.on);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
//    [self.stickerImageView stopAnimating];
//    self.stickerImageView.image = nil;
//    self.stickerImageView.animationImages = nil;

    self.stickerImageView.isPlay = NO;
    self.stickerBigViewModal = nil;
    
    
}


-(void) refresh:(WKSticker*)sticker {
    self.sticker = sticker;
    
    self.stickerImageView.placehoderSvg = sticker.placeholder;
    self.stickerImageView.stickerURL = [[WKApp shared] getFileFullUrl:sticker.path];

    
    self.checkBox.on = sticker.isSelected;
    self.checkBox.hidden = YES;
    if (sticker.isEdit) {
        self.checkBox.hidden = NO;
        [self.contentView addGestureRecognizer:self.tapGesture];
    }else {
        [self.contentView removeGestureRecognizer:self.tapGesture];
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.stickerImageView.lim_left = self.lim_width/2.0f - self.stickerImageView.lim_width/2.0f;
    self.stickerImageView.lim_top = self.lim_height/2.0f - self.stickerImageView.lim_height / 2.0f;
    
    self.checkBox.lim_top = 0.0f;
    self.checkBox.lim_left = self.stickerImageView.lim_width -self.checkBox.lim_width;
}

#pragma mark -> WKCheckBoxDelegate
- (void)selectedBtnEvent:(UIButton *)sender {
   
}

- (void)didTapCheckBox:(WKCheckBox*)checkBox {
    self.sticker.isSelected = checkBox.on;
    if(self.onCheck) {
        self.onCheck(checkBox.on);
    }
}

@end
