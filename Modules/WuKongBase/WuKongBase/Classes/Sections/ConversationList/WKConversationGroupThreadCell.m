//
//  WKConversationGroupThreadCell.m
//  WuKongBase
//

#import "WKConversationGroupThreadCell.h"
#import "WKThreadModel.h"
#import "WKTimeTool.h"
#import "WKBadgeView.h"
#import "WKUserAvatar.h"
#import "WKFollowedKeysStore.h"
#import "WKSidebarItemEntity.h"
#import "WKAvatarUtil.h"
#import "UIView+WK.h"
#import "WKApp.h"
#import "WuKongBase.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/SDImageCache.h>
#import "WKConversationListVM.h"

// [ThreadBadgeDbg] 子区 unread / +N 角标调试日志（PR #137 review 反馈）：
// 仅 DEBUG 构建打印，Release 编译为空 —— 防止 channelId / unread 数字这类
// metadata 进入生产日志、并避开 cell 刷新热路径的 NSLog 开销。
#if DEBUG
#define WK_THREAD_BADGE_DBG(...) NSLog(__VA_ARGS__)
#else
#define WK_THREAD_BADGE_DBG(...) do {} while(0)
#endif

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
@property (nonatomic, strong) UILabel *mentionBadge; // 父群行 "@我" 红底白字胶囊（与最近 tab cell 同款）
@property (nonatomic, strong) WKBadgeView *badgeView;
@property (nonatomic, strong) UIImageView *muteIcon;

// 子区预览区域
@property (nonatomic, strong) UIView *threadContainer;
@property (nonatomic, strong) WKThreadBranchView *branchView;
@property (nonatomic, strong) UILabel *moreLbl;
@property (nonatomic, strong) UILabel *moreBadgeLbl;
@property (nonatomic, strong) UIView *separatorLine;

// 动态预览行（按需增删）
@property (nonatomic, strong) NSMutableArray<UIView *> *previewRows;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *rowHashIcons;
@property (nonatomic, strong) NSMutableArray<UILabel *> *rowNameLbls;
@property (nonatomic, strong) NSMutableArray<UILabel *> *rowTimeLbls;
@property (nonatomic, strong) NSMutableArray<UILabel *> *rowMsgLbls;
@property (nonatomic, strong) NSMutableArray<UILabel *> *rowBadgeLbls;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *rowMuteIcons;
@property (nonatomic, strong) NSMutableArray<UILabel *> *rowMentionBadges; // 每行右侧 "@我" 胶囊（红底白字，跟最近 tab 同款）

@property (nonatomic, strong) WKConversationWrapModel *model;
@property (nonatomic, strong) UIButton *threadToggleBtn;

@property (nonatomic, copy) NSString *lastAvatarChannelId; // 上一次 refreshAvatar 对应的 channelId，用于判断 cell 是否被复用到不同会话
@property (nonatomic, copy) NSString *lastAppliedAvatarURL; // 上一次实际下发的 URL —— 复用判定用

@end

@implementation WKConversationGroupThreadCell

#define TOP_HEIGHT 64.0f
#define THREAD_ROW_HEIGHT 32.0f
#define MORE_HEIGHT 26.0f
#define HASH_TAG_SIZE 52.0f
#define HASH_TAG_LEFT 15.0f
#define CONTENT_LEFT 77.0f
#define RIGHT_PADDING 15.0f

#pragma mark - 关注 tab 子区可见性过滤

+ (NSArray<WKThreadModel *> *)visibleThreadPreviewsFor:(WKConversationWrapModel *)model {
    NSArray<WKThreadModel *> *raw = model.threadPreviews;
    if (raw.count == 0) return raw;
    WKFollowedKeysStore *store = [WKFollowedKeysStore shared];
    if (!store.loaded) return raw; // store 还没成功加载过，先按原样（避免冷启瞬间全部清空）
    NSSet<NSString *> *keys = store.followedKeys;
    NSMutableArray<WKThreadModel *> *kept = [NSMutableArray array];
    for (WKThreadModel *t in raw) {
        NSString *key = [NSString stringWithFormat:@"%ld::%@", (long)WKFollowTargetTypeThread, t.channelId ?: @""];
        if ([keys containsObject:key]) [kept addObject:t];
    }
    return kept;
}

