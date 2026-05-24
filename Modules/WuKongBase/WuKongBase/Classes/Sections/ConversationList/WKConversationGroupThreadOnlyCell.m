//
//  WKConversationGroupThreadOnlyCell.m
//  WuKongBase
//

#import "WKConversationGroupThreadOnlyCell.h"
#import "WKConversationGroupThreadCell.h"
#import "WKBadgeView.h"
#import "WKUserAvatar.h"
#import "WKAvatarUtil.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "WKConversationListVM.h"

// [ThreadBadgeDbg] 子区 unread / +N 角标调试日志（PR #137 review 反馈）：
// 仅 DEBUG 构建打印，Release 编译为空。
#if DEBUG
#define WK_THREAD_BADGE_DBG(...) NSLog(__VA_ARGS__)
#else
#define WK_THREAD_BADGE_DBG(...) do {} while(0)
#endif

@interface WKConversationGroupThreadOnlyCell ()

@property (nonatomic, strong) WKUserAvatar *avatarView;
@property (nonatomic, strong) UILabel *titleLbl;
@property (nonatomic, strong) UILabel *subtitleLbl;
@property (nonatomic, strong) WKBadgeView *badgeView;
@property (nonatomic, strong) UIImageView *muteIcon;
@property (nonatomic, strong) UIButton *threadToggleBtn;

@property (nonatomic, strong) UILabel *moreLbl;
@property (nonatomic, strong) UILabel *moreBadgeLbl;

@property (nonatomic, strong) WKConversationWrapModel *model;

@property (nonatomic, copy) NSString *lastAvatarChannelId; // 上一次 refreshAvatar 对应的 channelId，用于判断 cell 是否被复用到不同会话

@end

#define TOP_HEIGHT 64.0f
#define MORE_HEIGHT 26.0f
#define AVATAR_SIZE 52.0f
#define AVATAR_LEFT 15.0f
#define CONTENT_LEFT 77.0f
#define RIGHT_PADDING 15.0f

@implementation WKConversationGroupThreadOnlyCell

+(CGFloat) heightForModel:(WKConversationWrapModel *)model {
    BOOL hasMention = NO;
    if (model.simpleReminders.count > 0) {
        for (WKReminder *r in model.simpleReminders) {
            if (r.type == WKReminderTypeMentionMe) { hasMention = YES; break; }
        }
    }
    CGFloat topH = hasMention ? (TOP_HEIGHT + 10) : TOP_HEIGHT;
    // 走已关注子区数（与 WKConversationGroupThreadCell 同源），不能直接用 model.threadCount
    // 那是父群的 raw 总数，包括未关注子区 —— follow tab 已关注 = 0 但 raw > 0 时高度会
    // 多出 +N 子区那一行的占位（实际不显示），与 updateMoreLabel 的过滤口径不一致。
    NSInteger visibleThreadCount = [WKConversationGroupThreadCell visibleThreadCountFor:model];
    if (visibleThreadCount > 0) {
        return topH + MORE_HEIGHT + 6.0f;
    }
    return topH;
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
    self.avatarView = [[WKUserAvatar alloc] initWithFrame:CGRectMake(0, 0, AVATAR_SIZE, AVATAR_SIZE)];
    [self.contentView addSubview:self.avatarView];

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.font = [[WKApp shared].config appFontOfSizeMedium:16.0f];
    self.titleLbl.textColor = [WKApp shared].config.defaultTextColor;
    self.titleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:self.titleLbl];

    self.threadToggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.threadToggleBtn.contentEdgeInsets = UIEdgeInsetsMake(9, 9, 9, 9);
    [self.threadToggleBtn addTarget:self action:@selector(onToggleTap) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.threadToggleBtn];

    self.subtitleLbl = [[UILabel alloc] init];
    self.subtitleLbl.font = [[WKApp shared].config appFontOfSize:13.0f];
    self.subtitleLbl.textColor = [UIColor orangeColor];
    self.subtitleLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    self.subtitleLbl.hidden = YES;
    [self.contentView addSubview:self.subtitleLbl];

    self.badgeView = [WKBadgeView viewWithoutBadgeTip];
    [self.contentView addSubview:self.badgeView];

    self.muteIcon = [[UIImageView alloc] initWithImage:[WKApp.shared loadImage:@"ConversationList/Index/Mute" moduleID:@"WuKongBase"]];
    self.muteIcon.hidden = YES;
    [self.contentView addSubview:self.muteIcon];

    self.moreLbl = [[UILabel alloc] init];
    self.moreLbl.font = [[WKApp shared].config appFontOfSize:12.0f];
    self.moreLbl.textColor = [WKApp shared].config.themeColor;
    self.moreLbl.hidden = YES;
    self.moreLbl.userInteractionEnabled = YES;
    UITapGestureRecognizer *moreTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMoreTap)];
    [self.moreLbl addGestureRecognizer:moreTap];
    [self.contentView addSubview:self.moreLbl];

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
    if (!model.channelInfo) {
        [model startChannelRequest];
    }

    [self refreshAvatar:model];
    self.titleLbl.text = model.channelInfo ? model.channelInfo.displayName : LLang(@"群聊");

    // @我 提醒
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
            if (r.type == WKReminderTypeMentionMe) { reminderText = r.text ?: @""; break; }
        }
        self.subtitleLbl.text = [NSString stringWithFormat:@"%@ %@", reminderText, model.content ?: @""];
    } else {
        self.subtitleLbl.hidden = YES;
    }

    // 红点
    self.badgeView.hidden = YES;
    if (model.unreadCount > 0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = model.unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)model.unreadCount];
    }

    // 免打扰
    if (model.mute) {
        self.muteIcon.hidden = (model.unreadCount > 0);
        [self.badgeView setBadgeBackgroundColor:[UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f]];
    } else {
        self.muteIcon.hidden = YES;
        [self.badgeView setBadgeBackgroundColor:[UIColor redColor]];
    }

    // 折叠图标（带指示器，从 VM 缓存读取，无 DB 查询）
    NSInteger threadUnread = 0;
    BOOL threadHasMention = NO;
    [[WKConversationListVM shared] getThreadIndicatorForGroup:model.channel.channelId threadUnread:&threadUnread threadHasMention:&threadHasMention];
    NSInteger indicatorType = 0;
    UIColor *indicatorColor = nil;
    if (threadHasMention) {
        indicatorType = 2;
        indicatorColor = [UIColor orangeColor];
    } else if (threadUnread > 0) {
        indicatorType = 1;
        indicatorColor = model.mute
            ? [UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f]
            : [UIColor redColor];
    }
    UIImage *toggleIcon = [WKConversationGroupThreadCell threadToggleIconWithSize:CGSizeMake(28, 28)
                                                                       baseColor:[WKApp shared].config.themeColor
                                                                   indicatorType:indicatorType
                                                                  indicatorColor:indicatorColor];
    [self.threadToggleBtn setImage:toggleIcon forState:UIControlStateNormal];

    // "+X个子区"
    [self updateMoreLabel];
    [self setNeedsLayout];
}

