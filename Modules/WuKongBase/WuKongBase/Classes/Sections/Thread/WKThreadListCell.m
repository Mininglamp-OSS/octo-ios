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
#import "WKFollowedKeysStore.h"

@interface WKThreadListCell ()

@property (nonatomic, strong) UILabel *iconLbl;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UILabel *statsLbl;
@property (nonatomic, strong) UILabel *previewLbl;
@property (nonatomic, strong) UILabel *badgeLbl;
@property (nonatomic, strong) UIImageView *followIcon;
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
    [self.contentView addSubview:self.followIcon];
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

    // 最后消息预览 + @提醒
    WKChannel *threadChannel = [WKChannel channelID:model.channelId channelType:WK_COMMUNITY_TOPIC];
    WKConversation *threadConv = [[WKSDK shared].conversationManager getConversation:threadChannel];

    // 检查@提醒
    NSArray<WKReminder *> *reminders = [[WKReminderDB shared] getWaitDoneReminder:threadChannel];
    BOOL hasMention = NO;
    for (WKReminder *r in reminders) {
        if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
    }

    // 获取最新的消息预览（优先从 SDK 会话获取）
    NSString *lastContent = nil;
    if (threadConv && threadConv.lastMessage && threadConv.lastMessage.content) {
        NSString *digest = [threadConv.lastMessage.content conversationDigest];
        if (digest.length > 0) {
            WKChannelInfo *senderInfo = [[WKSDK shared].channelManager getChannelInfo:[WKChannel personWithChannelID:threadConv.lastMessage.fromUid]];
            NSString *senderName = senderInfo ? senderInfo.displayName : threadConv.lastMessage.fromUid;
            lastContent = senderName.length > 0 ? [NSString stringWithFormat:@"%@: %@", senderName, digest] : digest;
        }
    }
    if (!lastContent && model.lastMessageContent.length > 0 && model.lastMessageSenderName.length > 0) {
        lastContent = [NSString stringWithFormat:@"%@: %@", model.lastMessageSenderName, model.lastMessageContent];
    }

    if (hasMention) {
        self.previewLbl.hidden = NO;
        NSString *mentionPrefix = LLang(@"[有人@我]");
        NSString *fullText = lastContent.length > 0 ? [NSString stringWithFormat:@"%@ %@", mentionPrefix, lastContent] : mentionPrefix;
        NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:fullText];
        [attrText addAttribute:NSForegroundColorAttributeName value:[UIColor orangeColor] range:NSMakeRange(0, mentionPrefix.length)];
        if (fullText.length > mentionPrefix.length) {
            [attrText addAttribute:NSForegroundColorAttributeName value:[UIColor lightGrayColor] range:NSMakeRange(mentionPrefix.length, fullText.length - mentionPrefix.length)];
        }
        self.previewLbl.attributedText = attrText;
    } else if (lastContent.length > 0) {
        self.previewLbl.hidden = NO;
        self.previewLbl.attributedText = nil;
        self.previewLbl.textColor = [UIColor lightGrayColor];
        self.previewLbl.text = lastContent;
    } else {
        self.previewLbl.hidden = YES;
    }

    // 未读红点
    NSInteger unread = model.unreadCount;
    if (threadConv) unread = threadConv.unreadCount;
    if (unread > 0) {
        self.badgeLbl.hidden = NO;
        self.badgeLbl.text = unread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unread];
    } else {
        self.badgeLbl.hidden = YES;
    }

    // 已关注 / 未关注 视觉标识：右上角小五角星
    //  - followed: 实心金色（与 iOS 邮件 / 文件 app 的「收藏」语义一致，扫一眼即可识别）
    //  - 未 followed: 描边浅灰（保持存在感、提示用户可关注，但不喧宾夺主）
    // 不可点击 — 状态切换走 cell 的长按菜单（与会话列表对齐），避免误触。
    // 图像形状/颜色/尺寸固定，cache 一次，避免每次 refresh + 滚动时反复跑 Core
    // Graphics 描点（PR review #15 warning）。
    BOOL isFollowed = [[WKFollowedKeysStore shared] isFollowedWithType:WKFollowTargetTypeThread
                                                              targetId:model.channelId ?: @""];
    self.followIcon.image = isFollowed
        ? [WKThreadListCell cachedStarFilledIcon]
        : [WKThreadListCell cachedStarOutlineIcon];

    [self setNeedsLayout];
}

+ (UIImage *)cachedStarFilledIcon {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIColor *followedColor = [UIColor colorWithRed:1.0 green:0.72 blue:0.0 alpha:1.0]; // #FFB800 金色
        img = [WKThreadListCell starFilledIcon:CGSizeMake(14, 14) color:followedColor];
    });
    return img;
}

+ (UIImage *)cachedStarOutlineIcon {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIColor *unfollowedColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        img = [WKThreadListCell starOutlineIcon:CGSizeMake(14, 14) color:unfollowedColor];
    });
    return img;
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

    // 关注 / 未关注 标识：紧贴红点左侧（无红点时直接靠右），与 nameLbl 同基线
    CGFloat followIconW = 14;
    CGFloat followIconH = 14;
    CGFloat followIconX = self.contentView.lim_width - padding - badgeRight - followIconW;
    self.followIcon.frame = CGRectMake(followIconX, 16 + (20 - followIconH) / 2.0, followIconW, followIconH);
    CGFloat followReserve = followIconW + 6;

    // 名称
    CGFloat textLeft = self.iconLbl.lim_right + 10;
    CGFloat textWidth = contentWidth - (textLeft - padding) - badgeRight - followReserve;
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

- (UIImageView *)followIcon {
    if (!_followIcon) {
        _followIcon = [[UIImageView alloc] init];
        _followIcon.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _followIcon;
}

#pragma mark - 关注状态图标（cell 级别，14pt 小图标，与 WKFloatingMenu 菜单图标分离）

/// 实心五角星 — 已关注状态。整星填色，无描边，14pt 时清晰可辨。
+ (UIImage *)starFilledIcon:(CGSize)s color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [color setFill];
    CGFloat cx = s.width / 2.0, cy = s.height / 2.0;
    CGFloat outerR = MIN(s.width, s.height) / 2.0 - 0.5;
    CGFloat innerR = outerR * 0.42;
    for (int i = 0; i < 10; i++) {
        CGFloat r = (i % 2 == 0) ? outerR : innerR;
        CGFloat a = -M_PI / 2 + i * M_PI / 5;
        CGFloat x = cx + r * cos(a);
        CGFloat y = cy + r * sin(a);
        if (i == 0) CGContextMoveToPoint(ctx, x, y);
        else CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/// 描边五角星 — 未关注状态。1pt 描边、不填色，存在感低、提示用户"可关注"。
+ (UIImage *)starOutlineIcon:(CGSize)s color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [color setStroke];
    CGContextSetLineWidth(ctx, 1.0);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGFloat cx = s.width / 2.0, cy = s.height / 2.0;
    CGFloat outerR = MIN(s.width, s.height) / 2.0 - 1.0;
    CGFloat innerR = outerR * 0.42;
    for (int i = 0; i < 10; i++) {
        CGFloat r = (i % 2 == 0) ? outerR : innerR;
        CGFloat a = -M_PI / 2 + i * M_PI / 5;
        CGFloat x = cx + r * cos(a);
        CGFloat y = cy + r * sin(a);
        if (i == 0) CGContextMoveToPoint(ctx, x, y);
        else CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextClosePath(ctx);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
