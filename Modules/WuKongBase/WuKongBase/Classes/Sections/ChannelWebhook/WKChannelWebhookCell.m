//
//  WKChannelWebhookCell.m
//  WuKongBase
//

#import "WKChannelWebhookCell.h"
#import "WKIncomingWebhook.h"
#import "WuKongBase.h"
#import <SDWebImage/SDWebImage.h>

#define WK_WEBHOOK_CELL_HEIGHT 92.0f
#define WK_WEBHOOK_AVATAR_SIZE 32.0f
#define WK_WEBHOOK_H_PAD 16.0f

@interface WKChannelWebhookCell ()
@property(nonatomic,strong) UIImageView *avatarView;
@property(nonatomic,strong) UILabel *nameLbl;
@property(nonatomic,strong) UILabel *disabledChip;
@property(nonatomic,strong) UISwitch *toggleSwitch;
@property(nonatomic,strong) UIActivityIndicatorView *switchLoadingIndicator;
@property(nonatomic,strong) UILabel *createdMetaLbl;
@property(nonatomic,strong) UILabel *usageMetaLbl;
@end

@implementation WKChannelWebhookCell

+ (CGFloat)cellHeight { return WK_WEBHOOK_CELL_HEIGHT; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        self.contentView.backgroundColor = [WKApp shared].config.cellBackgroundColor;
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        _avatarView = [UIImageView new];
        _avatarView.layer.cornerRadius = 6.0f;
        _avatarView.layer.masksToBounds = YES;
        _avatarView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarView.backgroundColor = [UIColor colorWithRed:0xE8/255.0 green:0xEA/255.0 blue:0xF0/255.0 alpha:1.0];
        [self.contentView addSubview:_avatarView];

        _nameLbl = [UILabel new];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:16.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        [self.contentView addSubview:_nameLbl];

        _disabledChip = [UILabel new];
        _disabledChip.font = [[WKApp shared].config appFontOfSize:11.0f];
        _disabledChip.textColor = [UIColor whiteColor];
        _disabledChip.backgroundColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _disabledChip.textAlignment = NSTextAlignmentCenter;
        _disabledChip.layer.cornerRadius = 4.0f;
        _disabledChip.layer.masksToBounds = YES;
        _disabledChip.hidden = YES;
        [self.contentView addSubview:_disabledChip];

        _toggleSwitch = [[UISwitch alloc] init];
        _toggleSwitch.onTintColor = [WKApp shared].config.themeColor;
        [_toggleSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_toggleSwitch];

        _switchLoadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        _switchLoadingIndicator.hidesWhenStopped = YES;
        [self.contentView addSubview:_switchLoadingIndicator];

        _createdMetaLbl = [UILabel new];
        _createdMetaLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _createdMetaLbl.textColor = [WKApp shared].config.tipColor;
        [self.contentView addSubview:_createdMetaLbl];

        _usageMetaLbl = [UILabel new];
        _usageMetaLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _usageMetaLbl.textColor = [WKApp shared].config.tipColor;
        [self.contentView addSubview:_usageMetaLbl];
    }
    return self;
}

- (void)onSwitchChanged:(UISwitch *)sender {
    if (self.onSwitchToggle) self.onSwitchToggle(sender.isOn);
}

