//
//  WKConversationGroupThreadCell.m
//  WuKongBase
//

#import "WKConversationGroupThreadCell.h"
#import "WKThreadModel.h"
#import "WKTimeTool.h"
#import "WKBadgeView.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import <SDWebImage/UIImageView+WebCache.h>

// 弧线绘制视图
@interface WKThreadBranchView : UIView
@property (nonatomic, assign) NSInteger branchCount;
@property (nonatomic, assign) CGFloat rowHeight;
@property (nonatomic, assign) CGFloat firstRowTop;
@end

@implementation WKThreadBranchView
- (void)drawRect:(CGRect)rect {
    UIColor *lineColor = [[WKApp shared].config.themeColor colorWithAlphaComponent:0.3];
    [lineColor setStroke];

    for (NSInteger i = 0; i < self.branchCount; i++) {
        CGFloat rowCenterY = self.firstRowTop + i * self.rowHeight + self.rowHeight / 2.0f;
        UIBezierPath *path = [UIBezierPath bezierPath];
        path.lineWidth = 1.5f;
        path.lineCapStyle = kCGLineCapRound;

        if (i < self.branchCount - 1) {
            // 非最后一个：竖线 + 横向弧线分支
            [path moveToPoint:CGPointMake(rect.size.width / 2.0f, 0)];
            [path addLineToPoint:CGPointMake(rect.size.width / 2.0f, rowCenterY - 6)];
            [path addQuadCurveToPoint:CGPointMake(rect.size.width, rowCenterY)
                         controlPoint:CGPointMake(rect.size.width / 2.0f, rowCenterY)];
        } else {
            // 最后一个：竖线到此结束 + 弧线
            [path moveToPoint:CGPointMake(rect.size.width / 2.0f, 0)];
            [path addLineToPoint:CGPointMake(rect.size.width / 2.0f, rowCenterY - 6)];
            [path addQuadCurveToPoint:CGPointMake(rect.size.width, rowCenterY)
                         controlPoint:CGPointMake(rect.size.width / 2.0f, rowCenterY)];
        }
        [path stroke];
    }
}
@end

#pragma mark - Cell

@interface WKConversationGroupThreadCell ()

// 顶部区域（群组信息）
@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UILabel *timeLbl;
@property (nonatomic, strong) UILabel *subtitleLbl;
@property (nonatomic, strong) WKBadgeView *badgeView;
@property (nonatomic, strong) UIImageView *muteIcon;

// 子区预览区域
@property (nonatomic, strong) UIView *threadContainer;
@property (nonatomic, strong) WKThreadBranchView *branchView;
@property (nonatomic, strong) UILabel *moreLbl;
@property (nonatomic, strong) UILabel *moreBadgeLbl;
@property (nonatomic, strong) UIView *separatorLine;

// 预创建的 2 个固定预览行（不动态增删）
@property (nonatomic, strong) NSArray<UIView *> *previewRows;
// 每行内的子视图引用
@property (nonatomic, strong) NSArray<UIImageView *> *rowHashIcons; // 矢量 # 图标
@property (nonatomic, strong) NSArray<UILabel *> *rowNameLbls;
@property (nonatomic, strong) NSArray<UILabel *> *rowTimeLbls;
@property (nonatomic, strong) NSArray<UILabel *> *rowMsgLbls;
@property (nonatomic, strong) NSArray<UILabel *> *rowBadgeLbls;

@property (nonatomic, strong) WKConversationWrapModel *model;
@property (nonatomic, strong) UIButton *threadToggleBtn;

@end

@implementation WKConversationGroupThreadCell

#define TOP_HEIGHT 48.0f
#define THREAD_ROW_HEIGHT 32.0f
#define MORE_HEIGHT 26.0f
#define HASH_TAG_SIZE 36.0f
#define HASH_TAG_LEFT 15.0f
#define CONTENT_LEFT 57.0f
#define RIGHT_PADDING 15.0f