+ (NSInteger)visibleThreadCountFor:(WKConversationWrapModel *)model {
    // 关注 tab 上"该群下已关注的子区数"。
    WKFollowedKeysStore *store = [WKFollowedKeysStore shared];
    if (!store.loaded) return model.threadCount; // 未加载先按全量（避免冷启误清）
    NSString *groupNo = model.channel.channelId;
    if (groupNo.length == 0) return 0;
    NSString *prefix = [NSString stringWithFormat:@"%ld::%@____", (long)WKFollowTargetTypeThread, groupNo];
    NSInteger n = 0;
    for (NSString *k in store.followedKeys) {
        if ([k hasPrefix:prefix]) n++;
    }
    return n;
}

+(CGFloat) heightForModel:(WKConversationWrapModel *)model {
    // 父群行不再因为 @我 增高（@我 现在是右侧 mentionBadge 胶囊，不占行高）。
    CGFloat topH = TOP_HEIGHT;
    NSArray<WKThreadModel *> *visiblePreviews = [self visibleThreadPreviewsFor:model];
    if (visiblePreviews.count == 0) {
        return topH;
    }
    CGFloat h = topH;
    // 子区行高统一为 THREAD_ROW_HEIGHT：@我 已用右侧 mentionBadge 标识，
    // 不再因 hasMention 把 msg 行展开（用户反馈：@我 时不需要显示 lastContent 预览）。
    h += visiblePreviews.count * THREAD_ROW_HEIGHT;
    // "+N 个子区" 行：N = 已关注总数 − 已显示在 cell 里的数；followedCount 把
    // 已关注的归档/未在 listAllThreads 当页拿到的子区都算进去，所以 N 一般是
    // followed-but-not-shown（多数是已关注的归档子区）。
    NSInteger totalFollowed = [self visibleThreadCountFor:model];
    if (totalFollowed > (NSInteger)visiblePreviews.count) {
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
    UIImage *toggleIcon = [WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(28, 28) color:[WKApp shared].config.themeColor];
    [self.threadToggleBtn setImage:toggleIcon forState:UIControlStateNormal];
    self.threadToggleBtn.contentEdgeInsets = UIEdgeInsetsMake(9, 9, 9, 9);
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

    // 动态预览行（按需在 updateThreadPreviews 中创建）
    self.previewRows = [NSMutableArray array];
    self.rowHashIcons = [NSMutableArray array];
    self.rowNameLbls = [NSMutableArray array];
    self.rowTimeLbls = [NSMutableArray array];
    self.rowMsgLbls = [NSMutableArray array];
    self.rowBadgeLbls = [NSMutableArray array];
    self.rowMuteIcons = [NSMutableArray array];
    self.rowMentionBadges = [NSMutableArray array];

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
    // @我 标识改成右侧 mentionBadge 胶囊，subtitleLbl（旧版橙色长行）废弃。
    self.subtitleLbl.hidden = YES;
    self.mentionBadge.hidden = !hasMention;

    // 标题
    self.titleLbl.text = hasChannelInfo ? model.channelInfo.displayName : LLang(@"群聊");

    // 红点
    self.badgeView.hidden = YES;
    if (model.unreadCount > 0) {
        self.badgeView.hidden = NO;
        self.badgeView.badgeValue = model.unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)model.unreadCount];
        self.badgeView.lim_left = self.contentView.lim_width - RIGHT_PADDING - self.badgeView.lim_width;
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

    // 子区折叠图标颜色（从 VM 缓存读取，无 DB 查询）
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

    // 子区预览：只更新固定视图的数据，不增删视图
    [self updateThreadPreviews];
    [self setNeedsLayout];
}

