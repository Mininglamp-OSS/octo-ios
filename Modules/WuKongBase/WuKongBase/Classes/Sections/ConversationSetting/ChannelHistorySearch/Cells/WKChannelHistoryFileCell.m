//
//  WKChannelHistoryFileCell.m
//

#import "WKChannelHistoryFileCell.h"
#import "WKChannelHistoryHighlighter.h"
#import "WKApp.h"
#import "WKTimeTool.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"

#define kFileCellHeight 72.0f
#define kIconSize       40.0f
#define kHPadding       16.0f
#define kGap            12.0f

@interface WKChannelHistoryFileCell ()
@property (nonatomic, strong) UILabel *iconLbl;       // 文件后缀字符显示
@property (nonatomic, strong) UIView *iconBg;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UILabel *metaLbl;
@property (nonatomic, strong) UIView *separator;
@end

@implementation WKChannelHistoryFileCell

+ (NSString *)reuseIdentifier { return NSStringFromClass(self); }
+ (CGFloat)cellHeight { return kFileCellHeight; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

        _iconBg = [UIView new];
        _iconBg.layer.cornerRadius = 6.0f;
        _iconBg.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.12];
        [self.contentView addSubview:_iconBg];

        _iconLbl = [UILabel new];
        _iconLbl.font = [[WKApp shared].config appFontOfSize:11.0f];
        _iconLbl.textColor = [WKApp shared].config.themeColor;
        _iconLbl.textAlignment = NSTextAlignmentCenter;
        [_iconBg addSubview:_iconLbl];

        _nameLbl = [UILabel new];
        _nameLbl.font = [[WKApp shared].config appFontOfSize:15.0f];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        _nameLbl.numberOfLines = 1;
        _nameLbl.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:_nameLbl];

        _metaLbl = [UILabel new];
        _metaLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
        _metaLbl.textColor = [UIColor grayColor];
        _metaLbl.numberOfLines = 1;
        _metaLbl.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_metaLbl];

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
    self.iconBg.frame = CGRectMake(kHPadding, (h - kIconSize) / 2.0f, kIconSize, kIconSize);
    self.iconLbl.frame = self.iconBg.bounds;
    CGFloat textX = CGRectGetMaxX(self.iconBg.frame) + kGap;
    CGFloat textW = w - textX - kHPadding;
    self.nameLbl.frame = CGRectMake(textX, 16.0f, textW, 20.0f);
    self.metaLbl.frame = CGRectMake(textX, CGRectGetMaxY(self.nameLbl.frame) + 4.0f, textW, 16.0f);
    self.separator.frame = CGRectMake(textX, h - 0.5f, w - textX, 0.5f);
}

- (NSString *)humanReadableFileSize:(long long)bytes {
    if (bytes <= 0) return @"";
    double size = (double)bytes;
    NSArray *units = @[@"B", @"KB", @"MB", @"GB", @"TB"];
    NSUInteger idx = 0;
    while (size >= 1024.0 && idx < units.count - 1) {
        size /= 1024.0;
        idx++;
    }
    if (idx == 0) return [NSString stringWithFormat:@"%lld %@", bytes, units[0]];
    return [NSString stringWithFormat:@"%.1f %@", size, units[idx]];
}

- (NSString *)iconBadgeFromExt:(NSString *)ext fileName:(NSString *)name {
    NSString *e = ext.length > 0 ? [ext lowercaseString] : nil;
    if (e.length == 0 && name.length > 0) {
        NSString *trimmed = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSRange dot = [trimmed rangeOfString:@"." options:NSBackwardsSearch];
        if (dot.location != NSNotFound && dot.location + 1 < trimmed.length) {
            e = [[trimmed substringFromIndex:dot.location + 1] lowercaseString];
        }
    }
    if (e.length == 0) return @"FILE";
    if (e.length > 4) e = [e substringToIndex:4];
    return [e uppercaseString];
}

- (void)applyItem:(WKChannelHistorySearchItem *)item keyword:(NSString *)keyword {
    UIColor *theme = [WKApp shared].config.themeColor;
    self.iconLbl.text = [self iconBadgeFromExt:item.fileExt fileName:item.fileName];
    self.nameLbl.attributedText = [WKChannelHistoryHighlighter attributedFromSnippet:(item.fileName ?: @"")
                                                                                 keyword:keyword
                                                                                    font:self.nameLbl.font
                                                                               textColor:[WKApp shared].config.defaultTextColor
                                                                          highlightColor:theme];
    NSMutableArray<NSString *> *metaParts = [NSMutableArray array];
    if (item.senderName.length > 0) [metaParts addObject:item.senderName];
    NSString *sz = [self humanReadableFileSize:item.fileSizeBytes];
    if (sz.length > 0) [metaParts addObject:sz];
    if (item.timestamp > 0) {
        [metaParts addObject:[WKTimeTool searchResultTimeString:[NSDate dateWithTimeIntervalSince1970:item.timestamp]]];
    }
    self.metaLbl.text = [metaParts componentsJoinedByString:@" · "];
}

@end