+(CGFloat) heightForModel:(WKConversationWrapModel *)model {
    // 检查是否有 @我 提醒
    BOOL hasMention = NO;
    if (model.simpleReminders.count > 0) {
        for (WKReminder *r in model.simpleReminders) {
            if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
        }
    }
    CGFloat topH = hasMention ? (TOP_HEIGHT + 10) : TOP_HEIGHT;
    if (!model.threadPreviews || model.threadPreviews.count == 0) {
        return topH;
    }
    CGFloat h = topH;
    // 子区行高：有@提醒的行更高
    for (WKThreadModel *t in model.threadPreviews) {
        WKChannel *tc = [WKChannel channelID:t.channelId channelType:WK_COMMUNITY_TOPIC];
        NSArray<WKReminder *> *rems = [[WKReminderDB shared] getWaitDoneReminder:tc];
        BOOL tMention = NO;
        for (WKReminder *r in rems) { if (r.type == WKReminderTypeMentionMe) { tMention = YES; break; } }
        h += tMention ? 44.0f : THREAD_ROW_HEIGHT;
    }
    if (model.threadCount > (NSInteger)model.threadPreviews.count) {
        h += MORE_HEIGHT;
    }
    return h + 6.0f;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    // 群头像
    self.avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, HASH_TAG_SIZE, HASH_TAG_SIZE)];
    [self.contentView addSubview:self.avatarView];

    // 标题
    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.titleLbl];

    // 折叠按钮
    self.threadToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *toggleIcon = [WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(14, 14) color:[WKApp shared].config.themeColor];
    [self.threadToggleBtn setImage:toggleIcon forState:UIControlStateNormal];
    self.threadToggleBtn.contentEdgeInsets = UIEdgeInsetsMake(11, 11, 11, 11);
    [self.threadToggleBtn addTarget:self action:@selector(onToggleTap) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.threadToggleBtn];

    // 时间（保留但隐藏）
    self.timeLbl = [[UILabel alloc] init];
    self.timeLbl.font = [[WKApp shared].config appFontOfSize:11.0f];
    self.timeLbl.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.timeLbl.hidden = YES;
    [self.contentView addSubview:self.timeLbl];

    // 副标题（保留但隐藏）
    self.subtitleLbl = [[UILabel alloc] init];
    self.subtitleLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
    self.subtitleLbl.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.subtitleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    self.subtitleLbl.hidden = YES;
    [self.contentView addSubview:self.subtitleLbl];

    // 红点
    self.badgeView = [WKBadgeView viewWithoutBadgeTip];
    [self.contentView addSubview:self.badgeView];

    // 免打扰
    self.muteIcon = [[UIImageView alloc] initWithImage:[WKApp.shared loadImage:@"ConversationList/Index/Mute" moduleID:@"WuKongBase"]];
    self.muteIcon.hidden = YES;
    [self.contentView addSubview:self.muteIcon];

    // 弧线
    self.branchView = [[WKThreadBranchView alloc] init];
    self.branchView.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:self.branchView];

    // 子区容器
    self.threadContainer = [[UIView alloc] init];
    self.threadContainer.layer.cornerRadius = 8.0f;
    self.threadContainer.layer.masksToBounds = YES;
    [self.contentView addSubview:self.threadContainer];

    // 生成矢量 # 图标
    UIImage *channelIcon = [WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(16, 16) color:[UIColor colorWithRed:148.0f/255.0f green:152.0f/255.0f blue:168.0f/255.0f alpha:1.0f]];

    // 预创建 2 个固定预览行
    NSMutableArray *rows = [NSMutableArray array];
    NSMutableArray *hashIcons = [NSMutableArray array];
    NSMutableArray *nameLbls = [NSMutableArray array];
    NSMutableArray *timeLbls = [NSMutableArray array];
    NSMutableArray *msgLbls = [NSMutableArray array];
    NSMutableArray *badgeLbls = [NSMutableArray array];
    for (NSInteger i = 0; i < 2; i++) {
        UIView *row = [[UIView alloc] init];
        row.hidden = YES;
        row.tag = 2000 + i;
        row.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(threadRowTapped:)];
        [row addGestureRecognizer:tap];
        [self.threadContainer addSubview:row];
        [rows addObject:row];

        // 矢量 # 图标
        UIImageView *hashIcon = [[UIImageView alloc] initWithImage:channelIcon];
        hashIcon.contentMode = UIViewContentModeScaleAspectFit;
        [row addSubview:hashIcon];
        [hashIcons addObject:hashIcon];

        UILabel *name = [[UILabel alloc] init];
        name.font = [[WKApp shared].config appFontOfSizeMedium:14.0f];
        name.textColor = [WKApp shared].config.defaultTextColor;
        name.lineBreakMode = NSLineBreakByTruncatingTail;
        [row addSubview:name];
        [nameLbls addObject:name];

        // 时间（保留但隐藏）
        UILabel *time = [[UILabel alloc] init];
        time.font = [[WKApp shared].config appFontOfSize:10.0f];
        time.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        time.hidden = YES;
        [row addSubview:time];
        [timeLbls addObject:time];

        // 消息（保留但隐藏）
        UILabel *msg = [[UILabel alloc] init];
        msg.font = [[WKApp shared].config appFontOfSize:12.0f];
        msg.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        msg.lineBreakMode = NSLineBreakByTruncatingTail;
        msg.hidden = YES;
        [row addSubview:msg];
        [msgLbls addObject:msg];

        UILabel *badge = [[UILabel alloc] init];
        badge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        badge.textColor = [UIColor whiteColor];
        badge.backgroundColor = [UIColor redColor];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.layer.cornerRadius = 9;
        badge.layer.masksToBounds = YES;
        badge.hidden = YES;
        [row addSubview:badge];
        [badgeLbls addObject:badge];
    }
    self.previewRows = rows;
    self.rowHashIcons = hashIcons;
    self.rowNameLbls = nameLbls;
    self.rowTimeLbls = timeLbls;
    self.rowMsgLbls = msgLbls;
    self.rowBadgeLbls = badgeLbls;

    // 分割线
    self.separatorLine = [[UIView alloc] init];
    self.separatorLine.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
    self.separatorLine.hidden = YES;
    [self.threadContainer addSubview:self.separatorLine];

    // 更多
    self.moreLbl = [[UILabel alloc] init];
    self.moreLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    self.moreLbl.textColor = [WKApp shared].config.themeColor;
    self.moreLbl.hidden = YES;
    [self.contentView addSubview:self.moreLbl];

    // 更多行的未读红点
    self.moreBadgeLbl = [[UILabel alloc] init];
    self.moreBadgeLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.moreBadgeLbl.textColor = [UIColor whiteColor];
    self.moreBadgeLbl.backgroundColor = [UIColor redColor];
    self.moreBadgeLbl.textAlignment = NSTextAlignmentCenter;
    self.moreBadgeLbl.layer.cornerRadius = 9;
    self.moreBadgeLbl.layer.masksToBounds = YES;
    self.moreBadgeLbl.hidden = YES;
    [self.contentView addSubview:self.moreBadgeLbl];
}