-(void) ensureRowCount:(NSInteger)needed {
    while ((NSInteger)self.previewRows.count < needed) {
        NSInteger i = self.previewRows.count;
        UIView *row = [[UIView alloc] init];
        row.hidden = YES;
        row.tag = 2000 + i;
        row.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(threadRowTapped:)];
        [row addGestureRecognizer:tap];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(threadRowLongPressed:)];
        longPress.minimumPressDuration = 0.5;
        [row addGestureRecognizer:longPress];
        [self.threadContainer addSubview:row];
        [self.previewRows addObject:row];

        UIImageView *hashIcon = [[UIImageView alloc] init];
        hashIcon.contentMode = UIViewContentModeScaleAspectFit;
        [row addSubview:hashIcon];
        [self.rowHashIcons addObject:hashIcon];

        UILabel *name = [[UILabel alloc] init];
        name.font = [[WKApp shared].config appFontOfSizeMedium:14.0f];
        name.textColor = [WKApp shared].config.defaultTextColor;
        name.lineBreakMode = NSLineBreakByTruncatingTail;
        [row addSubview:name];
        [self.rowNameLbls addObject:name];

        UILabel *time = [[UILabel alloc] init];
        time.font = [[WKApp shared].config appFontOfSize:10.0f];
        time.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        time.hidden = YES;
        [row addSubview:time];
        [self.rowTimeLbls addObject:time];

        UILabel *msg = [[UILabel alloc] init];
        msg.font = [[WKApp shared].config appFontOfSize:12.0f];
        msg.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        msg.lineBreakMode = NSLineBreakByTruncatingTail;
        msg.hidden = YES;
        [row addSubview:msg];
        [self.rowMsgLbls addObject:msg];

        UILabel *badge = [[UILabel alloc] init];
        badge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        // 初始 fg/bg 走共享调色板，updateThreadPreviews 会按 mute 状态再覆盖一次。
        badge.textColor = WKUnreadBadgeFgColor();
        badge.backgroundColor = WKUnreadBadgeBgColor();
        badge.textAlignment = NSTextAlignmentCenter;
        badge.layer.cornerRadius = 9;
        badge.layer.masksToBounds = YES;
        badge.hidden = YES;
        [row addSubview:badge];
        [self.rowBadgeLbls addObject:badge];

        UIImageView *muteIv = [[UIImageView alloc] initWithImage:[WKApp.shared loadImage:@"ConversationList/Index/Mute" moduleID:@"WuKongBase"]];
        muteIv.contentMode = UIViewContentModeScaleAspectFit;
        muteIv.hidden = YES;
        [row addSubview:muteIv];
        [self.rowMuteIcons addObject:muteIv];

        // @我 胶囊（红底白字，与最近 tab 上 WKConversationListCell.mentionBadge 同款）
        UILabel *mention = [[UILabel alloc] init];
        mention.text = LLang(@"@我");
        mention.font = [UIFont boldSystemFontOfSize:11.0f];
        mention.textColor = [UIColor whiteColor];
        mention.backgroundColor = WKMentionBadgeBgColor();
        mention.textAlignment = NSTextAlignmentCenter;
        mention.layer.cornerRadius = 9.0f;
        mention.layer.masksToBounds = YES;
        mention.hidden = YES;
        [row addSubview:mention];
        [self.rowMentionBadges addObject:mention];
    }
    for (NSInteger i = needed; i < (NSInteger)self.previewRows.count; i++) {
        self.previewRows[i].hidden = YES;
    }
}

