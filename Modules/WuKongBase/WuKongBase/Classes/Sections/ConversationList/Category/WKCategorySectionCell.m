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
@property (nonatomic, strong) UILabel *countLbl;
@property (nonatomic, strong) UILabel *mentionLbl;
@property (nonatomic, strong) UILabel *badgeLbl;
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

        // 数量（折叠时显示）
        _countLbl = [[UILabel alloc] init];
        _countLbl.font = [UIFont systemFontOfSize:12];
        _countLbl.textColor = [UIColor colorWithRed:180/255.0 green:180/255.0 blue:180/255.0 alpha:1.0];
        _countLbl.hidden = YES;
        [self.contentView addSubview:_countLbl];

        // @提醒标识（折叠时显示）
        _mentionLbl = [[UILabel alloc] init];
        _mentionLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _mentionLbl.textColor = [UIColor orangeColor];
        _mentionLbl.hidden = YES;
        [self.contentView addSubview:_mentionLbl];

        // 未读红点（折叠时显示）
        _badgeLbl = [[UILabel alloc] init];
        _badgeLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _badgeLbl.textColor = [UIColor whiteColor];
        _badgeLbl.backgroundColor = [UIColor redColor];
        _badgeLbl.textAlignment = NSTextAlignmentCenter;
        _badgeLbl.layer.cornerRadius = 9;
        _badgeLbl.layer.masksToBounds = YES;
        _badgeLbl.hidden = YES;
        [self.contentView addSubview:_badgeLbl];

        // 点击
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
        [self.contentView addGestureRecognizer:tap];

        // 长按手势已上移到 VC（统一 table-level UILongPressGestureRecognizer）— 这里
        // 不再单独装一份，避免 cell 复用时手势随 cell 一起销毁，导致 VC 拖拽
        // snapshot 卡死的问题（详见 WKConversationListVC.m onUnifiedLongPress:）。
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

    [_titleLbl sizeToFit];
    _titleLbl.frame = CGRectMake(32, 0, _titleLbl.lim_width, h);

    // 数量标签（折叠时显示）
    if (self.collapsed && self.groupCount > 0) {
        _countLbl.hidden = NO;
        _countLbl.text = [NSString stringWithFormat:@"(%ld)", (long)self.groupCount];
        [_countLbl sizeToFit];
        _countLbl.frame = CGRectMake(_titleLbl.lim_right + 4, 0, _countLbl.lim_width, h);
    } else {
        _countLbl.hidden = YES;
    }

    // @提醒标识（折叠时，分组内有@我则显示在数量后面）
    if (self.collapsed && self.hasMention) {
        _mentionLbl.hidden = NO;
        _mentionLbl.text = @"[有人@我]";
        [_mentionLbl sizeToFit];
        CGFloat mentionLeft = _countLbl.hidden ? (_titleLbl.lim_right + 4) : (_countLbl.lim_right + 4);
        _mentionLbl.frame = CGRectMake(mentionLeft, 0, _mentionLbl.lim_width, h);
    } else {
        _mentionLbl.hidden = YES;
    }

    // 未读红点（折叠时显示在右侧）
    if (self.collapsed && self.unreadCount > 0) {
        _badgeLbl.hidden = NO;
        _badgeLbl.text = self.unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)self.unreadCount];
        [_badgeLbl sizeToFit];
        CGFloat badgeW = MAX(_badgeLbl.lim_width + 10, 18);
        _badgeLbl.frame = CGRectMake(w - 15 - badgeW, (h - 18) / 2.0, badgeW, 18);
    } else {
        _badgeLbl.hidden = YES;
    }
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

- (void)setLongPressHighlighted:(BOOL)highlighted {
    if (self.isDefault) return; // 默认分组无长按交互
    [UIView animateWithDuration:highlighted ? 0.15 : 0.2 animations:^{
        if (highlighted) {
            self.contentView.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.08];
            self.transform = CGAffineTransformMakeScale(0.98, 0.98);
        } else {
            self.contentView.backgroundColor = [UIColor clearColor];
            self.transform = CGAffineTransformIdentity;
        }
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onToggle = nil;
    self.isDefault = NO;
    self.showTopDivider = NO;
    // 复用时强制还原视觉，避免被复用时残留长按高亮
    self.contentView.backgroundColor = [UIColor clearColor];
    self.transform = CGAffineTransformIdentity;
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