-(void) refreshWithModel:(WKConversationWrapModel *)model {
    self.model = model;
    BOOL hasChannelInfo = model.channelInfo ? YES : NO;
    if (!hasChannelInfo) {
        [model startChannelRequest];
    }

    // 加载群头像
    [self refreshAvatar:model];

    // 隐藏时间
    self.timeLbl.hidden = YES;

    // 检查是否有 @我 提醒
    BOOL hasMention = NO;
    if (model.simpleReminders && model.simpleReminders.count > 0) {
        for (WKReminder *r in model.simpleReminders) {
            if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
        }
    }
    if (hasMention) {
        self.subtitleLbl.hidden = NO;
        NSString *reminderText = @"";
        for (WKReminder *r in model.simpleReminders) {
            if (r.type == WKReminderTypeMentionMe) {
                reminderText = r.text ?: @"";
                break;
            }
        }
        NSString *content = model.content ?: @"";
        self.subtitleLbl.text = [NSString stringWithFormat:@"%@ %@", reminderText, content];
        self.subtitleLbl.textColor = [UIColor orangeColor];
    } else {
        self.subtitleLbl.hidden = YES;
    }

    // 标题
    self.titleLbl.text = hasChannelInfo ? model.channelInfo.displayName : LLang(@"群聊");

    // 红点
    self.badgeView.hidden = YES;
    if (model.unreadCount > 0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = [NSString stringWithFormat:@"%ld", (long)model.unreadCount];
        self.badgeView.lim_left = self.contentView.lim_width - RIGHT_PADDING - self.badgeView.lim_width;
    }

    // 免打扰
    if (model.mute) {
        self.muteIcon.hidden = (model.unreadCount > 0);
        [self.badgeView setBadgeBackgroundColor:[UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f]];
    } else {
        self.muteIcon.hidden = YES;
        [self.badgeView setBadgeBackgroundColor:[UIColor redColor]];
    }

    // 子区预览：只更新固定视图的数据，不增删视图
    [self updateThreadPreviews];
    [self setNeedsLayout];
}

