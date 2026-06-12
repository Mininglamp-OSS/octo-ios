//
//  OctoSelectedSourcesView.m
//  OctoContext
//

#import "OctoSelectedSourcesView.h"
#import <WuKongBase/WuKongBase.h>
#import <WuKongIMSDK/WuKongIMSDK.h>
#import <SDWebImage/SDWebImage.h>

static const CGFloat kPillH       = 28;
static const CGFloat kPillHGap    = 6;
static const CGFloat kPillVGap    = 6;
static const CGFloat kPillRadius  = 14;
static const CGFloat kPillSidePad = 6;
static const CGFloat kAvatarSize  = 20;
static const CGFloat kCloseSize   = 14;
static const CGFloat kInnerGap    = 6;

@interface OctoSourcePillView : UIView
@property(nonatomic, strong) UIImageView *avatar;
@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, strong) UIButton *closeBtn;
@property(nonatomic, strong) OctoSourceItem *item;
@end

@implementation OctoSourcePillView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = kPillRadius;
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1 alpha:0.08]
                : [UIColor colorWithRed:0xF5/255.0 green:0xF6/255.0 blue:0xF7/255.0 alpha:1.0];
        }];
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.06].CGColor;

        _avatar = [UIImageView new];
        _avatar.layer.cornerRadius = kAvatarSize / 2.0;
        _avatar.layer.masksToBounds = YES;
        _avatar.contentMode = UIViewContentModeScaleAspectFill;
        _avatar.backgroundColor = [UIColor systemGray4Color];
        [self addSubview:_avatar];

        _nameLabel = [UILabel new];
        _nameLabel.font = [UIFont systemFontOfSize:13];
        _nameLabel.textColor = [UIColor labelColor];
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_nameLabel];

        _closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
            [_closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:cfg] forState:UIControlStateNormal];
        }
        _closeBtn.tintColor = [UIColor.labelColor colorWithAlphaComponent:0.5];
        [self addSubview:_closeBtn];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height;
    self.avatar.frame   = CGRectMake(kPillSidePad, (h - kAvatarSize) / 2.0, kAvatarSize, kAvatarSize);
    self.closeBtn.frame = CGRectMake(self.bounds.size.width - kPillSidePad - kCloseSize - 2,
                                     (h - kCloseSize) / 2.0, kCloseSize + 4, kCloseSize + 4);
    CGFloat nameX = CGRectGetMaxX(self.avatar.frame) + kInnerGap;
    CGFloat nameW = CGRectGetMinX(self.closeBtn.frame) - kInnerGap - nameX;
    self.nameLabel.frame = CGRectMake(nameX, 0, nameW, h);
}

+ (CGFloat)widthForName:(NSString *)name {
    UIFont *f = [UIFont systemFontOfSize:13];
    CGFloat textW = ceilf([name sizeWithAttributes:@{NSFontAttributeName: f}].width);
    textW = MIN(textW, 140);     // 名字过长截断: 单 pill 不超过 ~180 宽
    return kPillSidePad + kAvatarSize + kInnerGap + textW + kInnerGap + kCloseSize + 4 + kPillSidePad;
}

@end

#pragma mark - OctoSelectedSourcesView

@interface OctoSelectedSourcesView ()
@property(nonatomic, strong) UIScrollView *scroll;
@property(nonatomic, strong) NSMutableArray<OctoSourcePillView *> *pills;
@property(nonatomic, assign) CGFloat lastLayoutWidth;
@end

@implementation OctoSelectedSourcesView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _maxRows = 3;
        _pills = [NSMutableArray array];
        _scroll = [UIScrollView new];
        _scroll.alwaysBounceVertical = NO;
        _scroll.showsVerticalScrollIndicator = NO;
        [self addSubview:_scroll];
    }
    return self;
}

- (void)setItems:(NSArray<OctoSourceItem *> *)items {
    _items = [items copy] ?: @[];
    [self rebuildPills];
    [self setNeedsLayout];
}

- (void)setMaxRows:(NSInteger)maxRows {
    _maxRows = MAX(1, maxRows);
    [self setNeedsLayout];
}

