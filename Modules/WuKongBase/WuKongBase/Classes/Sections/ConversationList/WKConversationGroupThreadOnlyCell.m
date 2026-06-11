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
#import <SDWebImage/SDImageCache.h>
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
@property (nonatomic, strong) UILabel *mentionBadge; // 父群行 "@我" 红底白字胶囊（与最近 tab cell 同款）
@property (nonatomic, strong) WKBadgeView *badgeView;
@property (nonatomic, strong) UIImageView *muteIcon;
@property (nonatomic, strong) UIButton *threadToggleBtn;

@property (nonatomic, strong) UILabel *moreLbl;
@property (nonatomic, strong) UILabel *moreBadgeLbl;

@property (nonatomic, strong) WKConversationWrapModel *model;

@property (nonatomic, copy) NSString *lastAvatarChannelId; // 上一次 refreshAvatar 对应的 channelId，用于判断 cell 是否被复用到不同会话
@property (nonatomic, copy) NSString *lastAppliedAvatarURL; // 上一次实际下发的 URL —— 复用判定用

@end

#define TOP_HEIGHT 64.0f
#define MORE_HEIGHT 26.0f
#define AVATAR_SIZE 52.0f
#define AVATAR_LEFT 15.0f
#define CONTENT_LEFT 77.0f
#define RIGHT_PADDING 15.0f

@implementation WKConversationGroupThreadOnlyCell