/// 更新预创建的固定预览行数据（无 add/remove，不闪烁）
-(void) updateThreadPreviews {
    NSArray<WKThreadModel *> *previews = self.model.threadPreviews;
    NSInteger count = previews ? previews.count : 0;
    BOOL hasPreview = (count > 0);

    self.threadContainer.hidden = !hasPreview;
    self.branchView.hidden = !hasPreview;
    if (hasPreview) {
        self.threadContainer.backgroundColor = [WKApp shared].config.backgroundColor;
    }

    for (NSInteger i = 0; i < 2; i++) {
        UIView *row = self.previewRows[i];
        if (i < count) {
            WKThreadModel *thread = previews[i];
            row.hidden = NO;

            // 名称
            self.rowNameLbls[i].text = thread.name;

            // 时间隐藏
            self.rowTimeLbls[i].hidden = YES;

            // 检查子区是否有@提醒
            WKChannel *threadChannel = [WKChannel channelID:thread.channelId channelType:WK_COMMUNITY_TOPIC];
            NSArray<WKReminder *> *threadReminders = [[WKReminderDB shared] getWaitDoneReminder:threadChannel];
            BOOL threadHasMention = NO;
            for (WKReminder *r in threadReminders) {
                if (r.type == WKReminderTypeMentionMe) { threadHasMention = YES; break; }
            }
            if (threadHasMention) {
                self.rowMsgLbls[i].hidden = NO;
                // 显示 [有人@我] + 最后一条消息预览
                WKConversation *tConv = [[WKSDK shared].conversationManager getConversation:threadChannel];
                NSString *lastContent = @"";
                if (tConv && tConv.lastMessage && tConv.lastMessage.content) {
                    lastContent = [tConv.lastMessage.content conversationDigest] ?: @"";
                } else if (thread.lastMessageContent.length > 0) {
                    lastContent = thread.lastMessageContent;
                }
                self.rowMsgLbls[i].text = [NSString stringWithFormat:@"%@ %@", LLang(@"[有人@我]"), lastContent];
                self.rowMsgLbls[i].textColor = [UIColor orangeColor];
                self.rowMsgLbls[i].font = [[WKApp shared].config appFontOfSize:11.0f];
            } else {
                self.rowMsgLbls[i].hidden = YES;
            }

            // 红点（父群聊静音时用浅蓝色，否则红色）
            WKConversation *threadConv = [[WKSDK shared].conversationManager getConversation:threadChannel];
            NSInteger unread = thread.unreadCount;
            if (threadConv) unread = threadConv.unreadCount;
            if (unread > 0) {
                self.rowBadgeLbls[i].hidden = NO;
                self.rowBadgeLbls[i].text = unread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unread];
                // 继承父群聊 mute 状态：静音时红点变浅蓝色
                if (self.model.mute) {
                    self.rowBadgeLbls[i].backgroundColor = [UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f];
                } else {
                    self.rowBadgeLbls[i].backgroundColor = [UIColor redColor];
                }
            } else {
                self.rowBadgeLbls[i].hidden = YES;
            }
        } else {
            row.hidden = YES;
        }
    }

    // 分割线：只在有 2 个预览行时显示
    self.separatorLine.hidden = (count < 2);

    // 更多
    if (self.model.threadCount > count) {
        self.moreLbl.hidden = NO;
        self.moreLbl.userInteractionEnabled = YES;
        if (self.moreLbl.gestureRecognizers.count == 0) {
            UITapGestureRecognizer *moreTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMoreTap)];
            [self.moreLbl addGestureRecognizer:moreTap];
        }

        // 计算未预览子区的未读数和@提醒
        NSString *groupNo = self.model.channel.channelId;
        NSString *prefix = [NSString stringWithFormat:@"%@____", groupNo];
        NSMutableSet *previewedIds = [NSMutableSet set];
        for (NSInteger i = 0; i < count; i++) {
            [previewedIds addObject:previews[i].channelId];
        }
        NSInteger moreUnread = 0;
        BOOL moreMention = NO;
        NSArray<WKConversation *> *allConvs = [[WKSDK shared].conversationManager getConversationList];
        for (WKConversation *conv in allConvs) {
            if (conv.channel.channelType == WK_COMMUNITY_TOPIC
                && [conv.channel.channelId hasPrefix:prefix]
                && ![previewedIds containsObject:conv.channel.channelId]) {
                moreUnread += conv.unreadCount;
                if (!moreMention) {
                    NSArray<WKReminder *> *rems = [[WKReminderDB shared] getWaitDoneReminder:conv.channel];
                    for (WKReminder *r in rems) {
                        if (r.type == WKReminderTypeMentionMe) { moreMention = YES; break; }
                    }
                }
            }
        }

        // 构建文本：+N个子区 [有人@我]
        NSString *moreText = [NSString stringWithFormat:@"+%ld %@", (long)(self.model.threadCount - count), LLang(@"个子区")];
        if (moreMention) {
            NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:moreText attributes:@{NSForegroundColorAttributeName: [WKApp shared].config.themeColor}];
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", LLang(@"[有人@我]")] attributes:@{NSForegroundColorAttributeName: [UIColor orangeColor]}]];
            self.moreLbl.attributedText = attrText;
        } else {
            self.moreLbl.text = moreText;
            self.moreLbl.textColor = [WKApp shared].config.themeColor;
        }

        if (moreUnread > 0) {
            self.moreBadgeLbl.hidden = NO;
            self.moreBadgeLbl.text = moreUnread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)moreUnread];
            self.moreBadgeLbl.backgroundColor = self.model.mute ? [UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f] : [UIColor redColor];
        } else {
            self.moreBadgeLbl.hidden = YES;
        }
    } else {
        self.moreLbl.hidden = YES;
        self.moreBadgeLbl.hidden = YES;
    }
}