- (void)refreshWithWebhook:(WKIncomingWebhook *)webhook
        creatorDisplayName:(NSString *)creatorDisplayName
                 canManage:(BOOL)canManage
             switchLoading:(BOOL)loading {
    if (!webhook) return;

    // 头像：有自定义 URL 走 SD 加载，否则用程序化绘制的链接图占位。
    UIImage *fallback = [WKChannelWebhookCell defaultAvatarImage];
    if (webhook.avatar.length > 0) {
        NSURL *url = [WKApp.shared getImageFullUrl:webhook.avatar];
        [self.avatarView sd_setImageWithURL:url placeholderImage:fallback];
    } else {
        [self.avatarView sd_cancelCurrentImageLoad];
        self.avatarView.image = fallback;
    }

    self.nameLbl.text = webhook.name.length > 0 ? webhook.name : @"Webhook";

    BOOL disabled = (webhook.status == WKIncomingWebhookStatusDisabled);
    self.disabledChip.hidden = !disabled;
    if (disabled) {
        self.disabledChip.text = LLang(@"已禁用");
    }

    // Switch & loading 互斥显隐
    self.toggleSwitch.hidden = !canManage || loading;
    self.toggleSwitch.userInteractionEnabled = canManage && !loading;
    [self.toggleSwitch setOn:!disabled animated:NO];
    if (loading) {
        [self.switchLoadingIndicator startAnimating];
    } else {
        [self.switchLoadingIndicator stopAnimating];
    }

    // 整张卡片在禁用态稍降透明度，与 web 行为对齐。
    self.contentView.alpha = disabled ? 0.78f : 1.0f;

    // meta 行：「由 XX 创建 · 时间」/「累计 N 次推送，最近 时间」
    NSString *createdTime = [WKChannelWebhookCell formatDateOnly:webhook.createdAt];
    if (creatorDisplayName.length > 0) {
        self.createdMetaLbl.text = [NSString stringWithFormat:LLang(@"由 %@ 创建 · %@"), creatorDisplayName, createdTime];
    } else {
        self.createdMetaLbl.text = [NSString stringWithFormat:LLang(@"创建于 %@"), createdTime];
    }

    if (webhook.callCount > 0) {
        NSString *lastTime = webhook.lastUsedAt > 0 ? [WKChannelWebhookCell formatDateTime:webhook.lastUsedAt] : @"";
        self.usageMetaLbl.text = [NSString stringWithFormat:LLang(@"累计 %ld 次推送，最近 %@"),
                                  (long)webhook.callCount, lastTime];
        self.usageMetaLbl.hidden = NO;
    } else {
        self.usageMetaLbl.text = nil;
        self.usageMetaLbl.hidden = YES;
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.contentView.lim_width;
    CGFloat H = self.contentView.lim_height;

    self.avatarView.frame = CGRectMake(WK_WEBHOOK_H_PAD,
                                       12.0f,
                                       WK_WEBHOOK_AVATAR_SIZE, WK_WEBHOOK_AVATAR_SIZE);

    // Switch 在右
    CGSize switchSize = [self.toggleSwitch sizeThatFits:CGSizeZero];
    self.toggleSwitch.frame = CGRectMake(W - WK_WEBHOOK_H_PAD - switchSize.width,
                                         12.0f + (WK_WEBHOOK_AVATAR_SIZE - switchSize.height) / 2.0f,
                                         switchSize.width, switchSize.height);
    self.switchLoadingIndicator.frame = self.toggleSwitch.frame;

    // 名称 + chip
    CGFloat nameLeft = CGRectGetMaxX(self.avatarView.frame) + 10;
    CGFloat nameRight = self.toggleSwitch.hidden ? (W - WK_WEBHOOK_H_PAD) : (self.toggleSwitch.lim_left - 8);
    CGFloat nameTop = 12.0f;
    CGFloat nameH = ceil(self.nameLbl.font.lineHeight);

    if (!self.disabledChip.hidden) {
        CGSize chipText = [self.disabledChip.text sizeWithAttributes:@{NSFontAttributeName: self.disabledChip.font}];
        CGFloat chipW = ceil(chipText.width) + 12;
        CGFloat chipH = 18.0f;
        // 名称尽量靠左，chip 紧跟其后
        [self.nameLbl sizeToFit];
        CGFloat nameW = MIN(self.nameLbl.lim_width, MAX(0, nameRight - nameLeft - chipW - 6));
        self.nameLbl.frame = CGRectMake(nameLeft, nameTop, nameW, nameH);
        self.disabledChip.frame = CGRectMake(CGRectGetMaxX(self.nameLbl.frame) + 6,
                                             nameTop + (nameH - chipH) / 2.0f,
                                             chipW, chipH);
    } else {
        self.nameLbl.frame = CGRectMake(nameLeft, nameTop, MAX(0, nameRight - nameLeft), nameH);
    }

    // meta
    CGFloat metaLeft = nameLeft;
    CGFloat metaRight = W - WK_WEBHOOK_H_PAD;
    CGFloat metaY = CGRectGetMaxY(self.nameLbl.frame) + 6;
    CGFloat metaH = 16.0f;
    self.createdMetaLbl.frame = CGRectMake(metaLeft, metaY, MAX(0, metaRight - metaLeft), metaH);

    if (!self.usageMetaLbl.hidden) {
        self.usageMetaLbl.frame = CGRectMake(metaLeft,
                                             CGRectGetMaxY(self.createdMetaLbl.frame) + 2,
                                             MAX(0, metaRight - metaLeft), metaH);
    }
    (void)H;
}

#pragma mark - Helpers

+ (NSString *)formatDateOnly:(NSTimeInterval)tsSec {
    if (tsSec <= 0) return @"";
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:tsSec];
    static NSDateFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [NSDateFormatter new];
        fmt.dateFormat = @"yyyy-MM-dd";
    });
    return [fmt stringFromDate:d];
}

+ (NSString *)formatDateTime:(NSTimeInterval)tsSec {
    if (tsSec <= 0) return @"";
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:tsSec];
    static NSDateFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [NSDateFormatter new];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm";
    });
    return [fmt stringFromDate:d];
}

#pragma mark - Default avatar (程序化绘制，与 web INCOMING_WEBHOOK_DEFAULT_AVATAR 视觉同源)

+ (UIImage *)defaultAvatarImage {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CGSize s = CGSizeMake(50, 50);
        UIGraphicsBeginImageContextWithOptions(s, NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        // 圆角矩形底
        UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, s.width, s.height) cornerRadius:12];
        [[UIColor colorWithRed:0xE8/255.0 green:0xEA/255.0 blue:0xF0/255.0 alpha:1.0] setFill];
        [bg fill];
        // 链接符号
        [[UIColor colorWithRed:0x7A/255.0 green:0x82/255.0 blue:0x99/255.0 alpha:1.0] setStroke];
        CGContextSetLineWidth(ctx, 2.6f);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        CGContextMoveToPoint(ctx, 20, 30);
        CGContextAddLineToPoint(ctx, 30, 20);
        CGContextMoveToPoint(ctx, 27, 17);
        CGContextAddArc(ctx, 27 + 3.5, 17 + 3.5, 5, M_PI, M_PI + M_PI_2, 1);
        CGContextAddLineToPoint(ctx, 32 - 2.5, 26.5);
        CGContextMoveToPoint(ctx, 23, 33);
        CGContextAddArc(ctx, 23 - 3.5, 33 - 3.5, 5, 0, M_PI_2, 0);
        CGContextStrokePath(ctx);
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

@end