+(CGFloat) heightForModel:(WKConversationWrapModel *)model {
    // 父群行不再因为 @我 增高（@我 现在是右侧 mentionBadge 胶囊，不占行高）。
    CGFloat topH = TOP_HEIGHT;
    // OnlyCell 物理上不渲染任何 preview 行，previewCount 必须按 0 算（PR review #3 critical）。
    // followedThreadCount > 0 才有 "+N 个子区" 行可显示，与 updateMoreLabel 同口径。
    NSInteger followedThreadCount = [WKConversationGroupThreadCell visibleThreadCountFor:model];
    if (followedThreadCount > 0) {
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

    // "@我" 胶囊：跟最近 tab cell 同款（红底 #FA5151 白字粗体），父群行有 @我 时显示在右侧
    self.mentionBadge = [[UILabel alloc] init];
    self.mentionBadge.text = LLang(@"@我");
    self.mentionBadge.font = [UIFont boldSystemFontOfSize:11.0f];
    self.mentionBadge.textColor = [UIColor whiteColor];
    self.mentionBadge.backgroundColor = WKMentionBadgeBgColor();
    self.mentionBadge.textAlignment = NSTextAlignmentCenter;
    self.mentionBadge.layer.cornerRadius = 9.0f;
    self.mentionBadge.layer.masksToBounds = YES;
    self.mentionBadge.frame = CGRectMake(0, 0, 36.0f, 18.0f);
    self.mentionBadge.hidden = YES;
    [self.contentView addSubview:self.mentionBadge];

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
    // @我 标识改成右侧 mentionBadge 胶囊，subtitleLbl（旧版橙色长行）废弃。
    self.subtitleLbl.hidden = YES;
    self.mentionBadge.hidden = !hasMention;

    // 红点
    self.badgeView.hidden = YES;
    if (model.unreadCount > 0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = model.unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)model.unreadCount];
    }

    // 免打扰
    if (model.mute) {
        self.muteIcon.hidden = (model.unreadCount > 0);
        // mute 走浅蓝底 + 白字（与 WKConversationListCell mute 分支一致）
        [self.badgeView setBadgeBackgroundColor:[UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f]];
        [self.badgeView setBadgeTextColor:[UIColor whiteColor]];
    } else {
        self.muteIcon.hidden = YES;
        // 非静音走 WKUnreadBadge* 共享调色板（浅粉底 + 深红字），与 WKConversationListCell
        // 在关注 tab 折叠态（未点开展开时）的样式一致，避免折叠 / 展开切换时配色跳变。
        [self.badgeView setBadgeBackgroundColor:WKUnreadBadgeBgColor()];
        [self.badgeView setBadgeTextColor:WKUnreadBadgeFgColor()];
    }

    // 折叠图标（带指示器，从 VM 缓存读取，无 DB 查询）
    NSInteger threadUnread = 0;
    BOOL threadHasMention = NO;
    [[WKConversationListVM shared] getThreadIndicatorForGroup:model.channel.channelId threadUnread:&threadUnread threadHasMention:&threadHasMention];
    NSInteger indicatorType = 0;
    UIColor *indicatorColor = nil;
    if (threadHasMention) {
        indicatorType = 2;
        indicatorColor = WKMentionBadgeBgColor();
    } else if (threadUnread > 0) {
        indicatorType = 1;
        indicatorColor = model.mute
            ? [UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f]
            : WKUnreadBadgeBgColor();
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
    // cellForRowAt 分派），物理上不渲染任何 preview 行 —— previewCount 按 0 算
    // （PR review #3 critical：不能用 raw self.model.threadPreviews.count，
    // 那是父群下全部 active 子区，OnlyCell 一条都没渲染到屏幕上）。
    NSInteger previewCount = 0;
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
        [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", LLang(@"[有人@我]")] attributes:@{NSForegroundColorAttributeName: [UIColor redColor]}]];
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
    // 先把本次要下发的 URL 算出来；下面的复用判定要拿它跟 lastAppliedAvatarURL 比对。
    NSString *avatarURL = nil;
    if (model.channelInfo) {
        if ([model.channelInfo.logo hasPrefix:@"http"]) {
            NSString *key = (model.channelInfo.avatarCacheKey.length > 0) ? model.channelInfo.avatarCacheKey : @"0";
            NSString *sep = [model.channelInfo.logo containsString:@"?"] ? @"&" : @"?";
            avatarURL = [NSString stringWithFormat:@"%@%@v=%@", model.channelInfo.logo, sep, key];
        } else {
            avatarURL = [WKAvatarUtil getGroupAvatar:model.channel.channelId cacheKey:model.channelInfo.avatarCacheKey];
        }
    }
    // 复用判定：sameURL || sameChannel → 保留旧 image 作占位；都不同 → 清回 placeholder
    UIImage *cached = (avatarURL.length > 0)
                        ? [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:avatarURL]
                        : nil;
    // 「去 cache-busting v= 参数后的 URL」当 stable key（同 GroupThreadCell，应对 SDK
    // cacheKey 抖动）。只剥 v=，保留其它 query 避免不同身份头像被错误归一。
    NSString *stableKey = [WKAvatarUtil stableCacheKeyFromAvatarURL:avatarURL];
    UIImage *stableFallback = (cached == nil && stableKey.length > 0)
                                ? [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:stableKey]
                                : nil;
    BOOL sameURL = (self.lastAppliedAvatarURL.length > 0
                    && [self.lastAppliedAvatarURL isEqualToString:avatarURL ?: @""]);
    BOOL sameChannel = (channelId.length > 0
                        && [channelId isEqualToString:self.lastAvatarChannelId]);
    BOOL safeToKeepImage = sameURL || sameChannel;
#if DEBUG
    BOOL hadImage = (self.avatarView.avatarImgView.image != nil);
    NSLog(@"[AvatarDbg][ThreadOnly] ch=%@ prevCh=%@ url=%@ prevUrl=%@ sameURL=%d sameChannel=%d cacheHit=%d stableHit=%d hadImage=%d → %@",
          channelId, self.lastAvatarChannelId,
          avatarURL ?: @"<nil>", self.lastAppliedAvatarURL ?: @"<nil>",
          sameURL, sameChannel, cached != nil, stableFallback != nil, hadImage,
          cached ? @"USE_CACHED" : (stableFallback ? @"USE_STABLE" : (safeToKeepImage ? @"KEEP_OLD" : @"CLEAR")));
#endif
    if (cached) {
        self.avatarView.avatarImgView.image = cached;
    } else if (stableFallback) {
        // base URL stable key 命中：用上次同一张图当**视觉占位**；不能反向喂 SDImageCache
        // 新 URL key，否则 avatarCacheKey 失效，群头像上传后永远不刷新。
        self.avatarView.avatarImgView.image = stableFallback;
    } else if (!safeToKeepImage) {
        self.avatarView.avatarImgView.image = placeholder;
    }
    self.lastAvatarChannelId = channelId;
    self.lastAppliedAvatarURL = avatarURL ?: @"";
    if (avatarURL.length > 0) {
        NSString *stableKeyForCompletion = stableKey;
        [self.avatarView.avatarImgView lim_setImageWithURL:[NSURL URLWithString:avatarURL]
                                          placeholderImage:placeholder
                                                   options:SDWebImageDelayPlaceholder
                                                   context:@{SDWebImageContextStoreCacheType: @(SDImageCacheTypeAll)}
                                                 completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
            if (image && stableKeyForCompletion.length > 0) {
                [[SDImageCache sharedImageCache] storeImageToMemory:image forKey:stableKeyForCompletion];
            }
        }];
    } else {
        self.avatarView.avatarImgView.image = placeholder;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.lim_width;
    CGFloat topH = TOP_HEIGHT;

    self.avatarView.frame = CGRectMake(AVATAR_LEFT, (topH - AVATAR_SIZE) / 2.0f, AVATAR_SIZE, AVATAR_SIZE);

    CGFloat titleRight = w - RIGHT_PADDING - 50.0f;
    self.titleLbl.frame = CGRectMake(CONTENT_LEFT, (topH - 20) / 2.0f, titleRight - CONTENT_LEFT, 20);

    CGFloat rightEdge = w - RIGHT_PADDING;
    self.threadToggleBtn.frame = CGRectMake(rightEdge - 44, (topH - 44) / 2.0f, 44, 44);
    rightEdge = self.threadToggleBtn.lim_left - 2;

    self.badgeView.lim_left = rightEdge - self.badgeView.lim_width;
    self.badgeView.lim_top = (topH - self.badgeView.lim_height) / 2.0f;

    self.muteIcon.lim_left = rightEdge - self.muteIcon.lim_width;
    self.muteIcon.lim_top = (topH - self.muteIcon.lim_height) / 2.0f;

    // @我 胶囊：放在 badge / mute 左侧 4pt，纵向居中。顺序：[toggle][badge or mute][@我][...title]
    if (!self.mentionBadge.hidden) {
        CGFloat slotLeft = rightEdge;
        if (!self.badgeView.hidden) {
            slotLeft = self.badgeView.lim_left;
        } else if (!self.muteIcon.hidden) {
            slotLeft = self.muteIcon.lim_left;
        }
        self.mentionBadge.lim_left = slotLeft - 4.0f - self.mentionBadge.lim_width;
        self.mentionBadge.lim_top = (topH - self.mentionBadge.lim_height) / 2.0f;
    }

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
    self.mentionBadge.hidden = YES;
    self.onMoreThreadsTap = nil;
    self.onToggleThreadPreview = nil;
}

@end