-(void) onMoreTap {
    if (self.onMoreThreadsTap && self.model.channel.channelId.length > 0) {
        self.onMoreThreadsTap(self.model.channel.channelId);
    }
}

-(void) threadRowTapped:(UITapGestureRecognizer *)tap {
    NSInteger index = tap.view.tag - 2000;
    NSArray *previews = self.model.threadPreviews;
    if (previews && index >= 0 && index < (NSInteger)previews.count) {
        WKThreadModel *t = previews[index];
        if (self.onThreadPreviewTap && t.channelId.length > 0) {
            self.onThreadPreviewTap(t.channelId);
        }
    }
}

-(void) onToggleTap {
    if (self.onToggleThreadPreview && self.model.channel.channelId.length > 0) {
        self.onToggleThreadPreview(self.model.channel.channelId);
    }
}

-(void) refreshAvatar:(WKConversationWrapModel*)model {
    UIImage *placeholder = [WKApp.shared loadImage:@"Common/Index/DefaultAvatar" moduleID:@"WuKongBase"];
    self.avatarView.avatarImgView.image = placeholder;
    if (model.channelInfo) {
        NSString *avatarURL;
        if ([model.channelInfo.logo hasPrefix:@"http"]) {
            NSString *key = (model.channelInfo.avatarCacheKey.length > 0) ? model.channelInfo.avatarCacheKey : @"0";
            NSString *sep = [model.channelInfo.logo containsString:@"?"] ? @"&" : @"?";
            avatarURL = [NSString stringWithFormat:@"%@%@v=%@", model.channelInfo.logo, sep, key];
        } else {
            avatarURL = [WKAvatarUtil getGroupAvatar:model.channel.channelId cacheKey:model.channelInfo.avatarCacheKey];
        }
        [self.avatarView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:avatarURL]
                                          placeholderImage:placeholder
                                                   options:0
                                                   context:@{SDWebImageContextStoreCacheType: @(SDImageCacheTypeAll)}];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.contentView.lim_width;

    BOOL showMention = !self.subtitleLbl.hidden;
    CGFloat topH = showMention ? (TOP_HEIGHT + 10) : TOP_HEIGHT;

    // 群头像
    self.avatarView.frame = CGRectMake(HASH_TAG_LEFT, showMention ? 8.0f : (topH - HASH_TAG_SIZE) / 2.0f, HASH_TAG_SIZE, HASH_TAG_SIZE);

    // 标题
    CGFloat titleRight = w - RIGHT_PADDING - 50.0f;
    if (showMention) {
        self.titleLbl.frame = CGRectMake(CONTENT_LEFT, 8.0f, titleRight - CONTENT_LEFT, 20);
        self.subtitleLbl.frame = CGRectMake(CONTENT_LEFT, self.titleLbl.lim_bottom + 2, titleRight - CONTENT_LEFT, 18);
    } else {
        self.titleLbl.frame = CGRectMake(CONTENT_LEFT, (topH - 20) / 2.0f, titleRight - CONTENT_LEFT, 20);
    }

    // 折叠按钮（标题右侧）
    [self.titleLbl sizeToFit];
    if (self.titleLbl.lim_width > titleRight - CONTENT_LEFT) self.titleLbl.lim_width = titleRight - CONTENT_LEFT;
    self.threadToggleBtn.frame = CGRectMake(self.titleLbl.lim_right - 4, self.titleLbl.lim_top + (self.titleLbl.lim_height - 36) / 2.0f, 36, 36);

    // 红点 - 垂直居中在顶部区域
    self.badgeView.lim_left = w - RIGHT_PADDING - self.badgeView.lim_width;
    self.badgeView.lim_top = (topH - self.badgeView.lim_height) / 2.0f;

    // 免打扰
    self.muteIcon.lim_left = w - RIGHT_PADDING - self.muteIcon.lim_width;
    self.muteIcon.lim_top = (topH - self.muteIcon.lim_height) / 2.0f;

    // 子区预览区域
    NSArray *previews = self.model.threadPreviews;
    if (previews && previews.count > 0) {
        CGFloat containerTop = topH;
        CGFloat containerWidth = w - CONTENT_LEFT - RIGHT_PADDING;

        // 计算每行高度
        CGFloat rowHeights[2] = {THREAD_ROW_HEIGHT, THREAD_ROW_HEIGHT};
        for (NSInteger i = 0; i < 2 && i < (NSInteger)previews.count; i++) {
            if (!self.rowMsgLbls[i].hidden) rowHeights[i] = 44.0f;
        }
        CGFloat containerHeight = 0;
        for (NSInteger i = 0; i < (NSInteger)previews.count && i < 2; i++) containerHeight += rowHeights[i];

        self.threadContainer.frame = CGRectMake(CONTENT_LEFT, containerTop, containerWidth, containerHeight);

        CGFloat iconSize = 16.0f;
        CGFloat nameLeft = 10 + iconSize + 6;
        CGFloat rowY = 0;
        for (NSInteger i = 0; i < 2; i++) {
            UIView *row = self.previewRows[i];
            if (row.hidden) continue;
            CGFloat rh = rowHeights[i];
            row.frame = CGRectMake(0, rowY, containerWidth, rh);

            // 矢量 # 图标
            self.rowHashIcons[i].frame = CGRectMake(10, 8, iconSize, iconSize);

            // 红点
            UILabel *badge = self.rowBadgeLbls[i];
            CGFloat nameRight = containerWidth - 10;
            if (!badge.hidden) {
                [badge sizeToFit];
                CGFloat badgeW = MAX(badge.lim_width + 8, 18);
                badge.frame = CGRectMake(containerWidth - 10 - badgeW, 8, badgeW, 18);
                nameRight = badge.lim_left - 4;
            }

            // 名称和@提醒
            UILabel *msgLbl = self.rowMsgLbls[i];
            if (!msgLbl.hidden) {
                self.rowNameLbls[i].frame = CGRectMake(nameLeft, 6, nameRight - nameLeft, 16);
                msgLbl.frame = CGRectMake(nameLeft, 23, nameRight - nameLeft, 15);
            } else {
                self.rowNameLbls[i].frame = CGRectMake(nameLeft, (rh - 17) / 2.0f, nameRight - nameLeft, 17);
            }
            rowY += rh;
        }

        // 分割线
        if (!self.separatorLine.hidden) {
            self.separatorLine.frame = CGRectMake(10, rowHeights[0] - 0.5f, containerWidth - 20, 0.5f);
        }

        // 弧线
        CGFloat hashCenterX = HASH_TAG_LEFT + HASH_TAG_SIZE / 2.0f;
        CGFloat branchWidth = CONTENT_LEFT - hashCenterX;
        CGFloat hashBottom = self.avatarView.lim_top + HASH_TAG_SIZE;
        CGFloat branchHeight = containerTop + containerHeight - hashBottom;

        self.branchView.frame = CGRectMake(hashCenterX - branchWidth / 2.0f, hashBottom, branchWidth, branchHeight);
        self.branchView.branchCount = previews.count;
        self.branchView.rowHeight = THREAD_ROW_HEIGHT;
        self.branchView.firstRowTop = containerTop - hashBottom;
        [self.branchView setNeedsDisplay];

        // 更多
        if (!self.moreLbl.hidden) {
            self.moreLbl.frame = CGRectMake(CONTENT_LEFT + 10, containerTop + containerHeight + 2, containerWidth - 60, MORE_HEIGHT - 4);
            // 红点
            if (!self.moreBadgeLbl.hidden) {
                [self.moreBadgeLbl sizeToFit];
                CGFloat badgeW = MAX(self.moreBadgeLbl.lim_width + 8, 18);
                self.moreBadgeLbl.frame = CGRectMake(w - RIGHT_PADDING - badgeW, self.moreLbl.lim_top + (MORE_HEIGHT - 4 - 18) / 2.0, badgeW, 18);
            }
        }
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.avatarView.avatarImgView.image = nil;
    self.badgeView.hidden = YES;
    self.muteIcon.hidden = YES;
    self.threadContainer.hidden = YES;
    self.branchView.hidden = YES;
    self.moreLbl.hidden = YES;
    self.moreBadgeLbl.hidden = YES;
    self.onThreadPreviewTap = nil;
    self.onMoreThreadsTap = nil;
    self.onToggleThreadPreview = nil;
}

/// Convert SVG arc endpoint parameterization to center parameterization,
/// then approximate with cubic bezier curves (SVG spec F.6.5)
+ (void)addSVGArcToPath:(UIBezierPath *)path
                   fromX:(CGFloat)x1 fromY:(CGFloat)y1
                      rx:(CGFloat)inRx ry:(CGFloat)inRy xRot:(CGFloat)xRot
                largeArc:(BOOL)largeArc sweep:(BOOL)sweep
                     toX:(CGFloat)x2 toY:(CGFloat)y2 {
    if (x1 == x2 && y1 == y2) return;
    CGFloat rx = fabs(inRx), ry = fabs(inRy);
    if (rx == 0 || ry == 0) { [path addLineToPoint:CGPointMake(x2, y2)]; return; }

    CGFloat cosR = cos(xRot), sinR = sin(xRot);
    CGFloat dx = (x1 - x2) / 2.0, dy = (y1 - y2) / 2.0;
    CGFloat x1p = cosR * dx + sinR * dy;
    CGFloat y1p = -sinR * dx + cosR * dy;

    CGFloat x1p2 = x1p * x1p, y1p2 = y1p * y1p;
    CGFloat rx2 = rx * rx, ry2 = ry * ry;
    CGFloat lambda = x1p2 / rx2 + y1p2 / ry2;
    if (lambda > 1.0) { CGFloat s = sqrt(lambda); rx *= s; ry *= s; rx2 = rx*rx; ry2 = ry*ry; }

    CGFloat num = fmax(0, rx2*ry2 - rx2*y1p2 - ry2*x1p2);
    CGFloat den = rx2*y1p2 + ry2*x1p2;
    CGFloat sq = (den > 0) ? sqrt(num / den) : 0;
    if (largeArc == sweep) sq = -sq;
    CGFloat cxp = sq * rx * y1p / ry;
    CGFloat cyp = -sq * ry * x1p / rx;

    CGFloat cx = cosR*cxp - sinR*cyp + (x1+x2)/2.0;
    CGFloat cy = sinR*cxp + cosR*cyp + (y1+y2)/2.0;

    CGFloat ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry;
    CGFloat vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry;
    CGFloat theta1 = atan2(uy, ux);
    CGFloat n = sqrt(ux*ux+uy*uy) * sqrt(vx*vx+vy*vy);
    CGFloat cosVal = (n != 0) ? (ux*vx+uy*vy)/n : 0;
    cosVal = fmax(-1, fmin(1, cosVal));
    CGFloat dtheta = ((ux*vy - uy*vx) < 0 ? -1 : 1) * acos(cosVal);
    if (!sweep && dtheta > 0) dtheta -= 2*M_PI;
    if (sweep && dtheta < 0) dtheta += 2*M_PI;

    NSInteger segs = (NSInteger)ceil(fabs(dtheta) / (M_PI/2.0));
    if (segs < 1) segs = 1;
    CGFloat segAngle = dtheta / segs;

    for (NSInteger i = 0; i < segs; i++) {
        CGFloat t1 = theta1 + i * segAngle;
        CGFloat t2 = theta1 + (i+1) * segAngle;
        CGFloat half = segAngle / 2.0;
        CGFloat tanHalf = tan(half);
        CGFloat alpha = sin(segAngle) * (sqrt(4.0 + 3.0*tanHalf*tanHalf) - 1.0) / 3.0;

        CGFloat cos1 = cos(t1), sin1 = sin(t1);
        CGFloat cos2 = cos(t2), sin2 = sin(t2);

        CGFloat cp1x = rx*(cos1 - alpha*sin1), cp1y = ry*(sin1 + alpha*cos1);
        CGFloat cp2x = rx*(cos2 + alpha*sin2), cp2y = ry*(sin2 - alpha*cos2);
        CGFloat epx = rx*cos2, epy = ry*sin2;

        [path addCurveToPoint:CGPointMake(cosR*epx - sinR*epy + cx, sinR*epx + cosR*epy + cy)
                controlPoint1:CGPointMake(cosR*cp1x - sinR*cp1y + cx, sinR*cp1x + cosR*cp1y + cy)
                controlPoint2:CGPointMake(cosR*cp2x - sinR*cp2y + cx, sinR*cp2x + cosR*cp2y + cy)];
    }
}

/// Parse SVG path data string into a UIBezierPath (supports M,m,L,l,A,a,Z,z)
+ (UIBezierPath *)bezierPathFromSVGPathData:(NSString *)pathData {
    UIBezierPath *path = [UIBezierPath bezierPath];

    CGFloat curX = 0, curY = 0, startX = 0, startY = 0;
    NSMutableArray *tokens = [NSMutableArray array];
    NSUInteger len = pathData.length;
    NSUInteger pos = 0;

    // Tokenize: extract command letters and numbers
    while (pos < len) {
        unichar ch = [pathData characterAtIndex:pos];
        if (ch == ' ' || ch == ',' || ch == '\t' || ch == '\n' || ch == '\r') { pos++; continue; }
        if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')) {
            [tokens addObject:[NSString stringWithFormat:@"%C", ch]]; pos++; continue;
        }
        NSUInteger numStart = pos;
        if (ch == '-' || ch == '+') pos++;
        BOOL hasDot = NO;
        while (pos < len) {
            ch = [pathData characterAtIndex:pos];
            if (ch >= '0' && ch <= '9') { pos++; }
            else if (ch == '.' && !hasDot) { hasDot = YES; pos++; }
            else if ((ch == '-' || ch == '+') && pos > numStart) { break; } // new negative number
            else break;
        }
        if (pos > numStart) {
            [tokens addObject:@([[pathData substringWithRange:NSMakeRange(numStart, pos-numStart)] doubleValue])];
        }
    }

    NSUInteger ti = 0;
    unichar lastCmd = 0;

    while (ti < tokens.count) {
        id tok = tokens[ti];
        unichar cmd;
        if ([tok isKindOfClass:[NSString class]]) { cmd = [tok characterAtIndex:0]; ti++; }
        else { cmd = lastCmd; if (cmd == 'M') cmd = 'L'; if (cmd == 'm') cmd = 'l'; }
        lastCmd = cmd;

        switch (cmd) {
            case 'M': { CGFloat x=[tokens[ti++] doubleValue], y=[tokens[ti++] doubleValue];
                [path moveToPoint:CGPointMake(x,y)]; curX=x; curY=y; startX=x; startY=y; break; }
            case 'm': { CGFloat dx=[tokens[ti++] doubleValue], dy=[tokens[ti++] doubleValue];
                curX+=dx; curY+=dy; [path moveToPoint:CGPointMake(curX,curY)]; startX=curX; startY=curY; break; }
            case 'L': { CGFloat x=[tokens[ti++] doubleValue], y=[tokens[ti++] doubleValue];
                [path addLineToPoint:CGPointMake(x,y)]; curX=x; curY=y; break; }
            case 'l': { CGFloat dx=[tokens[ti++] doubleValue], dy=[tokens[ti++] doubleValue];
                curX+=dx; curY+=dy; [path addLineToPoint:CGPointMake(curX,curY)]; break; }
            case 'A': case 'a': {
                CGFloat rx=[tokens[ti++] doubleValue], ry=[tokens[ti++] doubleValue];
                CGFloat xRot=[tokens[ti++] doubleValue]*M_PI/180.0;
                BOOL la=[tokens[ti++] intValue]!=0, sw=[tokens[ti++] intValue]!=0;
                CGFloat x2=[tokens[ti++] doubleValue], y2=[tokens[ti++] doubleValue];
                if (cmd=='a') { x2+=curX; y2+=curY; }
                [self addSVGArcToPath:path fromX:curX fromY:curY rx:rx ry:ry xRot:xRot largeArc:la sweep:sw toX:x2 toY:y2];
                curX=x2; curY=y2; break; }
            case 'Z': case 'z':
                [path closePath]; curX=startX; curY=startY; break;
        }
    }
    return path;
}