- (void)rebuildPills {
    for (UIView *v in self.pills) [v removeFromSuperview];
    [self.pills removeAllObjects];

    for (OctoSourceItem *it in self.items) {
        OctoSourcePillView *p = [[OctoSourcePillView alloc] initWithFrame:CGRectZero];
        p.item = it;
        p.nameLabel.text = it.sourceName.length > 0 ? it.sourceName : it.sourceId;
        [self loadAvatarIntoPill:p forSource:it];
        [p.closeBtn addTarget:self action:@selector(onPillRemove:) forControlEvents:UIControlEventTouchUpInside];
        p.closeBtn.tag = (NSInteger)self.pills.count;
        [self.scroll addSubview:p];
        [self.pills addObject:p];
    }
}

- (void)loadAvatarIntoPill:(OctoSourcePillView *)pill forSource:(OctoSourceItem *)src {
    // 用 SDK channel info 拿头像 url。WKChannelInfo.logo 是头像字段; 无 url 时画首字母色块。
    NSInteger ct = (src.sourceType == OctoSourceDirectMessage) ? WK_PERSON : WK_GROUP;
    WKChannel *ch = [WKChannel channelID:src.sourceId channelType:ct];
    WKChannelInfo *info = [[WKSDK shared].channelManager getChannelInfo:ch];
    NSString *url = info.logo;
    if (url.length > 0) {
        [pill.avatar sd_setImageWithURL:[NSURL URLWithString:url]
                       placeholderImage:[OctoSelectedSourcesView fallbackAvatarFor:pill.nameLabel.text]];
    } else {
        pill.avatar.image = [OctoSelectedSourcesView fallbackAvatarFor:pill.nameLabel.text];
    }
}

+ (UIImage *)fallbackAvatarFor:(NSString *)name {
    NSString *first = name.length > 0 ? [name substringWithRange:[name rangeOfComposedCharacterSequenceAtIndex:0]] : @"·";
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kAvatarSize, kAvatarSize), NO, 0);
    UIBezierPath *p = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, kAvatarSize, kAvatarSize)];
    [[UIColor colorWithRed:0x7F/255.0 green:0x3B/255.0 blue:0xF5/255.0 alpha:0.85] setFill];
    [p fill];
    UIFont *f = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    NSDictionary *attrs = @{NSFontAttributeName: f, NSForegroundColorAttributeName: UIColor.whiteColor};
    CGSize s = [first sizeWithAttributes:attrs];
    [first drawAtPoint:CGPointMake((kAvatarSize - s.width) / 2.0, (kAvatarSize - s.height) / 2.0)
        withAttributes:attrs];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)onPillRemove:(UIButton *)btn {
    NSInteger idx = btn.tag;
    if (idx < 0 || idx >= (NSInteger)self.items.count) return;
    OctoSourceItem *removed = self.items[idx];
    if (self.onRemove) self.onRemove(removed);
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    if (width <= 0) return;
    self.scroll.frame = self.bounds;
    [self flowLayoutPillsInWidth:width];
}

- (CGFloat)flowLayoutPillsInWidth:(CGFloat)width {
    CGFloat x = 0, y = 0;
    NSInteger row = 0;
    for (OctoSourcePillView *p in self.pills) {
        CGFloat w = MIN([OctoSourcePillView widthForName:p.nameLabel.text], width);
        if (x + w > width && x > 0) {
            x = 0; y += kPillH + kPillVGap; row++;
        }
        p.frame = CGRectMake(x, y, w, kPillH);
        x += w + kPillHGap;
    }
    CGFloat total = (self.pills.count == 0) ? 0 : (y + kPillH);
    self.scroll.contentSize = CGSizeMake(width, total);
    return total;
}

- (CGFloat)heightForWidth:(CGFloat)width {
    if (self.items.count == 0) return 0;
    // 模拟一次布局算 row 数,但不实际改 frame:
    CGFloat x = 0, rows = 1;
    for (OctoSourceItem *it in self.items) {
        NSString *name = it.sourceName.length > 0 ? it.sourceName : it.sourceId;
        CGFloat w = MIN([OctoSourcePillView widthForName:name], width);
        if (x + w > width && x > 0) { x = 0; rows++; }
        x += w + kPillHGap;
    }
    NSInteger visibleRows = (NSInteger)MIN(rows, (CGFloat)self.maxRows);
    return visibleRows * kPillH + (visibleRows - 1) * kPillVGap;
}

@end
