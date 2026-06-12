//
//  OctoContextEntryGridCell.m
//  OctoContext
//

#import "OctoContextEntryGridCell.h"
#import <Masonry/Masonry.h>

@interface OctoContextEntryGridCell ()
@property(nonatomic, strong) UIView *iconContainer;   // 42×42 紫色圆角
@property(nonatomic, strong) UILabel *titleLabel;     // 10pt 居中
@end

@implementation OctoContextEntryGridCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.iconContainer = [UIView new];
        [self.contentView addSubview:self.iconContainer];

        self.titleLabel = [UILabel new];
        self.titleLabel.font = [UIFont systemFontOfSize:10];
        self.titleLabel.textColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            return tc.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor whiteColor]
                : [UIColor blackColor];
        }];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:self.titleLabel];

        // padding-top 17 → icon, gap 8 → label。整块 94×100 中按设计稿排。
        [self.iconContainer mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.contentView).offset(17);
            make.centerX.equalTo(self.contentView);
            make.size.mas_equalTo(CGSizeMake(42, 42));
        }];
        [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.iconContainer.mas_bottom).offset(8);
            make.left.right.equalTo(self.contentView);
        }];
    }
    return self;
}

- (void)bindIcon:(UIView *)iconView title:(NSString *)title {
    for (UIView *sub in self.iconContainer.subviews) [sub removeFromSuperview];
    iconView.frame = self.iconContainer.bounds;
    iconView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.iconContainer addSubview:iconView];
    self.titleLabel.text = title;
}

@end
