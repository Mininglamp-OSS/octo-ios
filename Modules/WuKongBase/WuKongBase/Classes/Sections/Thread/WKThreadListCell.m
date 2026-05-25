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
#import <WuKongIMSDK/WuKongIMSDK.h>

@interface WKThreadListCell ()

@property (nonatomic, strong) UILabel *iconLbl;
@property (nonatomic, strong) UILabel *nameLbl;
@property (nonatomic, strong) UILabel *statsLbl;
@property (nonatomic, strong) UILabel *previewLbl;
@property (nonatomic, strong) UILabel *badgeLbl;
@property (nonatomic, strong) UIImageView *followIcon;
/// 角色标识（管理员 / 已加入），与 followIcon 同尺寸并排显示。同一时刻最多展示一个：
/// creator → 管理员，非 creator 但 isMember → 已加入；都不是则隐藏。
@property (nonatomic, strong) UIImageView *roleIcon;
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
    [self.contentView addSubview:self.roleIcon];
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

    // 角色标识：管理员（creator）/ 已加入（非 creator 的成员）。和长按菜单里那一组
    // 「归档/删除/退出」的可见性条件完全对齐 —— 用户一眼就知道这条子区能做什么操作。
    // 同 followIcon 套路 cache，不在 refresh 路径上跑 Core Graphics。
    NSString *loginUid = [WKSDK shared].options.connectInfo.uid ?: @"";
    BOOL isCreator = (loginUid.length > 0 && [model.creatorUid isEqualToString:loginUid]);
    if (isCreator) {
        self.roleIcon.image = [WKThreadListCell cachedAdminIcon];
        self.roleIcon.hidden = NO;
    } else if (model.isMember) {
        self.roleIcon.image = [WKThreadListCell cachedJoinedIcon];
        self.roleIcon.hidden = NO;
    } else {
        self.roleIcon.image = nil;
        self.roleIcon.hidden = YES;
    }

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

+ (UIImage *)cachedAdminIcon {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 主题色填充的盾形 + 内嵌「✓」线条 —— 与平台「管理员/创建者」语义一致
        UIColor *adminColor = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
        img = [WKThreadListCell shieldIcon:CGSizeMake(14, 14) color:adminColor];
    });
    return img;
}

+ (UIImage *)cachedJoinedIcon {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 绿色描边圆里 ✓ —— iOS 系统/微信通讯录都是用类似形状表达「已加入/已添加」
        UIColor *joinedColor = [UIColor colorWithRed:0.30 green:0.69 blue:0.31 alpha:1.0]; // #4CAF50
        img = [WKThreadListCell checkmarkCircleIcon:CGSizeMake(14, 14) color:joinedColor];
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
    CGFloat iconW = 14;
    CGFloat iconH = 14;
    CGFloat iconY = 16 + (20 - iconH) / 2.0;
    CGFloat followIconX = self.contentView.lim_width - padding - badgeRight - iconW;
    self.followIcon.frame = CGRectMake(followIconX, iconY, iconW, iconH);
    CGFloat rightReserve = iconW + 6;

    // 角色图标（管理员 / 已加入）：紧贴 followIcon 左侧。隐藏时不占位。
    if (!self.roleIcon.hidden) {
        CGFloat roleIconX = followIconX - 4 - iconW;
        self.roleIcon.frame = CGRectMake(roleIconX, iconY, iconW, iconH);
        rightReserve += iconW + 4;
    } else {
        // 仍然给一个合法 frame，避免 reused cell 残影
        self.roleIcon.frame = CGRectZero;
    }

    // 名称
    CGFloat textLeft = self.iconLbl.lim_right + 10;
    CGFloat textWidth = contentWidth - (textLeft - padding) - badgeRight - rightReserve;
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

- (UIImageView *)roleIcon {
    if (!_roleIcon) {
        _roleIcon = [[UIImageView alloc] init];
        _roleIcon.contentMode = UIViewContentModeScaleAspectFit;
        _roleIcon.hidden = YES;
    }
    return _roleIcon;
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

/// 盾形 + 中心 ✓ — 管理员/创建者标识。整体填充主题色，内嵌白色 ✓ 提示「掌控
/// 权」语义。视觉上比五角星更厚重，避免跟收藏星抢眼。
+ (UIImage *)shieldIcon:(CGSize)s color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = s.width, h = s.height;
    // 盾形：顶部平、底部尖；用贝塞尔近似
    UIBezierPath *shield = [UIBezierPath bezierPath];
    [shield moveToPoint:CGPointMake(w * 0.5, h * 0.06)];
    [shield addLineToPoint:CGPointMake(w * 0.92, h * 0.22)];
    [shield addLineToPoint:CGPointMake(w * 0.92, h * 0.56)];
    [shield addCurveToPoint:CGPointMake(w * 0.5, h * 0.94)
              controlPoint1:CGPointMake(w * 0.92, h * 0.78)
              controlPoint2:CGPointMake(w * 0.72, h * 0.92)];
    [shield addCurveToPoint:CGPointMake(w * 0.08, h * 0.56)
              controlPoint1:CGPointMake(w * 0.28, h * 0.92)
              controlPoint2:CGPointMake(w * 0.08, h * 0.78)];
    [shield addLineToPoint:CGPointMake(w * 0.08, h * 0.22)];
    [shield closePath];
    [color setFill];
    [shield fill];
    // 中间白色 ✓
    [[UIColor whiteColor] setStroke];
    CGContextSetLineWidth(ctx, 1.4);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextMoveToPoint(ctx, w * 0.30, h * 0.50);
    CGContextAddLineToPoint(ctx, w * 0.46, h * 0.66);
    CGContextAddLineToPoint(ctx, w * 0.72, h * 0.38);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/// 描边圆 + 中心 ✓ — 「已加入」标识。绿色描边、白底，与微信通讯录「已添加」
/// 等场景的常用视觉一致。
+ (UIImage *)checkmarkCircleIcon:(CGSize)s color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = s.width, h = s.height;
    // 圆环描边
    [color setStroke];
    CGContextSetLineWidth(ctx, 1.2);
    CGRect circleRect = CGRectInset(CGRectMake(0, 0, w, h), 1.0, 1.0);
    CGContextStrokeEllipseInRect(ctx, circleRect);
    // 中心 ✓
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextSetLineWidth(ctx, 1.4);
    CGContextMoveToPoint(ctx, w * 0.28, h * 0.52);
    CGContextAddLineToPoint(ctx, w * 0.44, h * 0.68);
    CGContextAddLineToPoint(ctx, w * 0.74, h * 0.36);
    CGContextStrokePath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