-(void) updateMoreLabel {
    // OnlyCell 由 VC 在 visiblePreviews.count == 0 时才选用（见 WKConversationListVC.m
    // cellForRowAt 分派），物理上不渲染任何 preview 行 —— previewCount 必须按 0 算，
    // 而不是 raw self.model.threadPreviews.count（PR review #3 critical）。
    // 旧实现 raw count > 0 时（活跃 preview 全部未关注 + 已关注子区在 dormant 区的场景）
    // moreCount = followedThreadCount - raw 会 ≤ 0 把整行 + 红点错误隐藏。
    NSInteger previewCount = 0;
    // moreCount = 已关注子区数 - 当前展示的 preview 数（OnlyCell 始终为 0）
    NSInteger followedThreadCount = [WKConversationGroupThreadCell visibleThreadCountFor:self.model];
    NSInteger moreCount = followedThreadCount - previewCount;
    if (moreCount <= 0) {
        self.moreLbl.hidden = YES;
        self.moreBadgeLbl.hidden = YES;
        return;
    }

    self.moreLbl.hidden = NO;

    NSString *groupNo = self.model.channel.channelId;
    NSInteger moreUnread = 0;
    BOOL moreMention = NO;
    [[WKConversationListVM shared] getThreadIndicatorForGroup:groupNo threadUnread:&moreUnread threadHasMention:&moreMention];

    NSString *moreText = [NSString stringWithFormat:@"+%ld %@", (long)moreCount, LLang(@"个子区")];
    if (moreMention) {
        NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:moreText attributes:@{NSForegroundColorAttributeName: [WKApp shared].config.themeColor}];
        [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", LLang(@"[有人@我]")] attributes:@{NSForegroundColorAttributeName: [UIColor orangeColor]}]];
        self.moreLbl.attributedText = attrText;
    } else {
        self.moreLbl.attributedText = nil;
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
    WK_THREAD_BADGE_DBG(@"[ThreadBadgeDbg] GroupThreadOnlyCell group=%@ followed=%ld preview=%ld → +N=%ld moreUnread=%ld moreMention=%d",
          groupNo, (long)followedThreadCount, (long)previewCount, (long)moreCount, (long)moreUnread, moreMention);
}

-(void) refreshAvatar:(WKConversationWrapModel*)model {
    UIImage *placeholder = [WKApp.shared loadImage:@"Common/Index/DefaultAvatar" moduleID:@"WuKongBase"];
    NSString *channelId = model.channel.channelId;
    // 仅在 cell 被复用到不同会话时清回占位图，避免残留上一个会话的人脸；同会话刷新保留当前头像。
    BOOL channelChanged = (channelId.length == 0) || ![channelId isEqualToString:self.lastAvatarChannelId];
    if (channelChanged) {
        self.avatarView.avatarImgView.image = placeholder;
    }
    self.lastAvatarChannelId = channelId;
    if (model.channelInfo) {
        NSString *avatarURL;
        if ([model.channelInfo.logo hasPrefix:@"http"]) {
            NSString *key = (model.channelInfo.avatarCacheKey.length > 0) ? model.channelInfo.avatarCacheKey : @"0";
            NSString *sep = [model.channelInfo.logo containsString:@"?"] ? @"&" : @"?";
            avatarURL = [NSString stringWithFormat:@"%@%@v=%@", model.channelInfo.logo, sep, key];
        } else {
            avatarURL = [WKAvatarUtil getGroupAvatar:model.channel.channelId cacheKey:model.channelInfo.avatarCacheKey];
        }
        // SDWebImageDelayPlaceholder：加载中不覆盖已有头像，仅在失败时落到占位图，避免返回会话列表刷新时的占位图闪烁
        [self.avatarView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:avatarURL]
                                          placeholderImage:placeholder
                                                   options:SDWebImageDelayPlaceholder
                                                   context:@{SDWebImageContextStoreCacheType: @(SDImageCacheTypeAll)}];
    } else {
        self.avatarView.avatarImgView.image = placeholder;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.lim_width;
    BOOL showMention = !self.subtitleLbl.hidden;
    CGFloat topH = showMention ? (TOP_HEIGHT + 10) : TOP_HEIGHT;

    self.avatarView.frame = CGRectMake(AVATAR_LEFT, showMention ? 8.0f : (topH - AVATAR_SIZE) / 2.0f, AVATAR_SIZE, AVATAR_SIZE);

    CGFloat titleRight = w - RIGHT_PADDING - 50.0f;
    if (showMention) {
        self.titleLbl.frame = CGRectMake(CONTENT_LEFT, 8.0f, titleRight - CONTENT_LEFT, 20);
        self.subtitleLbl.frame = CGRectMake(CONTENT_LEFT, self.titleLbl.lim_bottom + 2, titleRight - CONTENT_LEFT, 18);
    } else {
        self.titleLbl.frame = CGRectMake(CONTENT_LEFT, (topH - 20) / 2.0f, titleRight - CONTENT_LEFT, 20);
    }

    CGFloat rightEdge = w - RIGHT_PADDING;
    self.threadToggleBtn.frame = CGRectMake(rightEdge - 44, (topH - 44) / 2.0f, 44, 44);
    rightEdge = self.threadToggleBtn.lim_left - 2;

    self.badgeView.lim_left = rightEdge - self.badgeView.lim_width;
    self.badgeView.lim_top = (topH - self.badgeView.lim_height) / 2.0f;

    self.muteIcon.lim_left = rightEdge - self.muteIcon.lim_width;
    self.muteIcon.lim_top = (topH - self.muteIcon.lim_height) / 2.0f;

    // "+X个子区"
    if (!self.moreLbl.hidden) {
        CGFloat containerWidth = w - CONTENT_LEFT - RIGHT_PADDING;
        self.moreLbl.frame = CGRectMake(CONTENT_LEFT + 10, topH + 2, containerWidth - 60, MORE_HEIGHT - 4);
        if (!self.moreBadgeLbl.hidden) {
            [self.moreBadgeLbl sizeToFit];
            CGFloat badgeW = MAX(self.moreBadgeLbl.lim_width + 8, 18);
            self.moreBadgeLbl.frame = CGRectMake(w - RIGHT_PADDING - badgeW, self.moreLbl.lim_top + (MORE_HEIGHT - 4 - 18) / 2.0, badgeW, 18);
        }
    }
}

-(void) onMoreTap {
    if (self.onMoreThreadsTap && self.model.channel.channelId.length > 0) {
        self.onMoreThreadsTap(self.model.channel.channelId);
    }
}

-(void) onToggleTap {
    if (self.onToggleThreadPreview && self.model.channel.channelId.length > 0) {
        self.onToggleThreadPreview(self.model.channel.channelId);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    // 不清空 avatar image：让旧头像保留到新头像加载完成后再替换，避免刷新时的空白闪烁。
    self.badgeView.hidden = YES;
    self.muteIcon.hidden = YES;
    self.moreLbl.hidden = YES;
    self.moreBadgeLbl.hidden = YES;
    self.subtitleLbl.hidden = YES;
    self.onMoreThreadsTap = nil;
    self.onToggleThreadPreview = nil;
}

@end