/// 动态更新预览行（按需增减行视图）
-(void) updateThreadPreviews {
    NSArray<WKThreadModel *> *previews = [WKConversationGroupThreadCell visibleThreadPreviewsFor:self.model];
    NSInteger count = previews ? previews.count : 0;
    BOOL hasPreview = (count > 0);

    self.threadContainer.hidden = !hasPreview;
    self.branchView.hidden = !hasPreview;
    if (hasPreview) {
        self.threadContainer.backgroundColor = [WKApp shared].config.backgroundColor;
    }

    // 按需创建或移除行视图
    [self ensureRowCount:count];

    UIImage *channelIcon = [WKConversationGroupThreadCell channelHashIconWithSize:CGSizeMake(16, 16) color:[UIColor colorWithRed:148.0f/255.0f green:152.0f/255.0f blue:168.0f/255.0f alpha:1.0f]];

    for (NSInteger i = 0; i < count; i++) {
        UIView *row = self.previewRows[i];
        WKThreadModel *thread = previews[i];
        row.hidden = NO;

        self.rowHashIcons[i].image = channelIcon;
        self.rowNameLbls[i].text = thread.name;
        self.rowTimeLbls[i].hidden = YES;

        WKChannel *threadChannel = [WKChannel channelID:thread.channelId channelType:WK_COMMUNITY_TOPIC];
        NSArray<WKReminder *> *threadReminders = [[WKReminderDB shared] getWaitDoneReminder:threadChannel];
        BOOL threadHasMention = NO;
        for (WKReminder *r in threadReminders) {
            if (r.type == WKReminderTypeMentionMe) { threadHasMention = YES; break; }
        }
        // @我 已在右侧 mentionBadge 标识，msg 预览行不再显示（即便 hasMention 也不展开）。
        self.rowMsgLbls[i].hidden = YES;
        // @我 胶囊：跟 threadHasMention 同源
        if (i < (NSInteger)self.rowMentionBadges.count) {
            self.rowMentionBadges[i].hidden = !threadHasMention;
        }

        WKConversation *threadConv = [[WKSDK shared].conversationManager getConversation:threadChannel];
        NSInteger unread = thread.unreadCount;
        if (threadConv) unread = threadConv.unreadCount;
        WKChannelInfo *threadInfo = [[WKSDK shared].channelManager getChannelInfo:threadChannel];
        BOOL threadMute = threadInfo ? threadInfo.mute : NO;
        if (i < (NSInteger)self.rowMuteIcons.count) {
            self.rowMuteIcons[i].hidden = !threadMute;
        }
        if (unread > 0) {
            self.rowBadgeLbls[i].hidden = NO;
            self.rowBadgeLbls[i].text = unread > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)unread];
            if (threadMute) {
                // mute 走浅蓝底 + 白字（与父群 cell mute 分支一致）
                self.rowBadgeLbls[i].backgroundColor = [UIColor colorWithRed:163/255.0f green:214/255.0f blue:237/255.0f alpha:1.0f];
                self.rowBadgeLbls[i].textColor = [UIColor whiteColor];
            } else {
                // 非静音走共享调色板：浅粉底 + 深红字，与父群 badge / 最近 tab cell badge 一致。
                self.rowBadgeLbls[i].backgroundColor = WKUnreadBadgeBgColor();
                self.rowBadgeLbls[i].textColor = WKUnreadBadgeFgColor();
            }
        } else {
            self.rowBadgeLbls[i].hidden = YES;
        }
    }

    // 分割线已下线：子区行之间不再画灰色横线（与 @我 / 普通行样式保持一致）。
    self.separatorLine.hidden = YES;

    // "+N 个子区" 入口：N = 已关注总数 − 已显示行数。followedCount 拿的是 store
    // 里这个群下的全部已关注子区（含归档），所以 +N 通常代表"已关注但没在 cell
    // 里露出的"——多半是已关注的归档子区。
    NSInteger totalFollowedThreads = [WKConversationGroupThreadCell visibleThreadCountFor:self.model];
    if (totalFollowedThreads > count) {
        self.moreLbl.hidden = NO;
        self.moreLbl.userInteractionEnabled = YES;
        if (self.moreLbl.gestureRecognizers.count == 0) {
            UITapGestureRecognizer *moreTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMoreTap)];
            [self.moreLbl addGestureRecognizer:moreTap];
        }

        // 排除已渲染 preview 行，避免与预览行自己的红点重复计数。
        NSMutableSet<NSString *> *excluded = [NSMutableSet setWithCapacity:count];
        for (NSInteger i = 0; i < count; i++) {
            WKThreadModel *p = previews[i];
            if (p.channelId.length > 0) [excluded addObject:p.channelId];
        }
        NSInteger moreUnread = 0;
        BOOL moreMention = NO;
        [[WKConversationListVM shared] getThreadIndicatorForGroup:self.model.channel.channelId
                                              excludingChannelIds:excluded
                                                     threadUnread:&moreUnread
                                                 threadHasMention:&moreMention];

        NSString *moreText = [NSString stringWithFormat:@"+%ld %@", (long)(totalFollowedThreads - count), LLang(@"个子区")];
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
        WK_THREAD_BADGE_DBG(@"[ThreadBadgeDbg] GroupThreadCell group=%@ totalFollowed=%ld preview=%ld → +N=%ld moreUnread=%ld moreMention=%d",
              self.model.channel.channelId, (long)totalFollowedThreads, (long)count,
              (long)(totalFollowedThreads - count), (long)moreUnread, moreMention);
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
    NSArray *previews = [WKConversationGroupThreadCell visibleThreadPreviewsFor:self.model];
    if (previews && index >= 0 && index < (NSInteger)previews.count) {
        WKThreadModel *t = previews[index];
        if (self.onThreadPreviewTap && t.channelId.length > 0) {
            self.onThreadPreviewTap(t.channelId);
        }
    }
}

