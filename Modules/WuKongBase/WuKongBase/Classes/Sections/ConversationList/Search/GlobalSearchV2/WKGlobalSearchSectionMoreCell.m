//
//  WKGlobalSearchSectionMoreCell.m
//  WuKongBase
//

#import "WKGlobalSearchSectionMoreCell.h"
#import "WKApp.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"

#define kMoreRowHeight 44.0f

@interface WKGlobalSearchSectionMoreCell ()
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UIImageView *chevron;
@property (nonatomic, strong) UIView *separator;
@end

@implementation WKGlobalSearchSectionMoreCell

+ (NSString *)reuseIdentifier { return NSStringFromClass(self); }
+ (CGFloat)cellHeight { return kMoreRowHeight; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

        _titleLbl = [UILabel new];
        _titleLbl.font = [[WKApp shared].config appFontOfSize:14.0f];
        _titleLbl.textColor = [WKApp shared].config.themeColor;
        _titleLbl.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_titleLbl];

        _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
        _chevron.tintColor = [WKApp shared].config.themeColor;
        _chevron.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_chevron];

        _separator = [UIView new];
        _separator.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.12];
        [self.contentView addSubview:_separator];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.lim_width;
    CGFloat h = self.contentView.lim_height;

    CGFloat chevW = 9.0f;
    CGFloat titleW = [self.titleLbl.text sizeWithAttributes:@{ NSFontAttributeName: self.titleLbl.font }].width + 2.0f;

    self.titleLbl.frame = CGRectMake((w - titleW - chevW - 4.0f) / 2.0f, 0, titleW, h);
    self.chevron.frame = CGRectMake(self.titleLbl.lim_right + 4.0f, (h - 11.0f) / 2.0f, chevW, 11.0f);

    self.separator.frame = CGRectMake(0, 0, w, 0.5f);
}

- (void)applyCount:(NSInteger)count {
    self.titleLbl.text = [NSString stringWithFormat:LLang(@"查看全部 %ld 条"), (long)count];
    [self setNeedsLayout];
}

@end
