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

// 「我的表情」抖动编辑模式相关
@property(nonatomic,assign) BOOL editModeOn;
@property(nonatomic,strong) UIButton *deleteBadge; // 左上角 × 按钮
@property(nonatomic,weak)   id contextMenuContext;

@end

@implementation WKStickerGIFCell

@synthesize editModeOn = _editModeOn;
@synthesize contextMenuContext = _contextMenuContext;

- (WKSticker *)currentSticker {
    return self.sticker;
}

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

    // 复用时把编辑态还原为正常态：由 refresh: 后消费方按新数据重新决定
    if (_editModeOn) {
        [self setEditMode:NO];
    }
    self.onDeleteBadgeTap = nil;
    self.onCheck = nil;
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

    // × 徽章固定左上角，稍微超出 cell 边界让视觉更明显（iOS 桌面隐喻）
    if (_deleteBadge) {
        _deleteBadge.frame = CGRectMake(-6.0f, -6.0f, 22.0f, 22.0f);
    }
}

#pragma mark - 编辑态 / × 徽章

- (UIButton *)deleteBadge {
    if (!_deleteBadge) {
        _deleteBadge = [UIButton buttonWithType:UIButtonTypeSystem];
        _deleteBadge.frame = CGRectMake(-6.0f, -6.0f, 22.0f, 22.0f);
        _deleteBadge.backgroundColor = [UIColor colorWithWhite:0.15f alpha:0.9f];
        _deleteBadge.tintColor = [UIColor whiteColor];
        _deleteBadge.titleLabel.font = [UIFont systemFontOfSize:14.0f weight:UIFontWeightBold];
        [_deleteBadge setTitle:@"×" forState:UIControlStateNormal];
        [_deleteBadge setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _deleteBadge.layer.cornerRadius = 11.0f;
        _deleteBadge.layer.masksToBounds = YES;
        _deleteBadge.hidden = YES;
        // 稍微扩大命中区域
        _deleteBadge.contentEdgeInsets = UIEdgeInsetsMake(-2, 0, 0, 0);
        [_deleteBadge addTarget:self action:@selector(onDeleteBadgeTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_deleteBadge];
    }
    return _deleteBadge;
}

- (void)onDeleteBadgeTapped {
    if (self.onDeleteBadgeTap) self.onDeleteBadgeTap();
}

- (void)setEditMode:(BOOL)editing {
    if (_editModeOn == editing) return;
    _editModeOn = editing;
    self.deleteBadge.hidden = !editing;
    if (editing) {
        // 保持 hitTest 优先能点到 badge
        [self.contentView bringSubviewToFront:self.deleteBadge];
        CAKeyframeAnimation *wobble = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
        // 幅度 ~1° (0.017 rad)，autoreverses 让抖动更自然
        wobble.values = @[@(-0.020), @(0.020), @(-0.020)];
        wobble.duration = 0.16;
        wobble.repeatCount = HUGE_VALF;
        wobble.autoreverses = NO;
        // 随机相位差 —— 每张卡不同步，视觉更像抖动而非整齐晃动
        wobble.timeOffset = ((double)arc4random_uniform(160)) / 1000.0;
        [self.layer addAnimation:wobble forKey:@"wk_wobble"];
    } else {
        [self.layer removeAnimationForKey:@"wk_wobble"];
    }
}

#pragma mark - Context Menu 挂载

- (void)installContextMenuWithDelegate:(id<UIContextMenuInteractionDelegate>)delegate
                              context:(id)context API_AVAILABLE(ios(13.0)) {
    if (@available(iOS 13.0, *)) {
        // 幂等：先移除已注册的，再挂新的（cell 复用时可能被反复调用）
        [self uninstallContextMenu];
        UIContextMenuInteraction *inter = [[UIContextMenuInteraction alloc] initWithDelegate:delegate];
        [self.contentView addInteraction:inter];
        _contextMenuContext = context;
    }
}

- (void)uninstallContextMenu API_AVAILABLE(ios(13.0)) {
    if (@available(iOS 13.0, *)) {
        NSArray *interactions = [self.contentView.interactions copy];
        for (id<UIInteraction> ia in interactions) {
            if ([ia isKindOfClass:UIContextMenuInteraction.class]) {
                [self.contentView removeInteraction:ia];
            }
        }
        _contextMenuContext = nil;
    }
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
