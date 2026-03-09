//
//  WKActionSheetView2.m
//  WuKongBase
//
//  Created by tt on 2020/6/21.
//

#import "WKActionSheetView2.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WuKongBase.h"
@interface WKActionSheetView2 ()
@property(nonatomic,strong) NSString *cancelBtnTitle;
@property(nonatomic,strong) UIView *sheetView;

@property(nonatomic,strong) WKActionSheetCancelItem2 *cancelItem;
@property(nonatomic,strong) WKActionSheetTipItem2 *tipItem;
@property(nonatomic,strong) NSMutableArray<WKActionSheetItem2*> *items;
@end

@implementation WKActionSheetView2

+ (WKActionSheetView2 *)initWithTip:(NSString *)tip {
   
    return [WKActionSheetView2 initWithTip:tip cancel:nil];
}

+ (WKActionSheetView2 *)initWithCancel:(NSString *)cancelBtnTitle {
   return [WKActionSheetView2 initWithTip:nil cancel:cancelBtnTitle];
}

+ (WKActionSheetView2 *)initWithTip:(NSString *)tip cancel:(NSString *)cancelBtnTitle {
    WKActionSheetView2 *sheet = [[WKActionSheetView2 alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if(tip) {
        sheet.tipItem =[WKActionSheetTipItem2 initWithTip:tip];
        [sheet addItem:sheet.tipItem];
    }
    sheet.cancelBtnTitle = cancelBtnTitle?:LLang(@"取消");
    
    // 背景覆盖视图
    sheet.backgroundColor = [UIColor blackColor];
    UIWindow *window = [WKApp.shared findWindow];
    [window addSubview:sheet];
    sheet.alpha = 0.0;
    
    [window addSubview:sheet.sheetView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:sheet action:@selector(coverClick)];
    [sheet addGestureRecognizer:tap];
    
    return sheet;
}


- (WKActionSheetCancelItem2 *)cancelItem {
    if(!_cancelItem) {
        __weak typeof(self) weakSelf = self;
        _cancelItem = [WKActionSheetCancelItem2 initWithTitle:self.cancelBtnTitle onClick:^{
            [weakSelf coverClick];
        }];
    }
    return _cancelItem;
}

-(void) layoutUI {
    CGFloat sheetHeight = 0;
    WKActionSheetItem2 *preItem;
    if(self.sheetView.subviews) {
        int i = 0;
        for (WKActionSheetItem2 *item in self.sheetView.subviews) {
            sheetHeight += item.lim_height;
            if(preItem) {
                item.lim_top = preItem.lim_bottom;
            }
            if(self.items.count>1 && i!=self.items.count-1) {
                item.showBottomLine = true;
            }else {
                item.showBottomLine = false;
            }
            i++;
            preItem = item;
        }
    }
    if(preItem) {
        self.cancelItem.lim_top = preItem.lim_bottom;
    }
    [self.cancelItem removeFromSuperview];
    [self.sheetView addSubview:self.cancelItem];
    sheetHeight+= self.cancelItem.lim_height;
    
    CGFloat safeAreaBottom = 0;
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeArea = [[UIApplication sharedApplication] keyWindow].safeAreaInsets;
        safeAreaBottom =safeArea.bottom;
    }
    self.sheetView.lim_height = sheetHeight + safeAreaBottom;
    [self setSheetViewCorner];
}

- (NSMutableArray<WKActionSheetItem2 *> *)items {
    if(!_items) {
        _items = [NSMutableArray array];
    }
    return _items;
}

- (UIView *)sheetView {
    if(!_sheetView) {
        _sheetView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,self.lim_width , 0)];
        if([WKApp shared].config.style == WKSystemStyleDark) {
            [_sheetView setBackgroundColor:[UIColor colorWithRed:44.0f/255.0f green:44.0f/255.0f blue:44.0f/255.0f alpha:1.0f]];
        }else{
            [_sheetView setBackgroundColor:[UIColor whiteColor]];
        }
        
    }
    return _sheetView;
}
-(void) setSheetViewCorner {
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.sheetView.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight cornerRadii:CGSizeMake(12, 12)];
     CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.sheetView.bounds;
     maskLayer.path = maskPath.CGPath;
    self.sheetView.layer.mask = maskLayer;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
}

- (void)addItem:(WKActionSheetItem2 *)item {
    __weak typeof(self) weakSelf = self;
    if([item isKindOfClass:[WKActionSheetButtonItem2 class]]) {
        onItemClick click = ((WKActionSheetButtonItem2*)item).onItemClick;
        ((WKActionSheetButtonItem2*)item).onItemClick = ^{
            [weakSelf hide];
            if(click) {
                click();
            }
        };
    }else  if([item isKindOfClass:[WKActionSheetButtonSubtitleItem2 class]]) {
        onItemClick click = ((WKActionSheetButtonSubtitleItem2*)item).onItemClick;
        ((WKActionSheetButtonSubtitleItem2*)item).onItemClick = ^{
            [weakSelf hide];
            if(click) {
                click();
            }
        };
    }
    [self.items addObject:item];
    [self.sheetView addSubview:item];
}

- (void)show {
    [self layoutUI];
    self.sheetView.lim_top = self.lim_height;
   
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0.3;
        self.sheetView.lim_top = self.lim_height - self.sheetView.lim_height;
    }];
}

-(void) hide {
    if(self.onHide) {
        self.onHide();
    }
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0.0;
        self.sheetView.lim_top = self.lim_height;
    } completion:^(BOOL finished) {
        [self.sheetView removeFromSuperview];
        [self removeFromSuperview];
    }];
}

// 点击黑色遮罩
- (void)coverClick{
    [self hide];
}

- (void)dealloc
{
    [self.sheetView removeFromSuperview];
    [self removeFromSuperview];
}

@end