/// Generate channel hash icon from Android vector XML path data
+ (UIImage *)channelHashIconWithSize:(CGSize)size color:(UIColor *)color {
    static NSString *svgPath = @"M12,2.81a1,1 0,0 1,0 -1.41l0.36,-0.36a1,1 0,0 1,1.41 0l9.2,9.2a1,1 0,0 1,0 1.4l-0.7,0.7a1,1 0,0 1,-1.3 0.13l-9.54,-6.72a1,1 0,0 1,-0.08 -1.58l1,-1L12,2.8ZM12,21.2a1,1 0,0 1,0 1.41l-0.35,0.35a1,1 0,0 1,-1.41 0l-9.2,-9.19a1,1 0,0 1,0 -1.41l0.7,-0.7a1,1 0,0 1,1.3 -0.12l9.54,6.72a1,1 0,0 1,0.07 1.58l-1,1 0.35,0.36ZM15.66,16.8a1,1 0,0 1,-1.38 0.28l-8.49,-5.66A1,1 0,1 1,6.9 9.76l8.49,5.65a1,1 0,0 1,0.27 1.39ZM17.1,14.25a1,1 0,1 0,1.11 -1.66L9.73,6.93a1,1 0,0 0,-1.11 1.66l8.49,5.66Z";

    UIBezierPath *bezier = [self bezierPathFromSVGPathData:svgPath];

    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;

    // Scale from 24x24 viewport to target size
    CGContextScaleCTM(ctx, size.width / 24.0f, size.height / 24.0f);

    [color setFill];
    [bezier fill];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
