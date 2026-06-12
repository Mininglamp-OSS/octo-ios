//
//  OctoSummaryMembersView.m
//  OctoContext
//

#import "OctoSummaryMembersView.h"
#import <WuKongBase/WuKongBase.h>

@interface OctoSummaryMembersView ()
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) NSArray<OctoMemberStatus *> *members;
@property(nonatomic, strong) NSMutableArray<UIView *> *rows;
@end

@implementation OctoSummaryMembersView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor systemBackgroundColor];
        self.layer.cornerRadius = 12;

        self.titleLabel = [UILabel new];
        self.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        self.titleLabel.textColor = [UIColor labelColor];
        self.titleLabel.text = LLang(@"成员状态");
        [self addSubview:self.titleLabel];

        self.rows = [NSMutableArray array];
    }
    return self;
}

- (void)updateMembers:(NSArray<OctoMemberStatus *> *)members {
    self.members = members ?: @[];
    for (UIView *r in self.rows) [r removeFromSuperview];
    [self.rows removeAllObjects];

    for (OctoMemberStatus *m in self.members) {
        UIView *row = [UIView new];
        UILabel *name = [UILabel new];
        name.font = [UIFont systemFontOfSize:14];
        name.textColor = [UIColor labelColor];
        name.text = m.userName.length > 0 ? m.userName : m.userId;
        [row addSubview:name];

        UILabel *st = [UILabel new];
        st.font = [UIFont systemFontOfSize:12];
        st.textColor = [UIColor.labelColor colorWithAlphaComponent:0.5];
        st.text = [self displayForStatus:m.status submittedAt:m.submittedAt];
        st.textAlignment = NSTextAlignmentRight;
        [row addSubview:st];

        row.tag = (NSInteger)self.rows.count;
        [self addSubview:row];
        [self.rows addObject:row];
        // store labels via associated objects? Simpler: search-by-tag in layout.
        name.tag = 1; st.tag = 2;
    }
    [self setNeedsLayout];
}

- (NSString *)displayForStatus:(NSString *)status submittedAt:(NSString *)at {
    if ([status isEqualToString:@"submitted"]) return LLang(@"已提交");
    if ([status isEqualToString:@"completed"]) return LLang(@"已完成");
    if ([status isEqualToString:@"processing"]) return LLang(@"生成中");
    if ([status isEqualToString:@"accepted"]) return LLang(@"已接受");
    if ([status isEqualToString:@"declined"]) return LLang(@"已拒绝");
    return LLang(@"等待中");
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    self.titleLabel.frame = CGRectMake(12, 12, w - 24, 22);
    CGFloat y = 40;
    for (UIView *row in self.rows) {
        row.frame = CGRectMake(12, y, w - 24, 32);
        UIView *name = [row viewWithTag:1];
        UIView *st   = [row viewWithTag:2];
        name.frame = CGRectMake(0, 6, (w - 24) * 0.6, 20);
        st.frame   = CGRectMake((w - 24) * 0.6, 6, (w - 24) * 0.4, 20);
        y += 32;
    }
}

- (CGFloat)intrinsicHeightForWidth:(CGFloat)width {
    return 40 + (CGFloat)self.members.count * 32 + 12;
}

@end
