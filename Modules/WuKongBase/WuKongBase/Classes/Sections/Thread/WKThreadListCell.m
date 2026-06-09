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
        [attrText addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(0, mentionPrefix.length)];
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

    // 已关注：实心金色五角星，与 iOS 邮件/文件 app 的「收藏」语义一致。
    // 未关注：直接隐藏图标，避免给每一行都挂个灰描边干扰扫读
    // —— cell 的关注状态切换仍走长按菜单，不依赖 cell 上的视觉提示。
    // 图像形状/颜色/尺寸固定，cache 一次，避免每次 refresh + 滚动时反复跑 Core
    // Graphics 描点（PR review #15 warning）。
    BOOL isFollowed = [[WKFollowedKeysStore shared] isFollowedWithType:WKFollowTargetTypeThread
                                                              targetId:model.channelId ?: @""];
    if (isFollowed) {
        self.followIcon.image = [WKThreadListCell cachedStarFilledIcon];
        self.followIcon.hidden = NO;
    } else {
        self.followIcon.image = nil;
        self.followIcon.hidden = YES;
    }

    // 角色标识：仅创建者显示「管理员」头像。默认情况下用户都是已加入状态，
    // 「已加入」无新信息量，不再单独画图标避免视觉噪音。
    NSString *loginUid = [WKSDK shared].options.connectInfo.uid ?: @"";
    BOOL isCreator = (loginUid.length > 0 && [model.creatorUid isEqualToString:loginUid]);
    if (isCreator) {
        self.roleIcon.image = [WKThreadListCell cachedAdminIcon];
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

+ (UIImage *)cachedAdminIcon {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 头肩人像剪影 —— 跟群主/管理员标识的常用形式一致，比之前的盾形更直观。
        // 用主题色填充。
        UIColor *adminColor = [WKApp shared].config.themeColor ?: [UIColor systemBlueColor];
        img = [WKThreadListCell personIcon:CGSizeMake(14, 14) color:adminColor];
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

    // 关注图标：仅已关注时显示，紧贴红点左侧（无红点时直接靠右）。
    // 未关注时 followIcon 隐藏 + 不占宽度，让 roleIcon / 名称往右扩展。
    CGFloat iconW = 14;
    CGFloat iconH = 14;
    CGFloat iconY = 16 + (20 - iconH) / 2.0;
    CGFloat rightCursor = self.contentView.lim_width - padding - badgeRight; // 当前右锚点
    CGFloat rightReserve = 0;
    if (!self.followIcon.hidden) {
        CGFloat followIconX = rightCursor - iconW;
        self.followIcon.frame = CGRectMake(followIconX, iconY, iconW, iconH);
        rightCursor = followIconX - 4;
        rightReserve += iconW + 6;
    } else {
        self.followIcon.frame = CGRectZero;
    }

    // 角色图标（管理员）：紧贴 followIcon 左侧（若 followIcon 隐藏则直接靠最右）。
    if (!self.roleIcon.hidden) {
        CGFloat roleIconX = rightCursor - iconW;
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

/// 头肩人像剪影 — 管理员/群主标识的常用视觉。整体主题色填充：上方圆头、下方
/// 半圆肩膀，14pt 小尺寸下足够辨识。
+ (UIImage *)personIcon:(CGSize)s color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(s, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = s.width, h = s.height;
    [color setFill];
    // 头：上方圆
    CGFloat headD = w * 0.46;
    CGRect headRect = CGRectMake((w - headD) / 2.0, h * 0.08, headD, headD);
    CGContextFillEllipseInRect(ctx, headRect);
    // 肩膀：底部半圆 / 钟形 —— 用贝塞尔近似
    UIBezierPath *body = [UIBezierPath bezierPath];
    CGFloat bodyTop = h * 0.62;
    CGFloat bodyBottom = h * 0.96;
    CGFloat bodyHalfW = w * 0.42;
    CGFloat cx = w / 2.0;
    [body moveToPoint:CGPointMake(cx - bodyHalfW, bodyBottom)];
    // 左侧上扬到肩颈
    [body addCurveToPoint:CGPointMake(cx, bodyTop)
            controlPoint1:CGPointMake(cx - bodyHalfW, bodyTop + (bodyBottom - bodyTop) * 0.2)
            controlPoint2:CGPointMake(cx - bodyHalfW * 0.55, bodyTop)];
    // 右侧对称下落
    [body addCurveToPoint:CGPointMake(cx + bodyHalfW, bodyBottom)
            controlPoint1:CGPointMake(cx + bodyHalfW * 0.55, bodyTop)
            controlPoint2:CGPointMake(cx + bodyHalfW, bodyTop + (bodyBottom - bodyTop) * 0.2)];
    [body closePath];
    [body fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