-(void) threadRowLongPressed:(UILongPressGestureRecognizer *)gesture {
    UIView *row = gesture.view;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        row.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.08];
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];

        NSInteger index = row.tag - 2000;
        NSArray *previews = [WKConversationGroupThreadCell visibleThreadPreviewsFor:self.model];
        if (previews && index >= 0 && index < (NSInteger)previews.count) {
            WKThreadModel *t = previews[index];
            if (self.onThreadPreviewLongPress && t.channelId.length > 0) {
                CGPoint ptInWindow = [row convertPoint:CGPointMake(row.bounds.size.width / 2.0, row.bounds.size.height / 2.0) toView:nil];
                self.onThreadPreviewLongPress(t.channelId, t.name ?: @"", ptInWindow);
            }
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled ||
               gesture.state == UIGestureRecognizerStateFailed) {
        [UIView animateWithDuration:0.2 animations:^{
            row.backgroundColor = [UIColor clearColor];
        }];
    }
}

-(void) onToggleTap {
    if (self.onToggleThreadPreview && self.model.channel.channelId.length > 0) {
        self.onToggleThreadPreview(self.model.channel.channelId);
    }
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
    // 「去 cache-busting v= 参数后的 URL」当 stable key：SDK refreshAvatarCacheKey 让
    // ?v= 每次抖动 → URL 抖动 → SDImageCache 按完整 URL key 必 miss。在每次成功 load
    // 后用 stable key 多存一份，下次 miss 时拿来当**视觉占位**。只剥 v=，保留其它 query
    // 避免不同身份头像被错误归一（见 WKAvatarUtil.stableCacheKeyFromAvatarURL）。
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
    NSLog(@"[AvatarDbg][ThreadCell] ch=%@ prevCh=%@ url=%@ prevUrl=%@ sameURL=%d sameChannel=%d cacheHit=%d stableHit=%d hadImage=%d → %@",
          channelId, self.lastAvatarChannelId,
          avatarURL ?: @"<nil>", self.lastAppliedAvatarURL ?: @"<nil>",
          sameURL, sameChannel, cached != nil, stableFallback != nil, hadImage,
          cached ? @"USE_CACHED" : (stableFallback ? @"USE_STABLE" : (safeToKeepImage ? @"KEEP_OLD" : @"CLEAR")));
#endif
    if (cached) {
        // memory cache 命中：直接显示真实头像，无视觉变化
        self.avatarView.avatarImgView.image = cached;
    } else if (stableFallback) {
        // base URL stable key 命中：用上次的同一张图当**视觉占位**。不要把 stable image
        // 喂给 SDImageCache 的新 URL key —— 会让 SDWebImage 跳过下载，导致 avatarCacheKey
        // 失效（群头像被上传后 path 不变只 bump cacheKey，永远不刷新）。
        self.avatarView.avatarImgView.image = stableFallback;
    } else if (!safeToKeepImage) {
        // cell 复用到不同会话且不同 URL：清回默认 placeholder
        self.avatarView.avatarImgView.image = placeholder;
    }
    self.lastAvatarChannelId = channelId;
    self.lastAppliedAvatarURL = avatarURL ?: @"";
    if (avatarURL.length > 0) {
        // SDWebImageDelayPlaceholder：加载中不覆盖已有头像，仅在失败时落到占位图
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

    // 父群行不再因为 @我 增高（@我 现在是右侧 mentionBadge 胶囊，不占行高）。
    CGFloat topH = TOP_HEIGHT;

    // 群头像
    self.avatarView.frame = CGRectMake(HASH_TAG_LEFT, (topH - HASH_TAG_SIZE) / 2.0f, HASH_TAG_SIZE, HASH_TAG_SIZE);

    // 标题
    CGFloat titleRight = w - RIGHT_PADDING - 50.0f;
    self.titleLbl.frame = CGRectMake(CONTENT_LEFT, (topH - 20) / 2.0f, titleRight - CONTENT_LEFT, 20);

    // 右侧元素从右往左：toggle → 红点/免打扰 → @我 胶囊
    CGFloat rightEdge = w - RIGHT_PADDING;

    // 折叠按钮 - 最右侧固定
    self.threadToggleBtn.frame = CGRectMake(rightEdge - 44, (topH - 44) / 2.0f, 44, 44);
    rightEdge = self.threadToggleBtn.lim_left - 2;

    // 红点
    self.badgeView.lim_left = rightEdge - self.badgeView.lim_width;
    self.badgeView.lim_top = (topH - self.badgeView.lim_height) / 2.0f;

    // 免打扰
    self.muteIcon.lim_left = rightEdge - self.muteIcon.lim_width;
    self.muteIcon.lim_top = (topH - self.muteIcon.lim_height) / 2.0f;

    // @我 胶囊：放在 badge / mute 左侧 4pt，纵向居中
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

    // 子区预览区域
    NSArray *previews = [WKConversationGroupThreadCell visibleThreadPreviewsFor:self.model];
    NSInteger previewCount = previews ? previews.count : 0;
    if (previewCount > 0) {
        CGFloat containerTop = topH;
        CGFloat containerWidth = w - CONTENT_LEFT - RIGHT_PADDING;

        // 计算每行高度
        CGFloat containerHeight = 0;
        NSMutableArray<NSNumber *> *rowHeightsArr = [NSMutableArray arrayWithCapacity:previewCount];
        for (NSInteger i = 0; i < previewCount; i++) {
            // 子区行高统一为 THREAD_ROW_HEIGHT，rowMsgLbls 已废弃（永远 hidden）。
            CGFloat rh = THREAD_ROW_HEIGHT;
            [rowHeightsArr addObject:@(rh)];
            containerHeight += rh;
        }

        self.threadContainer.frame = CGRectMake(CONTENT_LEFT, containerTop, containerWidth, containerHeight);

        CGFloat iconSize = 16.0f;
        CGFloat nameLeft = 10 + iconSize + 6;
        CGFloat rowY = 0;
        for (NSInteger i = 0; i < previewCount && i < (NSInteger)self.previewRows.count; i++) {
            UIView *row = self.previewRows[i];
            if (row.hidden) continue;
            CGFloat rh = [rowHeightsArr[i] floatValue];
            row.frame = CGRectMake(0, rowY, containerWidth, rh);

            self.rowHashIcons[i].frame = CGRectMake(10, 8, iconSize, iconSize);

            UILabel *badge = self.rowBadgeLbls[i];
            CGFloat nameRight = containerWidth - 10;
            if (!badge.hidden) {
                [badge sizeToFit];
                CGFloat badgeW = MAX(badge.lim_width + 8, 18);
                badge.frame = CGRectMake(containerWidth - 10 - badgeW, 8, badgeW, 18);
                nameRight = badge.lim_left - 4;
            }
            // @我 胶囊：放在 unread badge 左侧 4pt（无 badge 时直接贴右边缘）。
            // 顺序从右到左：[badge][mention][mute][name…]，与最近 tab cell 右侧惯例一致。
            if (i < (NSInteger)self.rowMentionBadges.count) {
                UILabel *mention = self.rowMentionBadges[i];
                if (!mention.hidden) {
                    [mention sizeToFit];
                    CGFloat mentionW = mention.lim_width + 12; // 左右各 6pt padding
                    mention.frame = CGRectMake(nameRight - mentionW, 8, mentionW, 18);
                    nameRight = mention.lim_left - 4;
                }
            }
            if (i < (NSInteger)self.rowMuteIcons.count) {
                UIImageView *muteIv = self.rowMuteIcons[i];
                if (!muteIv.hidden) {
                    CGFloat muteSize = 14.0f;
                    muteIv.frame = CGRectMake(nameRight - muteSize, (rh - muteSize) / 2.0f, muteSize, muteSize);
                    nameRight = muteIv.frame.origin.x - 4;
                }
            }

            UILabel *msgLbl = self.rowMsgLbls[i];
            if (!msgLbl.hidden) {
                self.rowNameLbls[i].frame = CGRectMake(nameLeft, 6, nameRight - nameLeft, 16);
                msgLbl.frame = CGRectMake(nameLeft, 23, nameRight - nameLeft, 15);
            } else {
                self.rowNameLbls[i].frame = CGRectMake(nameLeft, (rh - 17) / 2.0f, nameRight - nameLeft, 17);
            }
            rowY += rh;
        }

        // 分割线已下线（updateThreadPreviews 强制 hidden=YES）。

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
    // 不清空 avatar image：让旧头像保留到新头像加载完成后再替换，避免刷新时的空白闪烁。
    self.badgeView.hidden = YES;
    self.muteIcon.hidden = YES;
    self.mentionBadge.hidden = YES;
    self.threadContainer.hidden = YES;
    self.branchView.hidden = YES;
    self.moreLbl.hidden = YES;
    self.moreBadgeLbl.hidden = YES;
    for (UIView *row in self.previewRows) row.hidden = YES;
    self.onThreadPreviewTap = nil;
    self.onMoreThreadsTap = nil;
    self.onToggleThreadPreview = nil;
    self.onThreadPreviewLongPress = nil;
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

+ (UIImage *)threadToggleIconWithSize:(CGSize)size
                            baseColor:(UIColor *)baseColor
                        indicatorType:(NSInteger)type
                       indicatorColor:(UIColor *)indicatorColor {
    CGFloat padding = 8.0f;
    CGSize canvasSize = CGSizeMake(size.width + padding, size.height + padding);

    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;

    UIImage *baseIcon = [self channelHashIconWithSize:size color:baseColor];
    [baseIcon drawAtPoint:CGPointMake(0, 0)];

    if (type == 2) {
        // @符号
        CGFloat atSize = 22.0f;
        CGFloat atX = canvasSize.width - atSize;
        CGFloat atY = canvasSize.height - atSize;
        // 白色背景圆
        [[UIColor whiteColor] setFill];
        UIBezierPath *bgCircle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(atX - 1, atY - 1, atSize + 2, atSize + 2)];
        [bgCircle fill];
        // 显式 reset 上下文 fill = indicatorColor —— drawInRect:withAttributes: 在某些
        // 路径上会继承当前 fill color 而不是 attrs 里的 ForegroundColor，
        // 之前 setFill white 残留会把 "@" 字也画成白色 → 在白圆上视觉消失。
        [indicatorColor setFill];
        // @文字
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.alignment = NSTextAlignmentCenter;
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightBold],
            NSForegroundColorAttributeName: indicatorColor,
            NSParagraphStyleAttributeName: style
        };
        CGRect textRect = CGRectMake(atX, atY + 0.5f, atSize, atSize);
        [@"@" drawInRect:textRect withAttributes:attrs];
    } else if (type == 1) {
        // 小红点
        CGFloat dotSize = 12.0f;
        CGFloat dotX = canvasSize.width - dotSize;
        CGFloat dotY = canvasSize.height - dotSize;
        // 白色描边
        [[UIColor whiteColor] setFill];
        UIBezierPath *bgDot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(dotX - 1, dotY - 1, dotSize + 2, dotSize + 2)];
        [bgDot fill];
        // 红点
        [indicatorColor setFill];
        UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(dotX, dotY, dotSize, dotSize)];
        [dot fill];
    }

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@end
