//
//  WKThreadListCell.m
//  WuKongBase
//

#import "WKThreadListCell.h"
#import "WKThreadModel.h"
#import "WKTimeTool.h"
#import "WKApp.h"
#import "UIView+WKCommon.h"
#import "WuKongBase.h"

@interface WKThreadListCell ()

@property (nonatomic, strong) UILabel *iconLbl;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UILabel *statsLbl;
@property (nonatomic, strong) UILabel *previewLbl;
@property (nonatomic, strong) UILabel *badgeLbl;
@property (nonatomic, strong) WKThreadModel *model;

@end

@implementation WKThreadListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    [self.contentView addSubview:self.iconLbl];
    [self.contentView addSubview:self.nameLbl];
    [self.contentView addSubview:self.statsLbl];
    [self.contentView addSubview:self.previewLbl];
    [self.contentView addSubview:self.badgeLbl];
}

- (void)refreshWithModel:(WKThreadModel *)model {
    self.model = model;
    self.nameLbl.text = model.name;
    self.backgroundColor = [WKApp shared].config.cellBackgroundColor;

    // 统计信息
    NSString *timeStr = @"";
    if (model.updatedAt.length > 0) {
        NSDate *date = [WKTimeTool dateFromString:model.updatedAt];
        if (date) {
            timeStr = [WKTimeTool getTimeStringAutoShort2:date mustIncludeTime:NO];
        }
    }
    self.statsLbl.text = [NSString stringWithFormat:@"%ld%@ · %ld%@ · %@",
                          (long)model.messageCount, LLang(@"条消息"),
                          (long)model.memberCount, LLang(@"位成员"),
                          timeStr];

    // 最后消息预览
    if (model.lastMessageContent.length > 0 && model.lastMessageSenderName.length > 0) {
        self.previewLbl.text = [NSString stringWithFormat:@"%@: %@", model.lastMessageSenderName, model.lastMessageContent];
        self.previewLbl.hidden = NO;
    } else {
        self.previewLbl.hidden = YES;
    }

    // 未读红点
    NSInteger unread = model.unreadCount;
    WKChannel *threadChannel = [WKChannel channelID:model.channelId channelType:WK_COMMUNITY_TOPIC];
    WKConversation *threadConv = [[WKSDK shared].conversationManager getConversation:threadChannel];
    if (threadConv) unread = threadConv.unreadCount;
    if (unread > 0) {
        self.badgeLbl.hidden = NO;
        self.badgeLbl.text = unread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unread];
    } else {
        self.badgeLbl.hidden = YES;
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat padding = 16.0f;
    CGFloat contentWidth = self.contentView.lim_width - padding * 2;

    // # 图标
    self.iconLbl.frame = CGRectMake(padding, 14, 32, 32);

    // 红点
    CGFloat badgeRight = 0;
    if (!self.badgeLbl.hidden) {
        [self.badgeLbl sizeToFit];
        CGFloat badgeW = MAX(self.badgeLbl.lim_width + 10, 20);
        CGFloat badgeH = 20;
        self.badgeLbl.frame = CGRectMake(self.contentView.lim_width - padding - badgeW, 16, badgeW, badgeH);
        badgeRight = badgeW + 8;
    }

    // 名称
    CGFloat textLeft = self.iconLbl.lim_right + 10;
    CGFloat textWidth = contentWidth - (textLeft - padding) - badgeRight;
    [self.nameLbl sizeToFit];
    self.nameLbl.frame = CGRectMake(textLeft, 12, textWidth, 20);

    // 统计信息
    [self.statsLbl sizeToFit];
    self.statsLbl.frame = CGRectMake(textLeft, self.nameLbl.lim_bottom + 4, textWidth, 16);

    // 最后消息预览
    if (!self.previewLbl.hidden) {
        [self.previewLbl sizeToFit];
        self.previewLbl.frame = CGRectMake(textLeft, self.statsLbl.lim_bottom + 3, textWidth, 16);
    }
}

#pragma mark - Lazy Init

- (UILabel *)iconLbl {
    if (!_iconLbl) {
        _iconLbl = [[UILabel alloc] init];
        _iconLbl.text = @"#";
        _iconLbl.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        _iconLbl.textColor = [WKApp shared].config.themeColor;
        _iconLbl.textAlignment = NSTextAlignmentCenter;
        _iconLbl.backgroundColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.12];
        _iconLbl.layer.cornerRadius = 16;
        _iconLbl.layer.masksToBounds = YES;
    }
    return _iconLbl;
}

- (UILabel *)nameLbl {
    if (!_nameLbl) {
        _nameLbl = [[UILabel alloc] init];
        _nameLbl.font = [[WKApp shared].config appFontOfSizeMedium:16];
        _nameLbl.textColor = [WKApp shared].config.defaultTextColor;
        _nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _nameLbl;
}

- (UILabel *)statsLbl {
    if (!_statsLbl) {
        _statsLbl = [[UILabel alloc] init];
        _statsLbl.font = [UIFont systemFontOfSize:12];
        _statsLbl.textColor = [UIColor grayColor];
        _statsLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _statsLbl;
}

- (UILabel *)badgeLbl {
    if (!_badgeLbl) {
        _badgeLbl = [[UILabel alloc] init];
        _badgeLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _badgeLbl.textColor = [UIColor whiteColor];
        _badgeLbl.backgroundColor = [UIColor redColor];
        _badgeLbl.textAlignment = NSTextAlignmentCenter;
        _badgeLbl.layer.cornerRadius = 10;
        _badgeLbl.layer.masksToBounds = YES;
        _badgeLbl.hidden = YES;
    }
    return _badgeLbl;
}

- (UILabel *)previewLbl {
    if (!_previewLbl) {
        _previewLbl = [[UILabel alloc] init];
        _previewLbl.font = [UIFont systemFontOfSize:13];
        _previewLbl.textColor = [UIColor lightGrayColor];
        _previewLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    return _previewLbl;
}

@end
