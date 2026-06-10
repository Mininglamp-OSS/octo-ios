//
//  WKZipEntryCell.m
//  WuKongBase
//

#import "WKZipEntryCell.h"
#import "WKFileIconHelper.h"
#import "WKApp.h"

@interface WKZipEntryCell ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UILabel *sizeLbl;
@end

@implementation WKZipEntryCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        WKAppConfig *config = [WKApp shared].config;
        self.backgroundColor = config.cellBackgroundColor;
        self.contentView.backgroundColor = config.cellBackgroundColor;

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_iconView];

        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [UIFont systemFontOfSize:16];
        _nameLbl.textColor = config.defaultTextColor;
        _nameLbl.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:_nameLbl];

        _sizeLbl = [[UILabel alloc] init];
        _sizeLbl.font = [UIFont systemFontOfSize:12];
        _sizeLbl.textColor = config.tipColor;
        [self.contentView addSubview:_sizeLbl];
    }
    return self;
}

- (void)configureWithName:(NSString *)name
              isDirectory:(BOOL)isDirectory
                      ext:(NSString *)ext
                 sizeText:(NSString *)sizeText {
    self.nameLbl.text = name ?: @"";

    if (isDirectory) {
        UIImage *folder = [WKFileIconHelper folderIcon];
        self.iconView.image = folder;
        self.iconView.tintColor = [WKApp shared].config.themeColor;
        self.sizeLbl.text = @"";
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        UIImage *icon = [WKFileIconHelper iconForFileExtension:(ext ?: @"")];
        self.iconView.image = icon;
        // 系统兜底 doc.fill 是 Template, 需要可见的 tint; 彩色文件图标已是 Original 渲染, tint 不影响。
        self.iconView.tintColor = [UIColor systemBlueColor];
        self.sizeLbl.text = sizeText ?: @"";
        self.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    CGFloat iconSize = 30;
    CGFloat leftPad = 16;
    self.iconView.frame = CGRectMake(leftPad, (h - iconSize) / 2, iconSize, iconSize);

    CGFloat textX = CGRectGetMaxX(self.iconView.frame) + 12;
    CGFloat rightPad = self.accessoryType == UITableViewCellAccessoryNone ? 16 : 8;
    CGFloat textW = w - textX - rightPad;
    if (self.sizeLbl.text.length > 0) {
        self.nameLbl.frame = CGRectMake(textX, 10, textW, 22);
        self.sizeLbl.frame = CGRectMake(textX, 34, textW, 16);
    } else {
        self.nameLbl.frame = CGRectMake(textX, (h - 22) / 2, textW, 22);
        self.sizeLbl.frame = CGRectZero;
    }
}

@end
