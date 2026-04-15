//
//  WKCategorySectionCell.m
//  WuKongBase
//

#import "WKCategorySectionCell.h"
#import "WKApp.h"
#import "UIView+WK.h"

@interface WKCategorySectionCell ()
@property (nonatomic, strong) UIImageView *arrowView;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UIView *topDivider;
@end

@implementation WKCategorySectionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [WKApp shared].config.backgroundColor;

        // 顶部分隔线
        _topDivider = [[UIView alloc] init];
        _topDivider.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
        _topDivider.hidden = YES;
        [self.contentView addSubview:_topDivider];

        // 折叠箭头
        _arrowView = [[UIImageView alloc] init];
        _arrowView.contentMode = UIViewContentModeScaleAspectFit;
        _arrowView.image = [self chevronDownImage];
        [self.contentView addSubview:_arrowView];

        // 标题
        _titleLbl = [[UILabel alloc] init];
        _titleLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        _titleLbl.textColor = [UIColor colorWithRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0];
        [self.contentView addSubview:_titleLbl];

        // 点击
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
        [self.contentView addGestureRecognizer:tap];

        // 长按
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
        [self.contentView addGestureRecognizer:longPress];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.lim_height;
    CGFloat w = self.contentView.lim_width;

    _topDivider.frame = CGRectMake(15, 0, w - 30, 0.5);
    _topDivider.hidden = !self.showTopDivider;

    _arrowView.frame = CGRectMake(15, (h - 12) / 2.0, 12, 12);
    _arrowView.transform = self.collapsed ? CGAffineTransformMakeRotation(-M_PI_2) : CGAffineTransformIdentity;

    _titleLbl.frame = CGRectMake(32, 0, w - 47, h);
}

- (void)setSectionTitle:(NSString *)sectionTitle {
    _sectionTitle = sectionTitle;
    _titleLbl.text = sectionTitle;
}

- (void)setCollapsed:(BOOL)collapsed {
    _collapsed = collapsed;
    _arrowView.transform = collapsed ? CGAffineTransformMakeRotation(-M_PI_2) : CGAffineTransformIdentity;
}

- (void)onTap {
    BOOL newCollapsed = !self.collapsed;
    self.collapsed = newCollapsed;

    // 箭头旋转动画
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.arrowView.transform = newCollapsed ? CGAffineTransformMakeRotation(-M_PI_2) : CGAffineTransformIdentity;
    } completion:nil];

    if (self.onToggle) {
        self.onToggle(self.sectionId, newCollapsed);
    }
}

- (void)onLongPressGesture:(UILongPressGestureRecognizer *)gesture {
    if (self.isDefault) return;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // 高亮反馈
        [UIView animateWithDuration:0.15 animations:^{
            self.contentView.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.08];
            self.transform = CGAffineTransformMakeScale(0.98, 0.98);
        }];
        if (self.onLongPress) {
            CGPoint ptInCell = [gesture locationInView:self];
            CGPoint ptInWindow = [self convertPoint:ptInCell toView:nil];
            self.onLongPress(self.sectionId, self.sectionTitle, ptInWindow);
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.2 animations:^{
            self.contentView.backgroundColor = [UIColor clearColor];
            self.transform = CGAffineTransformIdentity;
        }];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onToggle = nil;
    self.onLongPress = nil;
    self.isDefault = NO;
    self.showTopDivider = NO;
}

/// 程序化生成向下箭头图标
- (UIImage *)chevronDownImage {
    CGSize size = CGSizeMake(12, 12);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;

    UIColor *color = [UIColor colorWithRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0];
    [color setStroke];
    CGContextSetLineWidth(ctx, 1.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    // V shape pointing down
    CGContextMoveToPoint(ctx, 2, 4);
    CGContextAddLineToPoint(ctx, 6, 8);
    CGContextAddLineToPoint(ctx, 10, 4);
    CGContextStrokePath(ctx);

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
